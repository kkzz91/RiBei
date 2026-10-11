import 'countdown_event.dart';
import 'milestone.dart';

/// 倒计时 / 纪念日合并成一条列表时用的**统一行模型**。
///
/// 两张表在数据库里是分开的（字段差别太大：倒计时有农历/重复/提醒，
/// 纪念日只有起始日），**合并只发生在显示层** —— 两边各自换算成 [DayRow] 再一起排序。
///
/// 抽成公开的纯数据类是为了能单测：**顺序是这块最容易出错的地方**
/// （置顶的要在最前、"还没到"的按由近及远、"已经过去"的排最后）。
class DayRow {
  const DayRow({
    required this.isMilestone,
    required this.id,
    required this.title,
    required this.past,
    required this.days,
    required this.pinned,
    required this.digitFont,
    required this.date,
  });

  /// true = 纪念日（正计时），false = 倒计时
  final bool isMilestone;
  final int id;
  final String title;

  /// true = 已经过去（"已经 N 天"），false = 还没到（"还有 N 天"）
  final bool past;

  /// 天数的**绝对值**（方向看 [past]）
  final int days;

  final bool pinned;
  final int digitFont;

  /// 倒计时是目标日，纪念日是起始日
  final DateTime date;

  static DayRow fromCountdown(CountdownEvent e) => DayRow(
    isMilestone: false,
    id: e.id ?? -1,
    title: e.title,
    past: e.daysLeft < 0,
    days: e.daysLeft.abs(),
    pinned: e.pinned,
    digitFont: e.digitFont,
    date: e.effectiveTarget,
  );

  static DayRow fromMilestone(Milestone m) {
    final e = m.elapsed;
    final future = e.isFuture;
    return DayRow(
      isMilestone: true,
      id: m.id ?? -1,
      title: m.title,
      past: !future,
      days: future ? -e.totalDays : e.totalDays,
      pinned: m.pinned,
      digitFont: m.digitFont,
      date: m.startDate,
    );
  }

  /// 排序：**置顶的永远第一**；然后"还没到"的由近及远；最后才是"已经过去"的。
  /// （参考图就是这个顺序：3 / 4 / 36 / 56 天在上，已经 42 / 6340 天在下）
  static int compare(DayRow a, DayRow b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    if (a.past != b.past) return a.past ? 1 : -1;
    return a.days.compareTo(b.days);
  }

  /// 把两类混在一起排好序
  static List<DayRow> merge(
    Iterable<CountdownEvent> countdowns,
    Iterable<Milestone> milestones,
  ) {
    return <DayRow>[
      ...countdowns.map(fromCountdown),
      ...milestones.map(fromMilestone),
    ]..sort(compare);
  }
}
