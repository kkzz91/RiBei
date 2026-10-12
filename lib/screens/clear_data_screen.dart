import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/countdown_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/todo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/pressable.dart';

/// 清空数据：记错了想重新开始的地方。
///
/// 三种粒度，从轻到重：
/// - **某一天的账目** —— 只改错了一天，不用全清
/// - **全部账目** —— 只动账本，倒计时和待办留着
/// - **全部数据** —— 账目 + 倒计时 + 待办，并撤掉所有已排定的提醒
///
/// 三种都要二次确认；「全部数据」要点两次，因为它不可撤销。
/// 删除前一律先逐条取消提醒（不用"取消全部通知"那种写法，那会误伤别的模块）。
class ClearDataScreen extends StatefulWidget {
  const ClearDataScreen({super.key});

  @override
  State<ClearDataScreen> createState() => _ClearDataScreenState();
}

class _ClearDataScreenState extends State<ClearDataScreen> {
  bool _busy = false;

  /// 统一的二次确认框，返回用户是否点了确认
  Future<bool> _confirm({
    required String title,
    required String body,
    String action = '清空',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.6)),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ctx.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _toast(String message, {IconData icon = Icons.delete_sweep_outlined}) {
    AppToast.show(
      context,
      message,
      icon: icon,
      tint: context.palette.inkSoft,
    );
  }

  // ---------------------------------------------------------------- 按天

  Future<void> _clearDay() async {
    final ledger = context.read<LedgerProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择要清空的日期',
    );
    if (picked == null || !mounted) return;

    final count = ledger.ofDay(picked).length;
    if (count == 0) {
      _toast(
        '${formatShortDate(picked)} 没有账目',
        icon: Icons.info_outline,
      );
      return;
    }
    final day = formatShortDate(picked);
    if (!await _confirm(
      title: '清空 $day 的账目？',
      body: '$day 一共有 $count 笔。\n\n只清这一天，其它日期和其它模块都不受影响。',
    )) {
      return;
    }

    Haptics.warn();
    final deleted = await ledger.clearOn(picked);
    if (!mounted) return;
    _toast('已清空 $day 的 $deleted 笔账目');
  }

  // ---------------------------------------------------------------- 全部账目

  Future<void> _clearAllRecords() async {
    final ledger = context.read<LedgerProvider>();
    final count = ledger.records.length;
    if (count == 0) {
      _toast('账本本来就是空的', icon: Icons.info_outline);
      return;
    }
    if (!await _confirm(
      title: '清空全部账目？',
      body: '共 $count 笔账目会被删除。\n\n倒计时和待办不受影响。这个操作无法恢复。',
    )) {
      return;
    }

    Haptics.warn();
    final deleted = await ledger.clearAll();
    if (!mounted) return;
    _toast('已清空 $deleted 笔账目');
  }

  // ---------------------------------------------------------------- 全部数据

  Future<void> _clearEverything() async {
    final ledger = context.read<LedgerProvider>();
    final countdowns = context.read<CountdownProvider>();
    final todos = context.read<TodoProvider>();

    final records = ledger.records.length;
    final events = countdowns.events.length;
    final items = todos.items.length;

    if (records == 0 && events == 0 && items == 0) {
      _toast('没有可清空的数据', icon: Icons.info_outline);
      return;
    }

    if (!await _confirm(
      title: '清空全部数据？',
      body:
          '账目 $records 笔、倒计时 $events 个、待办 $items 条都会被删除，'
          '同时撤掉所有已经排定的提醒。\n\n这个操作无法恢复。',
    )) {
      return;
    }
    // 不可撤销，所以再拦一次
    if (!await _confirm(
      title: '再确认一次',
      body: '确定要清空吗？清空之后数据找不回来了。',
      action: '确认清空',
    )) {
      return;
    }

    setState(() => _busy = true);
    Haptics.warn();
    // 各模块内部都是"先逐条取消自己的提醒、再删库"
    final clearedRecords = await ledger.clearAll();
    final clearedEvents = await countdowns.clearAll();
    final clearedItems = await todos.clearAll();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      '已清空：账目 $clearedRecords 笔 · 倒计时 $clearedEvents 个 · '
      '待办 $clearedItems 条',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ledger = context.watch<LedgerProvider>();
    final countdowns = context.watch<CountdownProvider>();
    final todos = context.watch<TodoProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('清空数据')),
      body: ListView(
        // 顶栏是彩色条，内容顶部留 14 不贴上去
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          // 先摆清楚"现在有什么"，让人知道这一步的分量
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 19,
                        color: p.inkSoft,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '现在的数据',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _CountChip(
                        label: '账目',
                        value: '${ledger.records.length} 笔',
                      ),
                      const SizedBox(width: 8),
                      _CountChip(
                        label: '倒计时',
                        value: '${countdowns.events.length} 个',
                      ),
                      const SizedBox(width: 8),
                      _CountChip(
                        label: '待办',
                        value: '${todos.items.length} 条',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('按天清'),
          Card(
            child: _ClearRow(
              icon: Icons.event_busy_outlined,
              title: '清空某一天的账目',
              subtitle: '只改错了一天，不用全清',
              onTap: _busy ? null : _clearDay,
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('只清账本'),
          Card(
            child: _ClearRow(
              icon: Icons.receipt_long_outlined,
              title: '清空全部账目',
              subtitle: '倒计时和待办保留',
              onTap: _busy ? null : _clearAllRecords,
            ),
          ),
          const SizedBox(height: 22),

          const _SectionLabel('全部'),
          Card(
            child: _ClearRow(
              icon: Icons.warning_amber_rounded,
              title: '清空全部数据',
              subtitle: '账目 + 倒计时 + 待办，并撤掉所有提醒',
              danger: true,
              onTap: _busy ? null : _clearEverything,
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '提醒一句：数据只存在这台手机里，清空之后没有任何办法找回。'
              '如果你只是想重新开始记账，「清空全部账目」就够了。',
              style: TextStyle(fontSize: 12, color: p.inkSoft, height: 1.7),
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
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: p.paper,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: p.line),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: p.inkFaint),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearRow extends StatelessWidget {
  const _ClearRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = danger ? p.danger : p.inkSoft;

    return Pressable(
      scale: 0.985,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: danger ? p.danger : p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: p.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: p.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
