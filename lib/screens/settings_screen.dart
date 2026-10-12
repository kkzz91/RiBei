import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../providers/countdown_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/todo_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'clear_data_screen.dart';
import 'data_health_screen.dart';
import 'onboarding_screen.dart';
import 'share_bill_screen.dart';
import 'sponsor_screen.dart';

/// 与 pubspec.yaml 的 version 保持一致
const String appVersion = '1.6.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsOn = true;
  ReminderDiagnostics? _diag;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = NotificationService.instance;
    final on = await service.notificationsAllowed();
    final diag = await service.diagnostics();
    if (!mounted) return;
    setState(() {
      _notificationsOn = on;
      _diag = diag;
    });
  }

  /// 手动重排：把数据库里的倒计时和待办重新写进系统闹钟。
  /// 换手机、系统清理过闹钟、或怀疑提醒丢了的时候用。
  Future<void> _reschedule() async {
    Haptics.impact();
    final countdowns = context.read<CountdownProvider>();
    final todos = context.read<TodoProvider>();
    setState(() => _busy = true);
    final report = await NotificationService.instance.rescheduleAll(
      countdowns: countdowns.events,
      todos: todos.items,
    );
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(report.summary)),
    );
  }


  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = context.watch<SettingsProvider>();
    final ledger = context.watch<LedgerProvider>();
    final countdowns = context.watch<CountdownProvider>();
    final todos = context.watch<TodoProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        // 顶栏是彩色条，内容顶部留 14 不贴上去
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          const _SectionLabel('外观'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.brightness_6_outlined, size: 19, color: p.inkSoft),
                      const SizedBox(width: 10),
                      const Text(
                        '主题',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        settings.themeModeLabel,
                        style: TextStyle(fontSize: 13, color: p.inkSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ThemeChooser(
                    value: settings.themeMode,
                    onChanged: (mode) {
                      Haptics.tap();
                      context.read<SettingsProvider>().setThemeMode(mode);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('交互'),
          Card(
            child: SwitchListTile(
              value: settings.hapticsEnabled,
              onChanged: (v) {
                Haptics.tap();
                context.read<SettingsProvider>().setHaptics(v);
              },
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
              secondary: Icon(
                Icons.vibration,
                size: 21,
                color: p.inkSoft,
              ),
              title: const Text(
                '触感反馈',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '打字、勾选时震动。需系统「声音与触感 → 触感反馈」已开启',
                  style: TextStyle(fontSize: 12, color: p.inkSoft),
                ),
              ),
            ),
          ),
          if (settings.hapticsEnabled) ...[
            const SizedBox(height: 10),
            _HapticStrengthChooser(
              value: settings.hapticStrength,
              onChanged: (v) {
                // 先应用再震动，这样试的就是刚选的那一档
                context.read<SettingsProvider>().setHapticStrength(v);
                Haptics.tap();
              },
            ),
          ],
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              value: settings.useSystemKeyboard,
              onChanged: (v) {
                Haptics.tap();
                context.read<SettingsProvider>().setUseSystemKeyboard(v);
              },
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
              secondary: Icon(
                Icons.keyboard_alt_outlined,
                size: 21,
                color: p.inkSoft,
              ),
              title: const Text(
                '金额用系统键盘输入',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '开启后，金额用输入法直接输数字；关掉则用 App 自带的数字键盘',
                  style: TextStyle(fontSize: 12, color: p.inkSoft),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('提醒'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  leading: Icon(
                    _notificationsOn
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 21,
                    color: _notificationsOn ? p.jade : p.danger,
                  ),
                  title: Text(
                    _notificationsOn ? '通知已开启' : '通知未开启，到点不会提醒',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _notificationsOn ? p.ink : p.danger,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _notificationsOn
                          ? '通知与震动由系统「日贝 → 通知」控制'
                          : '点右侧到系统设置里打开',
                      style: TextStyle(fontSize: 12, color: p.inkSoft),
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      Haptics.tap();
                      if (_notificationsOn) {
                        await NotificationService.instance.openSystemSettings();
                      } else {
                        await NotificationService.instance.ensurePermissions();
                      }
                      _refresh();
                    },
                    child: Text(_notificationsOn ? '系统设置' : '去开启'),
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  leading: Icon(Icons.send_outlined, size: 20, color: p.inkSoft),
                  title: const Text(
                    '发一条测试通知',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '确认铃声和震动是否正常',
                      style: TextStyle(fontSize: 12, color: p.inkSoft),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Haptics.impact();
                    await NotificationService.instance.showTest();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('提醒自检'),
          _DiagnosticsCard(
            diag: _diag,
            busy: _busy,
            onRefresh: _refresh,
            onReschedule: _reschedule,
          ),
          const SizedBox(height: 22),

          const _SectionLabel('数据'),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  label: '账目',
                  value: '${ledger.records.length} 笔',
                ),
                _InfoRow(
                  label: '倒计时',
                  value: '${countdowns.events.length} 个',
                ),
                _InfoRow(
                  label: '待办',
                  value: '${todos.items.length} 条',
                ),
                _InfoRow(label: '存储位置', value: '仅本机'),
                Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  leading: Icon(Icons.ios_share, size: 20, color: p.jade),
                  title: const Text(
                    '分享账单',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '把一个月的账生成好看的图片，发朋友圈',
                      style: TextStyle(fontSize: 12, color: p.inkSoft),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Haptics.tap();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ShareBillScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  leading: Icon(
                    Icons.health_and_safety_outlined,
                    size: 20,
                    color: p.inkSoft,
                  ),
                  title: const Text(
                    '数据与备份',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '看库文件与记录条数、导出一份备份',
                      style: TextStyle(fontSize: 12, color: p.inkSoft),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Haptics.tap();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DataHealthScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    size: 20,
                    color: p.inkSoft,
                  ),
                  title: const Text(
                    '清空数据',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '按天清、只清账本、或全部清空',
                      style: TextStyle(fontSize: 12, color: p.inkSoft),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Haptics.tap();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ClearDataScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('帮助'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              leading: Icon(
                Icons.school_outlined,
                size: 20,
                color: p.jade,
              ),
              title: const Text(
                '新手教程',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '功能简介，以及提醒为什么必须手动开权限。随时能回来看',
                  style: TextStyle(fontSize: 12, color: p.inkSoft),
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Haptics.tap();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingScreen(revisit: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('关于'),
          Card(
            child: Column(
              children: [
                const _InfoRow(label: '版本', value: appVersion),
                _InfoRow(
                  label: '说明',
                  value: '数据全部存在手机上，不联网',
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  leading: Icon(
                    Icons.favorite_outline,
                    size: 20,
                    color: p.jade,
                  ),
                  title: const Text(
                    '赞助作者',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '如果帮到了你，请作者喝杯水',
                      style: TextStyle(fontSize: 12, color: p.inkSoft),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Haptics.tap();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SponsorScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: Text(
              '日贝 · 日 = 时间，贝 = 货币',
              style: TextStyle(fontSize: 11.5, color: p.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 零件

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: context.palette.inkSoft,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ThemeChooser extends StatelessWidget {
  const _ThemeChooser({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, '跟随系统', Icons.brightness_auto_outlined),
      (ThemeMode.light, '浅色', Icons.light_mode_outlined),
      (ThemeMode.dark, '深色', Icons.dark_mode_outlined),
    ];

    return Row(
      children: [
        for (final (mode, label, icon) in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value == mode ? p.jade : p.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: value == mode ? p.jade : p.line,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: value == mode
                          ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                          : p.inkSoft,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: value == mode
                            ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                            : p.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (mode != ThemeMode.dark) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: p.ink),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: p.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------- 触感强度

class _HapticStrengthChooser extends StatelessWidget {
  const _HapticStrengthChooser({required this.value, required this.onChanged});

  final HapticStrength value;
  final ValueChanged<HapticStrength> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        const SizedBox(width: 2),
        Text('强度', style: TextStyle(fontSize: 13, color: p.inkSoft)),
        const SizedBox(width: 12),
        for (final s in HapticStrength.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == s ? p.jade : p.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: value == s ? p.jade : p.line),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value == s
                        ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                        : p.inkSoft,
                  ),
                ),
              ),
            ),
          ),
          if (s != HapticStrength.strong) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- 提醒自检

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.diag,
    required this.busy,
    required this.onRefresh,
    required this.onReschedule,
  });

  final ReminderDiagnostics? diag;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onReschedule;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = diag;

    return Card(
      child: Column(
        children: [
          if (d == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('读取中…', style: TextStyle(color: p.inkSoft)),
            )
          else ...[
            _DiagRow(
              label: '通知权限',
              value: d.notificationsEnabled ? '已开启' : '未开启',
              ok: d.notificationsEnabled,
            ),
            _DiagRow(
              label: '精确闹钟',
              value: d.exactAlarmsAllowed ? '已允许' : '未允许（会晚几分钟）',
              ok: d.exactAlarmsAllowed,
              warnOnly: true,
            ),
            _DiagRow(
              label: '已排定提醒',
              value: '${d.pendingCount} 条',
              ok: d.pendingCount > 0,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '通知渠道',
                    style: TextStyle(fontSize: 14, color: p.ink),
                  ),
                  const Spacer(),
                  Text(
                    '${d.channels.length} 个',
                    style: TextStyle(fontSize: 13, color: p.inkSoft),
                  ),
                ],
              ),
            ),
            if (d.channels.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '一个都没有 —— 提醒必然弹不出来',
                    style: TextStyle(fontSize: 12.5, color: p.danger),
                  ),
                ),
              )
            else
              for (final c in d.channels)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Row(
                    children: [
                      Icon(
                        c.importance.index >= 4
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_outlined,
                        size: 15,
                        color: c.importance.index >= 4 ? p.jade : p.warn,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${c.name} · 重要性 ${_importanceLabel(c.importance)}',
                          style: TextStyle(fontSize: 12.5, color: p.inkSoft),
                        ),
                      ),
                      Text(
                        c.playSound ? '有声' : '无声',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.playSound ? p.inkFaint : p.danger,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.battery_saver_outlined,
                      size: 19,
                      color: p.danger,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '到点不提醒？多半是后台被限制',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '到点不提醒、或只有开着 App 才提醒？国产系统会冻结后台 App、'
                  '把闹钟押后甚至丢掉。请手动打开这几处：\n'
                  '① 应用信息 → 省电策略 → 无限制\n'
                  '② 应用信息 → 自启动 → 打开\n'
                  '③ 权限管理 → 其他权限 → 闹钟和提醒 → 允许\n'
                  '④ 通知管理 → 悬浮通知 / 锁屏通知 → 允许\n'
                  '   （不开的话，别的 App 全屏时会收不到弹窗）',
                  style: TextStyle(fontSize: 12, color: p.inkSoft, height: 1.7),
                ),
              ],
            ),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            leading: Icon(Icons.refresh, size: 20, color: p.inkSoft),
            title: const Text(
              '重新排定全部提醒',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '提醒莫名不响时，点这里把闹钟按数据重建一遍',
                style: TextStyle(fontSize: 12, color: p.inkSoft),
              ),
            ),
            trailing: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, size: 20),
            onTap: busy
                ? null
                : () async {
                    await onReschedule();
                    await onRefresh();
                  },
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({
    required this.label,
    required this.value,
    required this.ok,
    this.warnOnly = false,
  });

  final String label;
  final String value;
  final bool ok;
  final bool warnOnly;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Color tint;
    if (ok) {
      tint = p.inkSoft;
    } else {
      tint = warnOnly ? p.warn : p.danger;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: p.ink)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}


/// Importance 枚举取中文名（不写 exhaustive switch，避免枚举增项后编译失败）
String _importanceLabel(Importance i) {
  switch (i.name) {
    case 'max':
    case 'high':
      return '高';
    case 'defaultImportance':
      return '默认';
    case 'low':
      return '低';
    case 'min':
      return '最低';
    case 'none':
      return '已关闭';
    default:
      return i.name;
  }
}
