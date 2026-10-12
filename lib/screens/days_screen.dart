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
import '../widgets/pressable.dart';
import '../widgets/reminder_status_banner.dart';
import 'add_day_screen.dart';
import 'countdown_detail_screen.dart';
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
        // 用户要求：这一页顶栏就写「倒计时」，不要那个英文品牌
        title: const Text('倒计时'),
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
              // 用户要求（v1.6.14）：列表**通栏** —— 置顶卡和每一条都贴屏幕左右边、
              // 宽度跟顶栏一样，"像覆盖住整个页面"（原来左右各留 16）。
              // 所以横向 padding 是 0，顶部仍留 14 不贴着顶栏。
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 32),
              children: [
                // 权限提示条是"旁白"不是列表内容，得自己留回左右边距
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ReminderStatusBanner(),
                ),
                if (featured != null) ...[
                  _HeadlineCard(
                    row: featured,
                    onTap: () => _openDetail(context, featured),
                    onLongPress: () => _rowActions(context, featured),
                  ),
                  const SizedBox(height: 14),
                ],
                // 用户要求删掉那两条"横帘"说明，列表直接铺开
                for (final r in rest)
                  _DayTile(
                    row: r,
                    onTap: () => _openDetail(context, r),
                    onLongPress: () => _rowActions(context, r),
                  ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------- 动作

  /// 新建：**不再问"倒计时还是纪念日"** —— 统一进一个页面，
  /// 由「选的日子在过去还是未来」自动决定（见 [AddDayScreen]）。
  Future<void> _openAdd(BuildContext context) async {
    Haptics.tap();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AddDayScreen()),
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
      await countdowns.unpinAll();
      await milestones.unpinAll();
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
        MaterialPageRoute<void>(builder: (_) => AddDayScreen(milestone: m)),
      );
    } else {
      final e = _findCountdown(context.read<CountdownProvider>(), row.id);
      if (e == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AddDayScreen(countdown: e)),
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

/// 数字徽标的配色：**还没到 = 玉青、已经过去 = 橙**。
///
/// 用户 v1.6.15："把倒计时那个也换成青色系吧，不要蓝的，橙的留着，统一一点好看"
/// —— 原来"还没到"用的是硬编码的蓝（0xFF2E7DD1），跟玉青顶栏不搭。
///
/// [deep] 那一档更深，专门给「天」那个小格子用 —— 两段深浅不同看起来才有质感
/// （用户对着参考图提的："人家那个单位那里颜色不一样"）。
/// 浅色模式取 `jade / jadeDeep`；深色模式整体是浅色底上的两档深绿，
/// 免得 `jade`（提亮过的那支）配白字太糊。
Color _badgeColor(AppPalette p, bool past) => past
    ? const Color(0xFFE08A1E)
    : (p.isDark ? p.jadeDeep : p.jade);

Color _badgeDeep(AppPalette p, bool past) => past
    ? const Color(0xFFB0650A)
    : (p.isDark
          ? Color.lerp(p.jadeDeep, Colors.black, 0.3)!
          : p.jadeDeep);

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
    final color = _badgeColor(p, row.past);

    return Pressable(
      scale: 0.98,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          // 置顶卡：**通栏方角**（左右贴边、宽度跟顶栏一样）+ 整体再大一圈
          // —— 用户："那个格子再大一点，宽度跟顶栏一样，像覆盖住整个页面"
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
          decoration: BoxDecoration(
            color: p.card,
            // 用户 v1.6.15："两边的蓝条消掉、顶上那条也消掉，就留一条蓝色的分割线"
            // —— 所以从"整圈彩色边框"改成"只有底部一条蓝线"。通栏方角不留圆角
            // （屏幕边上会露缺口）。
            border: Border(bottom: BorderSide(color: color, width: 2.4)),
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
              // 数字右边挂一颗红色小 DAY 标签（用户要的"单位"），底对齐
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${row.days}',
                    style: TextStyle(
                      fontSize: 64,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 9),
                    child: _DayTag(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 置顶卡右下角那颗**红色小长方形**，里面写英文大写的 `DAY`。
/// 用户："置顶那个没有单位，你搞一个红色的小长方形，里面写英文大写的 day，小小的，放在右边"
class _DayTag extends StatelessWidget {
  const _DayTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      decoration: BoxDecoration(
        color: context.palette.danger,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'DAY',
        style: TextStyle(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.white,
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
    final color = _badgeColor(p, row.past);

    return Padding(
      // 条与条之间留一条缝，**每条仍是自己的独立框**（用户 v1.6.7 明确要过"别连在一起"）
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // 通栏 + 方角（跟置顶卡、跟顶栏一个宽），并且**再细一点**：
          // 行高 40 → 36，字号保持 18 —— 相对行高就更"饱满"（用户这次要的）
          height: 36,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.card,
            border: Border.all(color: p.line),
          ),
          child: Row(
            // 让右边的徽标**撑满整条行高**（用户："弄得跟框一样大、站在右边"）
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      if (row.pinned) ...[
                        Icon(Icons.push_pin, size: 15, color: color),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          row.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 「还有 / 已经」和名字一样大（用户要求别缩小）
                      Text(
                        row.past ? '已经' : '还有',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: p.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _Badge(days: row.days, past: row.past, palette: p),
            ],
          ),
        ),
      ),
    );
  }
}

/// 彩色数字徽标。**两段式**：数字一段、单位"天"一段，
/// 单位那一段用**更深一档的同色**（用户："人家那个单位那里颜色不一样，
/// 这样看起来有质感"）。
/// 它**撑满整条行高、贴在右边**（用户："弄得跟框一样大、站在右边"）。
class _Badge extends StatelessWidget {
  const _Badge({
    required this.days,
    required this.past,
    required this.palette,
  });

  final int days;
  final bool past;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // 数字段：够宽才放得下三四位数（超了由 FittedBox 缩，不会挤成两行）
          width: 60,
          color: _badgeColor(palette, past),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$days',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 21,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Container(
          // 「天」这一段再长一点（v1.6.13 是 32，用户这次还要长一些）
          width: 36,
          color: _badgeDeep(palette, past),
          alignment: Alignment.center,
          child: const Text(
            '天',
            maxLines: 1,
            style: TextStyle(
              fontSize: 14.5,
              height: 1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
