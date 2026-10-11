import 'package:flutter/material.dart';

import '../models/countdown_event.dart';
import '../models/milestone.dart';
import 'days_poster.dart';

/// 倒计时那张海报。
///
/// 版式、配色、图案全和纪念日共用 [DaysPoster]，差别只在这里：
/// 纪念日是"从某个起始日往今天正计时"，倒计时是"从今天往目标日倒数"。
class CountdownPoster extends StatelessWidget {
  const CountdownPoster({super.key, required this.event});

  final CountdownEvent event;

  @override
  Widget build(BuildContext context) {
    final days = event.daysLeft;
    final target = event.effectiveTarget;
    final past = days < 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);

    // 复用"周年纪念日"那套算法算"还有多久 / 过了多久" —— 和纪念日是同一个函数，
    // 所以"1月31 → 3月1 = 1 个月 1 天"这类边界在两边的口径完全一致。
    //
    // 注意 `since(a, b)` 在 b 晚于 a 时算的就是"从 a 到 b 的日历跨度"，
    // 所以往未来算不用另写一个函数。
    final span = past
        ? MilestoneElapsed.since(targetDay, today)
        : MilestoneElapsed.since(today, targetDay);

    return DaysPoster(
      title: event.title,
      note: event.note,
      theme: event.theme,
      headerLabel: days == 0 ? '就是今天' : (past ? '已经过了' : '还有'),
      days: days.abs(),
      breakdown: days == 0 ? '今天就是这一天' : span.yearMonthDay,
      dateLabel: '目标日',
      date: target,
      footer: '日贝 · 倒计时',
    );
  }
}
