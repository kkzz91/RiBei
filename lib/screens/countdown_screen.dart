import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/countdown_event.dart';
import '../providers/countdown_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/milestone_themes.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../utils/lunar_date.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';
import '../widgets/reminder_status_banner.dart';
import 'add_countdown_screen.dart';
import 'countdown_detail_screen.dart';

class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  Future<void> _openEditor([CountdownEvent? existing]) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => AddCountdownScreen(existing: existing),
        ),
      );

  /// 点开看那张海报。改内容走海报页上的「背景 / 编辑」按钮 ——
  /// 和纪念日那边一样：点一下先看大的，别一点就跳进表单。
  void _openDetail(CountdownEvent event) {
    Haptics.tap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CountdownDetailScreen(countdownId: event.id ?? -1),
      ),
    );
  }

  Future<void> _confirmDelete(CountdownEvent event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个倒计时？'),
        content: Text(
          '「${event.title}」删除后，已排定的 ${event.leadDays + 1} 条提醒也会一并取消。',
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
    if (ok == true && mounted) {
      await context.read<CountdownProvider>().remove(event.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CountdownProvider>();
    final sort = context.watch<SettingsProvider>().countdownSort;
    final upcoming = provider.upcomingBy(sort);
    final archived = provider.archivedBy(sort);

    return Scaffold(
      appBar: AppBar(
        title: const Text('倒计时'),
        actions: [
          if (upcoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text('${upcoming.length} 个进行中', style: AppText.label(context)),
              ),
            ),
        ],
      ),
      floatingActionButton: Pressable(
        scale: 0.94,
        child: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('添加倒计时'),
        ),
      ),
      body: !provider.ready
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
              children: [
                if (upcoming.isNotEmpty || archived.isNotEmpty)
                  _SortBar(
                    value: sort,
                    onChanged: (v) {
                      Haptics.tap();
                      context.read<SettingsProvider>().setCountdownSort(v);
                    },
                  ),
                const ReminderStatusBanner(),
                if (upcoming.isEmpty && archived.isEmpty)
                  const EmptyState(
                    icon: Icons.hourglass_empty,
                    title: '还没有倒计时',
                    hint: '设个日子，临近时每天提醒你。\n提醒要在系统里把权限开全才会稳。',
                  )
                else ...[
                  if (upcoming.isNotEmpty) ...[
                    const _SectionLabel('进行中'),
                    for (final e in upcoming)
                      _CountdownCard(
                        event: e,
                        onTap: () => _openDetail(e),
                        onLongPress: () => _confirmDelete(e),
                      ),
                  ],
                  if (archived.isNotEmpty) ...[
                    _SectionLabel('已结束 · ${archived.length}'),
                    for (final e in archived)
                      _CountdownCard(
                        event: e,
                        onTap: () => _openDetail(e),
                        onLongPress: () => _confirmDelete(e),
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- 排序

/// 列表排序切换：剩余天数 / 添加时间 / 名称
class _SortBar extends StatelessWidget {
  const _SortBar({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Row(
        children: [
          Icon(Icons.swap_vert, size: 16, color: p.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  for (final s in CountdownSort.all)
                    Expanded(child: _seg(context, s)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, int sort) {
    final p = context.palette;
    final selected = sort == value;
    return GestureDetector(
      onTap: () => onChanged(sort),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.jade : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          CountdownSort.labels[sort] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                : p.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(text, style: AppText.sectionTitle(context)),
    );
  }
}

// ---------------------------------------------------------------- 卡片

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.event,
    required this.onTap,
    required this.onLongPress,
  });

  final CountdownEvent event;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = themeStyleOf(event.theme);
    final days = event.daysLeft;
    // 紧迫色只留给"左色条"和"临近标签"：这两处是**实色**，
    // 换到任何主题底色上都看得清。天数徽标和进度条改用主题强调色，
    // 否则在深色主题上会出现"深红压近黑"这种看不清的组合。
    final urgency = p.urgencyOf(days);
    final target = event.effectiveTarget;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        // 倒计时也用自己那套主题的底色 —— 和纪念日列表同一个口径
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: style.gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
        color: Colors.transparent,
        elevation: 0,
        // Card 自带的 4px 外边距会让底色和内容对不齐，这里去掉
        margin: EdgeInsets.zero,
        // 让内容按卡片圆角裁剪，左色条才不会和卡片描边叠成"两套框"
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: IntrinsicHeight(
            child: Row(
              // 色条自动撑满卡片高度
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: urgency),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: _DayBadge(
                    days: days,
                    color: style.accent,
                    isDark: style.isDark,
                    isPast: event.isPast,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 标题 + 标记
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                event.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: style.text,
                                ),
                              ),
                            ),
                            if (event.isClosingIn) ...[
                              const SizedBox(width: 6),
                              _Tag(
                                text: days == 0 ? '今天' : '$days 天内',
                                color: urgency,
                                solid: true,
                              ),
                            ],
                            if (event.isRepeating) ...[
                              const SizedBox(width: 6),
                              _Tag(
                                text: CountdownRepeat.labels[event.repeat] ?? '',
                                color: style.textSoft,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 日期（农历事件额外标注）
                        Row(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: 12,
                              color: style.textSoft,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatFullDate(target),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: style.textSoft,
                              ),
                            ),
                            if (event.isLunar) ...[
                              const SizedBox(width: 8),
                              Text(
                                '农历 ${LunarDate.monthName(event.lunarMonth)}月'
                                '${LunarDate.dayName(event.lunarDay)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: style.textSoft,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 9),
                        // 进度条
                        _ProgressBar(
                          value: event.progress,
                          color: style.accent,
                          track: style.textSoft,
                        ),
                        const SizedBox(height: 9),
                        // 提醒设置
                        Row(
                          children: [
                            Icon(
                              event.remindEnabled
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              size: 13,
                              color: event.remindEnabled
                                  ? style.accent
                                  : style.textSoft,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                event.remindEnabled
                                    ? '提前 ${event.leadDays} 天起 每天 '
                                          '${formatClock(event.remindHour, event.remindMinute)}'
                                    : '未开启提醒',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: style.textSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: style.textSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// 天数徽标。
///
/// 两轮修正的产物：
/// 1. 最早是 66px 宽的列 + 固定 36px 字号，**三位数会被挤成两行**；
/// 2. 改成"数字一行、单位一行"的分档字号后，虽然不折行了，
///    但**两位数的数字看着"飘在上面"** —— 原因是大字号的行盒有 ascent/descent 余量，
///    而数字字形只占上半部分，于是视觉上偏上、和下面的"天"对不齐。
///
/// 现在改成**数字和单位排在同一基线上**（`CrossAxisAlignment.baseline`），
/// 两者天然对齐，不再有"飘"的感觉；徽标固定高度，所以每张卡片的天数块位置一致。
/// 外面套 FittedBox 兜底，位数再多也只会整体缩小，不会折行。
class _DayBadge extends StatelessWidget {
  const _DayBadge({
    required this.days,
    required this.color,
    required this.isDark,
    required this.isPast,
  });

  final int days;
  final Color color;

  /// 取的是**主题**的深浅，不是 App 深浅色 —— 卡片底色来自主题
  final bool isDark;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final text = days.abs().toString();
    final size = switch (text.length) {
      1 => 34.0,
      2 => 32.0,
      3 => 25.0,
      _ => 19.0,
    };

    return Container(
      width: 82,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // 关键：两者以同一条基线对齐，数字再大也不会"浮"起来
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 2),
              Text(
                isPast ? '天前' : '天',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 细进度条：0 = 刚开始，满格 = 到日子了
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;

  /// 底槽颜色（跟着主题走，别用 App 的描边色 —— 那是给纸底设计的）
  final Color track;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            // 入场时从 0 长到当前进度，"已经过了多少"更有实感
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: track.withValues(alpha: 0.22),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).round()}%',
          style: TextStyle(fontSize: 10.5, color: track),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.solid = false});

  final String text;
  final Color color;

  /// 实心标签（底色即 [color]、字用白色）：用于"临近"这种必须一眼看见的标记，
  /// 免得低透明度色块压在深色主题上看不清
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: solid ? Colors.white : color,
        ),
      ),
    );
  }
}
