import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_record.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/budget_card.dart';
import '../widgets/daily_spend_chart.dart';
import '../widgets/empty_state.dart';
import '../widgets/pay_tag.dart';
import '../widgets/pressable.dart';
import 'settings_screen.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import 'add_transaction_screen.dart';
import 'search_screen.dart';
import 'share_bill_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _openEditor([TransactionRecord? existing]) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => AddTransactionScreen(existing: existing),
        ),
      );

  Future<void> _confirmDelete(TransactionRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这笔记录？'),
        content: Text(
          '${record.category}  ${formatMoney(record.amount)}'
          '${record.note.isEmpty ? '' : '\n备注：${record.note}'}',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<LedgerProvider>().remove(record.id!);
    if (!mounted) return;
    AppToast.show(
      context,
      '已删除 · ${record.category} ${formatMoney(record.amount)}',
      icon: Icons.delete_outline,
      tint: context.palette.inkSoft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final records = ledger.ofMonth(_month);
    final groups = _groupByDay(records);
    final isCurrentMonth =
        _month.year == DateTime.now().year && _month.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账本'),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () {
              Haptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            tooltip: '分享账单',
            icon: const Icon(Icons.ios_share),
            onPressed: () {
              Haptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShareBillScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Haptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '共 ${records.length} 笔',
                // ⚠️ 顶栏现在是深色底 —— 这里必须用浅色字。
                // 用 AppText.label() 那种跟随页面底色的深灰，会糊成一团（用户报过）。
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Pressable(
        scale: 0.94,
        child: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('记一笔'),
        ),
      ),
      body: ListView(
        // 顶栏是深色条了，内容要留一点间距，不然结余卡直接贴着顶栏很难看（用户反馈）
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
        children: [
          _SummaryCard(
            month: _month,
            expense: ledger.expenseOf(_month),
            income: ledger.incomeOf(_month),
            onPrev: () => _shiftMonth(-1),
            onNext: isCurrentMonth ? null : () => _shiftMonth(1),
          ),
          const SizedBox(height: 14),
          // 本月预算（总额 + 用户自己设的那几条金额红线）
          BudgetCard(monthExpense: ledger.expenseOf(_month)),
          const SizedBox(height: 12),
          DailySpendChart(month: _month, records: ledger.records),
          const SizedBox(height: 22),
          if (groups.isEmpty)
            EmptyState(
              icon: ledger.records.isEmpty
                  ? Icons.receipt_long_outlined
                  : Icons.calendar_month_outlined,
              title: ledger.records.isEmpty
                  ? '还没有记过一笔账'
                  : '${_month.month} 月还没有记账',
              hint: ledger.records.isEmpty
                  ? '点右下角「记一笔」开始。\n像午饭 15 块这种常花的，存成常用后一点就记好了'
                  : '点右下角「记一笔」补上，或左右切换月份看看',
            )
          else
            for (var i = 0; i < groups.length; i++)
              StaggeredFadeIn(
                index: i,
                child: _DayGroup(
                  day: groups[i].key,
                  items: groups[i].value,
                  onTap: _openEditor,
                  onLongPress: _confirmDelete,
                ),
              ),
        ],
      ),
    );
  }

  List<MapEntry<DateTime, List<TransactionRecord>>> _groupByDay(
    List<TransactionRecord> list,
  ) {
    final buckets = <DateTime, List<TransactionRecord>>{};
    for (final r in list) {
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      buckets.putIfAbsent(day, () => <TransactionRecord>[]).add(r);
    }
    return buckets.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  }
}

// ---------------------------------------------------------------- 概览卡

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.month,
    required this.expense,
    required this.income,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final double expense;
  final double income;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    // 结余为正用玉青（有余），入不敷出换成赭红警示
    final balance = income - expense;
    final isDeficit = balance < 0;
    final top = isDeficit ? context.palette.deficit : context.palette.jade;
    final bottom = isDeficit ? context.palette.deficitDeep : context.palette.jadeDeep;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: top.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StepButton(icon: Icons.chevron_left, onTap: onPrev),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  formatMonth(month),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StepButton(icon: Icons.chevron_right, onTap: onNext),
              const Spacer(),
              Text(
                isDeficit ? '本月超支' : '本月结余',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 换月份时数字滚一下，切换动作看起来是"切过去了"而不是"跳过去了"
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: balance),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              formatMoney(v),
              style: AppText.amountHero(context).copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.16)),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                label: '收入',
                value: income,
                icon: Icons.south_west_rounded,
              ),
              const SizedBox(width: 26),
              _MiniStat(
                label: '支出',
                value: expense,
                icon: Icons.north_east_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.28),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.75)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              formatMoneyCompact(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 流水

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.day,
    required this.items,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime day;
  final List<TransactionRecord> items;
  final ValueChanged<TransactionRecord> onTap;
  final ValueChanged<TransactionRecord> onLongPress;

  @override
  Widget build(BuildContext context) {
    final net = items.fold<double>(0, (a, r) => a + r.signedAmount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(groupHeader(day), style: AppText.sectionTitle(context)),
                const Spacer(),
                Text(
                  '${net >= 0 ? '+' : '-'}${formatMoneyCompact(net.abs())}',
                  style: AppText.label(context).copyWith(
                    color: net >= 0 ? context.palette.income : context.palette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 70, endIndent: 16),
                  _RecordTile(
                    record: items[i],
                    onTap: () => onTap(items[i]),
                    onLongPress: () => onLongPress(items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.onTap,
    required this.onLongPress,
  });

  final TransactionRecord record;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isExpense = record.isExpense;
    // 图标底色用分类专属色，和记一笔、统计里保持一致
    final tint = context.categoryColor(record.category);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(iconForCategory(record.category), size: 20, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.category,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.palette.ink,
                    ),
                  ),
                  if (record.note.isNotEmpty ||
                      PayMethod.isRecorded(record.payMethod)) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (record.note.isNotEmpty)
                          Flexible(
                            child: Text(
                              record.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label(context),
                            ),
                          ),
                        if (PayMethod.isRecorded(record.payMethod)) ...[
                          if (record.note.isNotEmpty) const SizedBox(width: 6),
                          PayTag(method: record.payMethod, compact: true),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${isExpense ? '-' : '+'}${formatMoney(record.amount)}',
              style: AppText.amount(context).copyWith(
                color: isExpense ? context.palette.ink : context.palette.income,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
