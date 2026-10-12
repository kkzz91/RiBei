import 'package:flutter/material.dart';

import '../models/transaction_record.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

/// 「每天花了多少」的**大图页**（从账本页那一行点进来）。
///
/// 用户 v1.6.17：账本页那个小柱状图"挺小的，其实也看不清"，而且"长按也没有反馈"
/// ⇒ 改成**账本页只留一个入口**，点进来是满屏大图：
/// **手指在柱子上按住/左右滑动，上面就实时显示那一天的日期和金额**；
/// 下面跟一张按天列的表格（要精确数字的时候看它）。
class DailyChartScreen extends StatefulWidget {
  const DailyChartScreen({
    super.key,
    required this.month,
    required this.records,
  });

  final DateTime month;
  final List<TransactionRecord> records;

  @override
  State<DailyChartScreen> createState() => _DailyChartScreenState();
}

class _DailyChartScreenState extends State<DailyChartScreen> {
  late DateTime _month;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.month.year, widget.month.month);
  }

  int get _days => DateTime(_month.year, _month.month + 1, 0).day;

  /// 这个月每天花了多少（下标 1..月末）＋ 每天几笔
  (List<double>, List<int>) _totals() {
    final amounts = List<double>.filled(_days + 1, 0);
    final counts = List<int>.filled(_days + 1, 0);
    for (final r in widget.records) {
      if (r.type != TxType.expense) continue;
      if (r.date.year != _month.year || r.date.month != _month.month) continue;
      final d = r.date.day;
      if (d < 1 || d > _days) continue;
      amounts[d] += r.amount;
      counts[d] += 1;
    }
    return (amounts, counts);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _picked = null;
    });
  }

  /// 手指落在柱子区的哪个位置 → 选中哪一天
  void _pickAt(double dx, double width) {
    if (width <= 0) return;
    final day = ((dx / width) * _days).floor() + 1;
    final next = day.clamp(1, _days);
    if (next != _picked) setState(() => _picked = next);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (amounts, counts) = _totals();
    final total = amounts.fold<double>(0, (a, b) => a + b);
    var max = 0.0;
    for (final v in amounts) {
      if (v > max) max = v;
    }
    final picked = _picked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('每天花了多少'),
        actions: [
          IconButton(
            tooltip: '上个月',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(-1),
          ),
          IconButton(
            tooltip: '下个月',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftMonth(1),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 28),
        children: [
          // 标题行：选中某天就显示那天的，没选就显示整月
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  picked == null
                      ? '${_month.year}年${_month.month}月'
                      : '${_month.month}月$picked日',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  picked == null
                      ? '共 ${formatMoney(total)}'
                      : '支出 ${formatMoney(amounts[picked])}',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: picked == null ? p.ink : p.jade,
                  ),
                ),
                const Spacer(),
                if (picked != null)
                  Text(
                    '${counts[picked]} 笔',
                    style: TextStyle(fontSize: 12.5, color: p.inkFaint),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              picked == null ? '手指按住柱子左右滑动，看某一天花了多少' : '再点一次收回',
              style: TextStyle(fontSize: 12, color: p.inkFaint),
            ),
          ),
          const SizedBox(height: 14),

          // 大柱子。手指在整块区域上滑动都算，不用点准那根细柱。
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth - 32; // 左右各留 16
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _pickAt(d.localPosition.dx - 16, width),
                onHorizontalDragStart: (d) =>
                    _pickAt(d.localPosition.dx - 16, width),
                onHorizontalDragUpdate: (d) =>
                    _pickAt(d.localPosition.dx - 16, width),
                onTapUp: (d) {
                  // 点的是已经选中的那天 → 收回
                  final day = (((d.localPosition.dx - 16) / width) * _days)
                          .floor() +
                      1;
                  if (day.clamp(1, _days) == _picked) {
                    setState(() => _picked = null);
                  }
                },
                child: Container(
                  height: 220,
                  color: p.card,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var d = 1; d <= _days; d++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: _Bar(
                                    value: amounts[d],
                                    max: max,
                                    picked: picked == d,
                                    dim: picked != null && picked != d,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var d = 1; d <= _days; d++)
                            Expanded(
                              child: Text(
                                // 只标 1 / 10 / 20 / 月末，31 个数字会挤成一片
                                d == 1 || d == 10 || d == 20 || d == _days
                                    ? '$d'
                                    : '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: p.inkFaint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 表格：每天一行，要精确数字的时候看这里
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('按天看', style: AppText.sectionTitle(context)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: p.card,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.line),
              ),
              child: Column(
                children: [
                  for (var d = 1; d <= _days; d++)
                    if (amounts[d] > 0) ...[
                      if (d > 1) const Divider(height: 1, indent: 14, endIndent: 14),
                      InkWell(
                        onTap: () => setState(
                          () => _picked = _picked == d ? null : d,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 46,
                                child: Text(
                                  '$d 日',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.ink,
                                  ),
                                ),
                              ),
                              Text(
                                weekdayLabel(
                                  DateTime(_month.year, _month.month, d),
                                ),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.inkFaint,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${counts[d]} 笔',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.inkFaint,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                formatMoney(amounts[d]),
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  if (total <= 0)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        '这个月还没有支出',
                        style: TextStyle(fontSize: 13.5, color: p.inkFaint),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.max,
    required this.picked,
    required this.dim,
  });

  final double value;
  final double max;
  final bool picked;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // 有花销的至少给 3dp，不然 1 块钱和 0 块钱看起来一样
    final h = value <= 0 ? 2.0 : (value / max * 186).clamp(4.0, 186.0);
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: value <= 0
            ? p.line
            : (picked
                  ? p.jadeDeep
                  : p.jade.withValues(alpha: dim ? 0.35 : 0.85)),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
