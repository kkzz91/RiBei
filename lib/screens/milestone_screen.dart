import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/milestone.dart';
import '../providers/milestone_provider.dart';
import '../theme/app_theme.dart';
import '../theme/milestone_themes.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';
import 'edit_milestone_screen.dart';
import 'milestone_detail_screen.dart';

/// 纪念日列表（正计时：从某天起，已经过了多久）
class MilestoneScreen extends StatelessWidget {
  const MilestoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MilestoneProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('纪念日'),
        actions: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text('${items.length} 个', style: AppText.label(context)),
              ),
            ),
        ],
      ),
      floatingActionButton: Pressable(
        scale: 0.94,
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const EditMilestoneScreen(),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('新建纪念日'),
        ),
      ),
      body: !provider.ready
          ? const SizedBox.shrink()
          : items.isEmpty
          ? const EmptyState(
              icon: Icons.favorite_outline,
              title: '还没有纪念日',
              hint: '把「在一起」「入职」这些值得记住的日子记下来，\n它会一天天为你正计时。',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
              children: [
                for (final m in items)
                  Pressable(
                    scale: 0.98,
                    child: _MilestoneTile(milestone: m),
                  ),
              ],
            ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});

  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final style = themeStyleOf(milestone.theme);
    final elapsed = milestone.elapsed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  MilestoneDetailScreen(milestoneId: milestone.id ?? -1),
            ),
          );
        },
        onLongPress: () => _confirmDelete(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: style.gradient,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: style.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '起始于 ${formatFullDate(milestone.startDate)}'
                      '${milestone.note.isEmpty ? '' : ' · ${milestone.note}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: style.textSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    elapsed.isFuture ? '未开始' : '第 ${milestone.dayNumber} 天',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: style.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    elapsed.isFuture ? '' : elapsed.yearMonthDay,
                    style: TextStyle(fontSize: 11, color: style.textSoft),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个纪念日？'),
        content: Text('「${milestone.title}」删掉后就没有了。'),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ctx.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<MilestoneProvider>().remove(milestone.id!);
  }
}
