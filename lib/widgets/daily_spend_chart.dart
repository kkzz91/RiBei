import 'package:flutter/material.dart';

import '../models/transaction_record.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

/// 「每天花了多少」的**内联版**：账本页和统计页各摆一张，**不用点开就能看**。
///
/// 用户 v1.6.18："每天花了多少那个条形图，我觉得可以在流水那里做一个、
/// 统计那里做一个，可以直接查看，不用点开的"。
/// （v1.6.17 曾经改成"只留一行入口"，他嫌要跳一步；这次两张内联 +
/// 右上角一个「展开」按钮通向大图 `DailyChartScreen`，两头都占。）
///
/// 手指按住柱子区左右滑动 → 上面那行变成那一天的金额；再点一下收回。
class DailySpendChart extends StatefulWidget {
  const DailySpendChart({
    super.key,
    required this.month,
    required this.records,
    this.onExpand,
    this.barHeight = 110,
  });

  /// 看哪个月（只用年月）
  final DateTime month;
  final List<TransactionRecord> records;

  /// 右上角「展开」按钮：一般传"打开大图页"。不传就不显示那个按钮。
  final VoidCallback? onExpand;

  /// 柱子区的高度（内联用 110，够看清）
  final double barHeight;

  @override
  State<DailySpendChart> createState() => _DailySpendChartState();
}

class _DailySpendChartState extends State<DailySpendChart> {
  int? _picked;

  @override
  void didUpdateWidget(DailySpendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换月份就把选中清掉，不然会指着"这个月没有的那一天"
    if (oldWidget.month != widget.month) _picked = null;
  }

  int get _days => DateTime(widget.month.year, widget.month.month + 1, 0).day;

  /// 每天花了多少（下标 1..月末）＋ 每天几笔
  (List<double>, List<int>) _totals() {
    final amounts = List<double>.filled(_days + 1, 0);
    final counts = List<int>.filled(_days + 1, 0);
    for (final r in widget.records) {
      if (r.type != TxType.expense) continue;
      if (r.date.year != widget.month.year ||
          r.date.month != widget.month.month) {
        continue;
      }
      final d = r.date.day;
      if (d < 1 || d > _days) continue;
      amounts[d] += r.amount;
      counts[d] += 1;
    }
    return (amounts, counts);
  }

  void _pickAt(double dx, double width) {
    if (width <= 0) return;
    final day = (((dx / width) * _days).floor() + 1).clamp(1, _days);
    if (day != _picked) setState(() => _picked = day);
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

    return Material(
      color: p.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: p.inkSoft),
                const SizedBox(width: 8),
                Text(
                  '每天花了多少',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  picked == null
                      ? '共 ${formatMoney(total)}'
                      : '${widget.month.month}月$picked日 '
                            '${formatMoney(amounts[picked])}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: picked == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: picked == null ? p.inkFaint : p.jade,
                  ),
                ),
                if (widget.onExpand != null)
                  IconButton(
                    tooltip: '看大图',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.open_in_full, size: 16, color: p.inkFaint),
                    onPressed: widget.onExpand,
                  )
                else
                  const SizedBox(width: 6),
              ],
            ),
            const SizedBox(height: 2),
            LayoutBuilder(
              builder: (context, c) {
                final width = c.maxWidth - 8;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pickAt(d.localPosition.dx - 4, width),
                  onHorizontalDragStart: (d) =>
                      _pickAt(d.localPosition.dx - 4, width),
                  onHorizontalDragUpdate: (d) =>
                      _pickAt(d.localPosition.dx - 4, width),
                  onTapUp: (d) {
                    final day =
                        (((d.localPosition.dx - 4) / width) * _days).floor() + 1;
                    if (day.clamp(1, _days) == _picked) {
                      setState(() => _picked = null);
                    }
                  },
                  child: SizedBox(
                    height: widget.barHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var d = 1; d <= _days; d++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: _Bar(
                                value: amounts[d],
                                max: max,
                                picked: picked == d,
                                dim: picked != null && picked != d,
                                maxHeight: widget.barHeight - 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  for (var d = 1; d <= _days; d++)
                    Expanded(
                      child: Text(
                        // 只标 1 / 10 / 20 / 月末，31 个数字会挤成一片
                        d == 1 || d == 10 || d == 20 || d == _days ? '$d' : '',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9.5, color: p.inkFaint),
                      ),
                    ),
                ],
              ),
            ),
            if (picked != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${counts[picked]} 笔',
                  style: TextStyle(fontSize: 11, color: p.inkFaint),
                ),
              ),
          ],
        ),
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
    required this.maxHeight,
  });

  final double value;
  final double max;
  final bool picked;
  final bool dim;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // 有花销的至少给 3px，不然 1 块钱和 0 块钱看起来一样
    final h = value <= 0
        ? 2.0
        : (value / max * maxHeight).clamp(3.0, maxHeight);
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: value <= 0
            ? p.line
            : (picked
                  ? p.jadeDeep
                  : p.jade.withValues(alpha: dim ? 0.32 : 0.85)),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
