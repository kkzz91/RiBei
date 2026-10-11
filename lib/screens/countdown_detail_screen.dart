import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/countdown_event.dart';
import '../providers/countdown_provider.dart';
import '../theme/milestone_themes.dart';
import '../utils/haptics.dart';
import '../widgets/countdown_poster.dart';
import '../widgets/poster_screen.dart';
import 'add_day_screen.dart';

/// 倒计时详情。
///
/// 用的是和纪念日**同一个** [PosterScreen] + [DaysPoster] ——
/// 背景主题也是同一套 8 个，选哪个就在哪里显示（列表里也能看见）。
class CountdownDetailScreen extends StatelessWidget {
  const CountdownDetailScreen({super.key, required this.countdownId});

  final int countdownId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CountdownProvider>();
    final event = _event(provider);
    final days = event.daysLeft;

    return PosterScreen(
      style: themeStyleOf(event.theme),
      // 第二个参数就是卡片下面那排按钮；分享截图时它是 null（图里不要按钮）
      posterBuilder: (context, actions) =>
          CountdownPoster(event: event, actions: actions),
      shareFileName: '倒计时-${event.title}',
      shareText: days >= 0
          ? '「${event.title}」还有 $days 天'
          : '「${event.title}」已经过了 ${-days} 天',
      onEdit: () async {
        Haptics.tap();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddDayScreen(countdown: event),
          ),
        );
      },
    );
  }

  CountdownEvent _event(CountdownProvider provider) {
    for (final e in provider.events) {
      if (e.id == countdownId) return e;
    }
    return CountdownEvent(
      title: '（已删除）',
      targetDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }
}
