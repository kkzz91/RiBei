import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/milestone.dart';
import '../providers/milestone_provider.dart';
import '../theme/milestone_themes.dart';
import '../utils/haptics.dart';
import '../widgets/milestone_card.dart';
import '../widgets/poster_screen.dart';
import 'add_day_screen.dart';

/// 纪念日详情。
///
/// 版式、浮动按钮、分享截图全在共用的 [PosterScreen] 里；
/// 这里只负责找到这个纪念日、把名字交给编辑页。
///
/// ⚠️ **海报必须交给 `PosterScreen` 去摆**，不要自己在外面套
/// `SingleChildScrollView` / `ConstrainedBox(minHeight)` ——
/// 那样海报最外层的 `Stack` 会拿到**无界高度**，`size` 变成无限大，
/// 背景图案里按固定步长画线的循环就会**永远转下去**（debug 是断言报错，
/// release 断言被关掉 → **整个 App 卡死**）。这个坑踩过一次，见红线 28 ④。
class MilestoneDetailScreen extends StatelessWidget {
  const MilestoneDetailScreen({super.key, required this.milestoneId});

  final int milestoneId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MilestoneProvider>();
    final milestone = _milestone(provider);

    return PosterScreen(
      style: themeStyleOf(milestone.theme),
      // 第二个参数就是卡片下面那排按钮；分享截图时它是 null（图里不要按钮）
      posterBuilder: (context, actions) =>
          MilestoneCard(milestone: milestone, actions: actions),
      shareFileName: '纪念日-${milestone.title}',
      shareText: '「${milestone.title}」已经 ${milestone.elapsed.totalDays} 天',
      onEdit: () async {
        Haptics.tap();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddDayScreen(milestone: milestone),
          ),
        );
      },
    );
  }

  Milestone _milestone(MilestoneProvider provider) {
    for (final m in provider.items) {
      if (m.id == milestoneId) return m;
    }
    return Milestone(
      title: '（已删除）',
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }
}
