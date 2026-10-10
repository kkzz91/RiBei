import 'package:flutter/material.dart';

import '../models/milestone.dart';
import '../theme/milestone_themes.dart';
import '../utils/formatters.dart';

/// 纪念日那张"氛围感"卡片。
///
/// 它同时有两份用途：
/// ① 详情页里实时显示（每秒刷新一次）；② 分享出去的那张图（RepaintBoundary 直接截它）。
/// 因为配色来自 [MilestoneThemeStyle] 这套**固定配色**（不跟随 App 深浅色），
/// 所以屏幕上长什么样，分享出去就是什么样，颜色不会乱。
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({super.key, required this.milestone});

  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final style = themeStyleOf(milestone.theme);
    final elapsed = milestone.elapsed;
    final future = elapsed.isFuture;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.gradient,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            milestone.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: style.text,
              letterSpacing: 1,
            ),
          ),
          if (milestone.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              milestone.note,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: style.textSoft,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 26),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 一圈柔光
                Container(
                  width: 216,
                  height: 216,
                  decoration: BoxDecoration(
                    color: style.accentSoft,
                    shape: BoxShape.circle,
                  ),
                ),
                // 细环
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: style.accent, width: 1.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        future ? '还未开始' : '第 ${milestone.dayNumber} 天',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: style.accent,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        future ? '设一个未来的日子吧' : elapsed.yearMonthDay,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: style.textSoft),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        future ? '' : elapsed.clock,
                        style: TextStyle(
                          fontSize: 14,
                          color: style.textSoft,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            '起始于 ${formatFullDate(milestone.startDate)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: style.textSoft),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: style.divider),
          const SizedBox(height: 14),
          Text(
            '日贝 · 纪念',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: style.textSoft,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
