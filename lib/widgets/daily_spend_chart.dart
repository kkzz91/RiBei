import 'package:flutter/material.dart';

import '../models/transaction_record.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

/// 账本页的「这个月每天花多少」柱状图。
///
/// 用户要求（v1.6.15）："每日柱状图的话也可以搞一下，在流水那里可以查看"。
///
/// 交互抄的是参考项目的做法：**点某一天的柱子 → 上面那行变成那天的日期和金额**，
/// 再点一次收回。只画**支出**（收入不是每天都有，画出来一片空白）。
class DailySpendChart extends StatefulWidget {
  const DailySpendChart({
    super.key,
    required this.month,
    required this.records,
  });

  /// 看哪个月（只用年月）
  final DateTime month;
  final List<TransactionRecord> records;

  @override
  State<DailySpendChart> createState() => _DailySpendChartState();
}

class _DailySpendChartState extends State<DailySpendChart> {
  int? _picked;

  @override
  void didUpdateWidget(DailySpendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换月份时把选中清掉，不然会指着"上个月没有的那一天"
    if (oldWidget.month != widget.month) _picked = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final days = DateTime(widget.month.year, widget.month.month + 1, 0).day;

    // 每天花了多少
    final byDay = List<double>.filled(days + 1, 0);
    for (final r in widget.records) {
      if (r.type != TxType.expense) continue;
      if (r.date.year != widget.month.year ||
          r.date.month != widget.month.month) {
        continue;
      }
      final d = r.date.day;
      if (d >= 1 && d <= days) byDay[d] += r.amount;
    }
    final total = byDay.fold<double>(0, (a, b) => a + b);
    var max = 0.0;
    for (final v in byDay) {
      if (v > max) max = v;
    }

    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: p.inkSoft),
                const SizedBox(width: 8),
                Text(
                  '这个月每天花多少',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  _picked == null
                      ? '共 ${formatMoney(total)}'
                      : '${widget.month.month}月$_picked日 · '
                            '${formatMoney(byDay[_picked!])}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _picked == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: _picked == null ? p.inkFaint : p.jade,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var d = 1; d <= days; d++)
                    Expanded(
                      child: GestureDetector(
                        // 柱子只有几像素宽，命中区得放宽一点
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(
                          () => _picked = _picked == d ? null : d,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: _Bar(
                            value: byDay[d],
                            max: max,
                            picked: _picked == d,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 只标 1 / 10 / 20 / 月末，不然 31 个数字挤成一排
            Row(
              children: [
                for (var d = 1; d <= days; d++)
                  Expanded(
                    child: Text(
                      // 只标 1 / 10 / 20 / 月末：写 `d % 10 == 0` 的话，
                      // 31 天的月份里 30 和 31 会挨在一起挤成"3031"
                      d == 1 || d == 10 || d == 20 || d == days ? '$d' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: p.inkFaint),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.picked});

  final double value;
  final double max;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // 有花销的至少给 3dp，不然 1 块钱和 0 块钱看起来一样
    final h = value <= 0 ? 2.0 : (value / max * 40).clamp(3.0, 40.0);
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: value <= 0
            ? p.line
            : (picked ? p.jadeDeep : p.jade.withValues(alpha: 0.82)),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
