import 'package:flutter/material.dart';

import '../models/milestone.dart';
import 'days_poster.dart';

/// 纪念日那张海报。
///
/// 版式、配色、图案全在共用的 [DaysPoster] 里 —— 这里只负责把 [Milestone]
/// 换算成海报要的那几个数（倒计时那边同理，走的是同一个组件）。
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({super.key, required this.milestone, this.actions});

  final Milestone milestone;

  /// 卡片下面那排按钮（由详情页传进来；分享截图时是 null）
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final elapsed = milestone.elapsed;
    final future = elapsed.isFuture;

    return DaysPoster(
      title: milestone.title,
      note: milestone.note,
      theme: milestone.theme,
      // 还没到起始日就倒数、已经过了就正计时 —— 对应参考图的「还有 / 已经」
      headerLabel: future ? '还有' : '已经',
      days: future ? -elapsed.totalDays : elapsed.totalDays,
      breakdown: future ? '还没到起始日' : elapsed.yearMonthDay,
      dateLabel: future ? '目标日' : '起始日',
      date: milestone.startDate,
      digitFont: milestone.digitFont,
      actions: actions,
    );
  }
}
