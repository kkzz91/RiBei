import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/pressable.dart';
import 'sponsor_screen.dart';

/// 首次启动的说明页。
///
/// 只做两件事：**讲清这个 App 是什么**，以及**强调提醒要在系统里手动开权限**。
/// 后半件是重点 —— 倒计时和待办靠系统闹钟发出，权限不开就会静默失效，
/// 而 App 自己既看不到也改不了，只能趁第一次说清楚。
///
/// 看过之后写一个标记（[SettingsProvider.markOnboardingSeen]），
/// 之后不再出现。标记一变，`main.dart` 就把首页换成主界面。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.revisit = false});

  /// 从「设置 → 新手教程」再进来看的情形。
  /// 影响两处：底部按钮文案，以及退出时要不要自己 pop。
  final bool revisit;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _notificationsOn = false;
  bool _exactOk = false;
  bool _checked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = NotificationService.instance;
    final on = await service.notificationsAllowed();
    final exact = await service.canUseExactAlarms();
    if (!mounted) return;
    setState(() {
      _notificationsOn = on;
      _exactOk = exact;
      _checked = true;
    });
  }

  Future<void> _askPermissions() async {
    setState(() => _busy = true);
    Haptics.impact();
    await NotificationService.instance.ensurePermissions();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(
      context,
      _notificationsOn ? '通知权限已开启' : '还没开启，可以到系统设置里手动开',
      icon: _notificationsOn
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline,
      tint: _notificationsOn ? context.palette.jade : context.palette.warn,
    );
  }

  Future<void> _openSystemSettings() async {
    Haptics.tap();
    await NotificationService.instance.openSystemSettings();
    await _refresh();
  }

  Future<void> _sendTest() async {
    Haptics.impact();
    await NotificationService.instance.showTest();
    if (!mounted) return;
    AppToast.show(
      context,
      '测试通知已发出，看看有没有声音和震动',
      icon: Icons.notifications_active_outlined,
    );
  }

  Future<void> _finish() async {
    Haptics.impact();
    // 先取好 navigator，避免 await 之后再碰 context
    final navigator = Navigator.of(context);
    // 标记一变，main.dart 就会把首页换成主界面（首次启动那一次）
    await context.read<SettingsProvider>().markOnboardingSeen();
    if (!mounted) return;
    // 从设置里进来时它是被 push 的一页，要自己退出；
    // 首次启动时它是根路由（pop 不掉），maybePop 会安全地什么都不做 —— 靠上面那个标记换页。
    navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  // ---------- 头 ----------
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [p.jade, p.jadeDeep],
                          ),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.hourglass_bottom_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '日贝',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '日 = 时间，贝 = 货币',
                            style: TextStyle(fontSize: 12, color: p.inkSoft),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '一个把数据只放在你自己手机里的 App：\n'
                    '不联网、不上传、不需要注册账号。',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: p.inkSoft,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---------- 三个模块 ----------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Column(
                        children: [
                          _FeatureRow(
                            icon: Icons.receipt_long_outlined,
                            title: '记账',
                            body: '记一笔、看本月结余、按分类统计；常花的那几笔存成常用，一点就记好',
                          ),
                          Divider(height: 1, color: p.line),
                          _FeatureRow(
                            icon: Icons.hourglass_empty,
                            title: '倒计时',
                            body: '公历或农历都行，支持重复；临近时按你设定的提前天数每天提醒',
                          ),
                          Divider(height: 1, color: p.line),
                          _FeatureRow(
                            icon: Icons.checklist_rtl,
                            title: '待办',
                            body: '优先级、重复、逾期宽限；到点弹通知，勾掉会有反馈',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---------- 重点：权限 ----------
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                    decoration: BoxDecoration(
                      color: p.isDark
                          ? p.warn.withValues(alpha: 0.10)
                          : const Color(0xFFFFF7EC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.warn.withValues(alpha: 0.38)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 19,
                              color: p.warn,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                '想让提醒准时响，请先开这几处权限',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '倒计时和待办的提醒由系统闹钟发出，不需要 App 挂在后台。'
                          '但国产系统管得严，下面几处不开，提醒会被冻结、推迟甚至直接丢掉 —— '
                          '而且 App 自己看不到、改不了，只能你来开。',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: p.inkSoft,
                            height: 1.75,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final line in const <String>[
                          '应用信息 → 省电策略 → 无限制',
                          '应用信息 → 自启动 → 打开',
                          '权限管理 → 其他权限 → 闹钟和提醒 → 允许',
                          '通知管理 → 悬浮通知 / 锁屏通知 → 允许',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_box_outlined,
                                  size: 14,
                                  color: p.warn,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: p.ink,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        // 当前状态：点了按钮之后能立刻看到有没有真的开上
                        Row(
                          children: [
                            _StatusPill(
                              label: '通知权限',
                              ok: _notificationsOn,
                              checked: _checked,
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(
                              label: '精确闹钟',
                              ok: _exactOk,
                              checked: _checked,
                              warnOnly: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Pressable(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    backgroundColor: p.warn,
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: _busy ? null : _askPermissions,
                                  child: Text(_busy ? '处理中…' : '一键开启通知权限'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Pressable(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: _openSystemSettings,
                                  child: const Text('去系统设置'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _sendTest,
                            style: TextButton.styleFrom(
                              foregroundColor: p.inkSoft,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            icon: const Icon(Icons.send_outlined, size: 14),
                            label: const Text('先发一条测试通知看看'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '这几处之后随时能在「倒计时 / 待办」页顶部的提示条里复查；'
                    '设置页也有一个「提醒自检」面板。',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.inkFaint,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 赞助入口就放在这一屏：教程页是每个人都会看的地方，
                  // 比藏在「设置 → 关于」里容易被发现
                  Pressable(
                    scale: 0.98,
                    child: InkWell(
                      onTap: () {
                        Haptics.tap();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SponsorScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: p.jadeSoft,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.favorite_outline,
                                size: 16,
                                color: p.jade,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '觉得好用？请作者喝杯水',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: p.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '以后也能在「设置 → 关于」里找到',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.inkFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: p.inkFaint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ---------- 开始使用 ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Pressable(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _finish,
                  child: Text(widget.revisit ? '知道了' : '开始使用'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 零件

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.jadeSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: p.jade),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkSoft,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.ok,
    required this.checked,
    this.warnOnly = false,
  });

  final String label;
  final bool ok;
  final bool checked;

  /// 「精确闹钟」没允许只是会晚几分钟，不是致命问题，用橙色提示
  final bool warnOnly;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = !checked
        ? p.inkFaint
        : ok
        ? p.jade
        : (warnOnly ? p.warn : p.danger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            !checked
                ? Icons.circle_outlined
                : ok
                ? Icons.check_circle_outline
                : Icons.error_outline,
            size: 13,
            color: tint,
          ),
          const SizedBox(width: 5),
          Text(
            checked ? '$label ${ok ? '已开启' : '未开启'}' : label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
