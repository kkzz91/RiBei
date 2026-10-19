import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stats.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/daily_spend_chart.dart';
import '../widgets/empty_state.dart';
import '../widgets/pie_3d.dart';
import 'daily_chart_screen.dart';
import 'share_bill_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _type = TxType.expense;

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<LedgerProvider>();
    final stats = ledger.categoryStats(_month, _type);
    final total = stats.fold<double>(0, (a, s) => a + s.amount);
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
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
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        // 顶栏是彩色条，内容顶部留 14 不贴上去
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _MonthBar(
            month: _month,
            onPrev: () => _shiftMonth(-1),
            onNext: isCurrent ? null : () => _shiftMonth(1),
          ),
          const SizedBox(height: 16),
          _TypeSwitch(
            type: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: 20),
          if (stats.isEmpty)
            _EmptyStats(type: _type)
          else ...[
            _PieCard(stats: stats, total: total, type: _type),
            const SizedBox(height: 16),
            _RankCard(stats: stats, total: total),
          ],
          const SizedBox(height: 24),
          _TrendCard(data: ledger.trend(6)),
          const SizedBox(height: 16),
          // 「每天花了多少」内联就能看（用户 v1.6.18）；右上角小按钮通向大图
          DailySpendChart(
            month: _month,
            records: ledger.records,
            onExpand: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DailyChartScreen(
                  month: _month,
                  records: ledger.records,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 月份

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _arrow(context, Icons.chevron_left, onPrev),
        Expanded(
          child: Center(
            child: Text(
              formatMonth(month),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.palette.ink,
              ),
            ),
          ),
        ),
        _arrow(context, Icons.chevron_right, onNext),
      ],
    );
  }

  Widget _arrow(BuildContext context, IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: onTap == null ? context.palette.line : context.palette.inkSoft,
      ),
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.type, required this.onChanged});

  final int type;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        children: [
          _seg(context, TxType.expense, '支出', context.palette.expense),
          _seg(context, TxType.income, '收入', context.palette.income),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, int value, String label, Color tint) {
    final selected = type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? tint : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.palette.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 饼图

class _PieCard extends StatelessWidget {
  const _PieCard({
    required this.stats,
    required this.total,
    required this.type,
  });

  final List<CategoryStat> stats;
  final double total;
  final int type;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isExpense = type == TxType.expense;
    final accent = isExpense ? p.expense : p.income;

    final slices = <PieSlice>[
      for (final s in stats)
        PieSlice(
          label: s.category,
          value: s.amount,
          color: context.categoryColor(s.category),
          icon: iconForCategory(s.category),
        ),
    ];

    // 卡片左右各有 16(页面) + 12(卡片) 的内边距；
    // 上限 250 是让饼尽量大 —— 立体饼图自己会把"厚度 + 抬起"的边距留出来，
    // 所以这里只需要保证横向放得下。
    final pieSize = math.min(MediaQuery.sizeOf(context).width - 108, 250.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        child: Column(
          children: [
            Pie3D(
              slices: slices,
              size: pieSize,
              centerIdle: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isExpense ? '总支出' : '总收入',
                    style: AppText.label(context).copyWith(fontSize: 11.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatMoneyCompact(total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '点扇形看明细',
                    style: AppText.label(context).copyWith(fontSize: 9.5),
                  ),
                ],
              ),
              centerFor: (slice, index) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(slice.icon, size: 17, color: slice.color),
                  const SizedBox(height: 3),
                  Text(
                    slice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoneyCompact(slice.value),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: slice.color,
                    ),
                  ),
                  Text(
                    '${(slice.value / total * 100).round()}%',
                    style: AppText.label(context).copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '共 ${stats.length} 个分类 · 点一下或长按扇形看明细',
              style: AppText.label(context).copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 排行

class _RankCard extends StatelessWidget {
  const _RankCard({required this.stats, required this.total});

  final List<CategoryStat> stats;
  final double total;

  @override
  Widget build(BuildContext context) {
    final maxAmount = stats.first.amount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('分类排行', style: AppText.sectionTitle(context)),
            const SizedBox(height: 14),
            for (var i = 0; i < stats.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: _RankRow(
                  stat: stats[i],
                  share: total > 0 ? stats[i].amount / total : 0,
                  ratio: maxAmount > 0 ? stats[i].amount / maxAmount : 0,
                  color: context.categoryColor(stats[i].category),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.stat,
    required this.share,
    required this.ratio,
    required this.color,
  });

  final CategoryStat stat;
  final double share;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(iconForCategory(stat.category), size: 17, color: color),
        const SizedBox(width: 9),
        SizedBox(
          width: 48,
          child: Text(
            stat.category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.palette.ink,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.palette.line,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          child: Text(
            formatMoneyCompact(stat.amount),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.palette.ink,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(share * 100).round()}%',
            textAlign: TextAlign.right,
            style: AppText.label(context).copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 趋势

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});

  final List<MonthStat> data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final values = <double>[
      for (final s in data) ...[s.expense, s.income],
    ];
    final peak = values.isEmpty ? 0.0 : values.reduce(math.max);
    // 顶上加 40% 的余量（原 25%）：手指按住柱子时弹出的提示框是画在**柱子上方**的，
    // 余量不够就会被顶到上面那行文字里去（用户 v1.6.18 报的"柱状图升起来挡到字"）。
    // 只有一个月有数据时最容易撞上 —— 那一根直接顶到顶。
    final maxY = peak <= 0 ? 100.0 : peak * 1.4;
    final now = DateTime.now();

    // 柱子的渐变色：底部是主色、顶部提亮，看起来有厚度
    LinearGradient rod(Color base) => LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [base, Color.lerp(base, Colors.white, 0.34) ?? base],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('近 6 个月', style: AppText.sectionTitle(context)),
                const Spacer(),
                _LegendDot(color: p.expense, label: '支出'),
                const SizedBox(width: 12),
                _LegendDot(color: p.income, label: '收入'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '点柱子看具体金额',
              style: AppText.label(context).copyWith(fontSize: 11),
            ),
            // 图和上面那两行字之间多留一点：提示框有地方站，就不会压到字
            const SizedBox(height: 22),
            SizedBox(
              height: 172,
              child: peak <= 0
                  ? Center(child: Text('还没有数据', style: AppText.label(context)))
                  : BarChart(
                      BarChartData(
                        maxY: maxY,
                        minY: 0,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(10),
                            tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            tooltipMargin: 8,
                            getTooltipColor: (_) =>
                                p.isDark ? const Color(0xFF35302B) : p.ink,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final m = data[group.x];
                              final isExpense = rodIndex == 0;
                              return BarTooltipItem(
                                '${m.month.month} 月\n'
                                '${isExpense ? '支出' : '收入'} '
                                '${formatMoneyCompact(isExpense ? m.expense : m.income)}',
                                TextStyle(
                                  color: p.isDark ? p.ink : Colors.white,
                                  fontSize: 12,
                                  height: 1.55,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 3,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: p.line, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= data.length) {
                                  return const SizedBox.shrink();
                                }
                                final month = data[i].month;
                                final isNow =
                                    month.year == now.year &&
                                    month.month == now.month;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${month.month}月',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isNow
                                          ? FontWeight.w800
                                          : FontWeight.w400,
                                      color: isNow ? p.jade : p.inkFaint,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < data.length; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 4,
                              barRods: [
                                BarChartRodData(
                                  toY: data[i].expense,
                                  width: 10,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  gradient: rod(p.expense),
                                ),
                                BarChartRodData(
                                  toY: data[i].income,
                                  width: 10,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  gradient: rod(p.income),
                                ),
                              ],
                            ),
                        ],
                      ),
                      // 数据变化时柱子长出来
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppText.label(context).copyWith(fontSize: 11.5)),
      ],
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats({required this.type});

  final int type;

  @override
  Widget build(BuildContext context) {
    final isExpense = type == TxType.expense;
    return EmptyState(
      icon: Icons.donut_large_outlined,
      title: '这个月没有${isExpense ? '支出' : '收入'}记录',
      hint: '记上几笔，这里就会有分类占比和排行',
    );
  }
}
