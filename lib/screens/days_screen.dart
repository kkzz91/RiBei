import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/countdown_event.dart';
import '../models/day_row.dart';
import '../models/milestone.dart';
import '../providers/countdown_provider.dart';
import '../providers/milestone_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/empty_state.dart';
import '../widgets/hollow_text.dart';
import '../widgets/pressable.dart';
import '../widgets/reminder_status_banner.dart';
import 'add_countdown_screen.dart';
import 'countdown_detail_screen.dart';
import 'edit_milestone_screen.dart';
import 'milestone_detail_screen.dart';

/// 「日子」——**倒计时和纪念日合并后的那一个板块**。
///
/// 版式抄参考图 `样图2.jpg`：
///   ① 顶栏「RiBei Day」+ **右上角一个 ⊕ 新建**（参考图的添加就在右上角）；
///   ② **置顶的那一条放大成"头条卡"**（名字 + 还有/已经 + 大数字 + 目标日）；
///   ③ 其余是**紧凑行**：名字 + 还有/已经 在左，右边一个**彩色数字徽标**。
///      参考图就是这样 —— 一屏能看到七八条，不会像以前每张卡都占半屏。
///
/// 倒计时和纪念日在数据上仍是两张表（字段差别太大），
/// 合并只发生在**显示层**：这里把它们统一成 [DayRow] 再一起排序。
class DaysScreen extends StatelessWidget {
  const DaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final countdowns = context.watch<CountdownProvider>();
    final milestones = context.watch<MilestoneProvider>();

    final rows = DayRow.merge(countdowns.events, milestones.items);

    final ready = countdowns.ready && milestones.ready;
    final featured = rows.isEmpty ? null : rows.first;
    final rest = rows.length <= 1 ? const <DayRow>[] : rows.sublist(1);

    return Scaffold(
      appBar: AppBar(
        // 镂空透明立体字（用户要的质感）
        title: SizedBox(
          height: 34,
          child: Align(
            alignment: Alignment.centerLeft,
            child: HollowText(
              'RiBei Day',
              size: 21,
              color: context.palette.jade,
              tracking: 1.2,
              strokeWidth: 1.2,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '新建',
            icon: const Icon(Icons.add_circle_outline, size: 26),
            onPressed: () => _openAdd(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !ready
          ? const SizedBox.shrink()
          : rows.isEmpty
          ? const EmptyState(
              icon: Icons.event_note_outlined,
              title: '还没有日子',
              hint: '把「期末考试」「在一起」这些日子记下来，\n它会帮你数着还有多久、或者已经过去多久。',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                const ReminderStatusBanner(),
                if (featured != null) ...[
                  const _Banner('最要紧的那天'),
                  _HeadlineCard(
                    row: featured,
                    onTap: () => _openDetail(context, featured),
                    onLongPress: () => _rowActions(context, featured),
                  ),
                  const SizedBox(height: 20),
                ],
                if (rest.isNotEmpty) ...[
                  _Banner('全部日子', trailing: '共 ${rows.length} 条'),
                  // **每一条独立成框**（用户要求：不要连成一整张纸）
                  for (final r in rest)
                    _DayTile(
                      row: r,
                      onTap: () => _openDetail(context, r),
                      onLongPress: () => _rowActions(context, r),
                    ),
                ],
              ],
            ),
    );
  }

  // ---------------------------------------------------------------- 动作

  Future<void> _openAdd(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: const Text('新建倒计时'),
              subtitle: const Text('设个未来的日子，临近时每天提醒你'),
              onTap: () => Navigator.pop(ctx, 'countdown'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('新建纪念日'),
              subtitle: const Text('记下「在一起」这种日子，帮你正计时'),
              onTap: () => Navigator.pop(ctx, 'milestone'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    Haptics.tap();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => choice == 'countdown'
            ? const AddCountdownScreen()
            : const EditMilestoneScreen(),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, DayRow row) async {
    Haptics.tap();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => row.isMilestone
            ? MilestoneDetailScreen(milestoneId: row.id)
            : CountdownDetailScreen(countdownId: row.id),
      ),
    );
  }

  /// 长按一条：置顶 / 编辑 / 删除
  Future<void> _rowActions(BuildContext context, DayRow row) async {
    Haptics.warn();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(row.title, style: AppText.sectionTitle(ctx)),
                ),
              ),
              ListTile(
                leading: Icon(
                  row.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(row.pinned ? '取消置顶' : '置顶到最上面'),
                onTap: () => Navigator.pop(ctx, 'pin'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: p.danger),
                title: Text('删除', style: TextStyle(color: p.danger)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'pin':
        await _togglePin(context, row);
      case 'edit':
        await _edit(context, row);
      case 'delete':
        await _confirmDelete(context, row);
    }
  }

  /// 置顶是"**全局最多一个**"：先把它自己那类里的都取消，再置顶这一个。
  Future<void> _togglePin(BuildContext context, DayRow row) async {
    final countdowns = context.read<CountdownProvider>();
    final milestones = context.read<MilestoneProvider>();
    final next = !row.pinned;

    if (next) {
      for (final e in countdowns.events) {
        if (e.pinned) await countdowns.save(e.copyWith(pinned: false));
      }
      for (final m in milestones.items) {
        if (m.pinned) await milestones.save(m.copyWith(pinned: false));
      }
    }
    if (row.isMilestone) {
      final m = _findMilestone(milestones, row.id);
      if (m != null) await milestones.save(m.copyWith(pinned: next));
    } else {
      final e = _findCountdown(countdowns, row.id);
      if (e != null) await countdowns.save(e.copyWith(pinned: next));
    }
  }

  Future<void> _edit(BuildContext context, DayRow row) async {
    Haptics.tap();
    if (row.isMilestone) {
      final m = _findMilestone(context.read<MilestoneProvider>(), row.id);
      if (m == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditMilestoneScreen(existing: m),
        ),
      );
    } else {
      final e = _findCountdown(context.read<CountdownProvider>(), row.id);
      if (e == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AddCountdownScreen(existing: e)),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, DayRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${row.title}」？'),
        content: Text(
          row.isMilestone
              ? '删掉后就没有了。'
              : '删除后，已排定的提醒也会一并取消。',
        ),
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
    if (row.isMilestone) {
      await context.read<MilestoneProvider>().remove(row.id);
    } else {
      await context.read<CountdownProvider>().remove(row.id);
    }
  }

  static Milestone? _findMilestone(MilestoneProvider p, int id) {
    for (final m in p.items) {
      if (m.id == id) return m;
    }
    return null;
  }

  static CountdownEvent? _findCountdown(CountdownProvider p, int id) {
    for (final e in p.events) {
      if (e.id == id) return e;
    }
    return null;
  }
}

/// 数字徽标的配色：**还没到 = 蓝、已经过去 = 橙**（和参考图一个语义）。
/// 做成实色 + 白字，所以在深浅两种 App 主题下都读得清。
/// 用户反馈"区分不够清晰"，所以取的都是**饱和度更高**的一档。
Color _badgeColor(bool past) =>
    past ? const Color(0xFFE08A1E) : const Color(0xFF2E7DD1);

// ---------------------------------------------------------------- 头条卡

/// 置顶（或最近）的那一条，放大展示。
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({
    required this.row,
    required this.onTap,
    required this.onLongPress,
  });

  final DayRow row;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = _badgeColor(row.past);

    return Pressable(
      scale: 0.98,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.32 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (row.pinned) ...[
                          Icon(Icons.push_pin, size: 14, color: color),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            row.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 「还有 / 已经」和名字一样大（用户明确要求别缩小）
                        Text(
                          row.past ? '已经' : '还有',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: p.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${row.past ? '起始日' : '目标日'}：'
                      '${isoDateWithWeekday(row.date)}',
                      style: TextStyle(fontSize: 13, color: p.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 数字**不带那个小"天"**，而且**字体统一** ——
              // 自选的数字字体只在点进去的详情页生效（用户要求：列表页别混着来）
              Text(
                '${row.days}',
                style: TextStyle(
                  fontSize: 58,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 紧凑行

/// 普通的一条：**自己一个独立的框**（用户要求别连在一起），
/// 名字 + 还有/已经 在左，彩色数字徽标在右。
/// 字号 17、上下各 13dp —— 用户要的"字大一点、把框撑饱满"。
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.row,
    required this.onTap,
    required this.onLongPress,
  });

  final DayRow row;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = _badgeColor(row.past);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: p.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.26 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              if (row.pinned) ...[
                Icon(Icons.push_pin, size: 15, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 「还有 / 已经」**和名字一样大**（用户明确要求别缩小）
                    Text(
                      row.past ? '已经' : '还有',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Badge(days: row.days, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// 彩色数字徽标。
///
/// ⚠️ **宽度固定**：用户反馈"个位数和三位数框的长度不一样，要统一" ——
/// 数字在固定宽的槽里居中，位数变了框也不变。
/// ⚠️ **不带那个小「天」**（用户要求删掉）—— 方向看左边的「还有 / 已经」就够了。
/// ⚠️ **字体统一**（用户要求：列表页别跟着自选字体走，那样看着乱；
///    自选的数字字体只在**点进去的详情页**生效）。
class _Badge extends StatelessWidget {
  const _Badge({required this.days, required this.color});

  final int days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$days',
          maxLines: 1,
          style: const TextStyle(
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 每个模块上面那条"**横帘**"：整宽的一条淡色带 + 一个竖色条 + 标题。
/// 用户说加了它"看起来更清晰" —— 它把模块之间的边界画出来了。
class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.jadeSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(width: 3, height: 14, color: p.jade),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.jade,
              ),
            ),
            const Spacer(),
            if (trailing != null)
              Text(
                trailing!,
                style: AppText.label(context).copyWith(fontSize: 11.5),
              ),
          ],
        ),
      ),
    );
  }
}
