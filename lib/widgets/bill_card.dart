import 'package:flutter/material.dart';

import '../models/stats.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

/// 可以分享出去的那张「账单卡片」。
///
/// 两个刻意的决定：
/// ① **永远用浅色主题**。分享到朋友圈的图，深色底既不好看也不清楚，
///    所以这里把卡片包进一个浅色 Theme，让 `context.palette` 取出浅色那一套，
///    而不是跟随 App 当前主题。
/// ② **纯展示、不碰数据库**。数据由 [BillSummary] 先算好传进来，
///    这样以后想换成导出 PDF / 图片以外的形式都不用动这里。
class BillCard extends StatelessWidget {
  const BillCard({super.key, required this.summary});

  final BillSummary summary;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Builder(builder: _buildCard),
    );
  }

  Widget _buildCard(BuildContext context) {
    final p = context.palette;
    final top = summary.topCategories;
    final maxAmount = top.isEmpty ? 0.0 : top.first.amount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.jade, p.jadeDeep],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- 品牌 ----------
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '日贝',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '记账 · 倒计时 · 待办',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '账单',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatDateRange(summary.from, summary.to),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          // ---------- 大数字 ----------
          Text(
            '支出',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(summary.expense),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(label: '收入', value: formatMoneyCompact(summary.income)),
              const SizedBox(width: 26),
              _MiniStat(
                label: summary.balance < 0 ? '超支' : '结余',
                value: formatMoneyCompact(summary.balance),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ---------- 明细（白底，像贴上去的一张纸）----------
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '花在哪了',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '共 ${summary.count} 笔',
                      style: TextStyle(fontSize: 11, color: p.inkFaint),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (top.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        '这段时间还没有支出',
                        style: TextStyle(fontSize: 12, color: p.inkFaint),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0) const SizedBox(height: 11),
                    _CategoryRow(
                      stat: top[i],
                      ratio: maxAmount > 0 ? top[i].amount / maxAmount : 0,
                      share: summary.expense > 0
                          ? top[i].amount / summary.expense
                          : 0,
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '数据只存在这台手机里 · 不联网不上传',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.stat,
    required this.ratio,
    required this.share,
  });

  /// 占最大那一类的比例，决定条形长度
  final double ratio;

  /// 占总支出的比例，显示百分比
  final double share;
  final CategoryStat stat;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = context.categoryColor(stat.category);

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(iconForCategory(stat.category), size: 12, color: color),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 42,
          child: Text(
            stat.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 7,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    // 留个下限，占比很小的也看得见一条
                    widthFactor: ratio.clamp(0.04, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 62,
          child: Text(
            formatMoneyCompact(stat.amount),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '${(share * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10.5, color: p.inkFaint),
          ),
        ),
      ],
    );
  }
}
