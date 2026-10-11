import '../theme/digit_fonts.dart';

/// 纪念日的背景主题
///
/// ⚠️ **这些常量的数值就是存进数据库 `milestones.theme` 的值，也是
/// `milestoneThemeStyles` 里的下标。只许往后加，不许插入或调整顺序** ——
/// 否则老数据的主题会集体换掉（和红线 9 的枚举取值是同一条规矩）。
class MilestoneTheme {
  const MilestoneTheme._();

  static const blackGold = 0; // 黑金
  static const jade = 1; // 玉青
  static const deepBlue = 2; // 深空蓝
  static const sunset = 3; // 暖橙日暮
  static const paper = 4; // 极简白
  static const pinkHearts = 5; // 粉雾爱心（v1.6.1 新增）
  static const wood = 6; // 原木（v1.6.1 新增）
  static const mint = 7; // 薄荷（v1.6.1 新增）

  static const all = <int>[
    blackGold,
    jade,
    deepBlue,
    sunset,
    paper,
    pinkHearts,
    wood,
    mint,
  ];

  static const labels = <int, String>{
    blackGold: '黑金',
    jade: '玉青',
    deepBlue: '深空蓝',
    sunset: '暖橙日暮',
    paper: '极简白',
    pinkHearts: '粉雾爱心',
    wood: '原木',
    mint: '薄荷',
  };
}

/// 已经过去多久。
///
/// [totalDays] 是**唯一没有歧义**的数（两个日期相差多少天），
/// 所以它当"第 N 天"的大字。
/// 年/月/日/时/分/秒是"借位法"算出来的美观拆解 —— 注意月份天数不一样，
/// 这个拆解只是"日历意义上的几周年零几天"，不是精确到毫秒的时长。
class MilestoneElapsed {
  const MilestoneElapsed({
    required this.years,
    required this.months,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.totalDays,
  });

  final int years;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  /// 从起始日到"今天"过了多少个整天（起始日当天 = 第 0 天）
  final int totalDays;

  bool get isFuture => totalDays < 0;

  /// 比如"3年2个月18天"
  String get yearMonthDay {
    if (years > 0) return '$years 年 $months 个月 $days 天';
    if (months > 0) return '$months 个月 $days 天';
    return '$days 天';
  }

  /// "12:34:56"
  String get clock => [
    hours,
    minutes,
    seconds,
  ].map((v) => v.toString().padLeft(2, '0')).join(':');

  /// 从 [start] 到 [now] 的拆解。
  ///
  /// **算法是"周年纪念日"语义**，不是简单借位：
  /// 先按整年、再按整月，用"逐月推进 + 天数夹到月末"的方式找到**最近的那个纪念日**，
  /// 剩下的整天数就是 [days]。这样对"跨月、月末、闰年 2 月 29 日"都稳定：
  /// - 1月31 → 3月1 = 1 个月 + 1 天（2月31 夹成 2月28）
  /// - 闰年 2月29 → 次年 2月28 = 整 1 年（周年被夹到 2月28）
  ///
  /// [totalDays] 是两个日期的整天差，是唯一没有歧义的数，当"第 N 天"的大字。
  /// 时/分/秒取的是"当天走到哪了"（即当前时刻），作为氛围感的实时走字。
  static MilestoneElapsed since(DateTime start, DateTime now) {
    final s = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    final totalDays = today.difference(s).inDays;

    if (totalDays < 0) {
      return MilestoneElapsed(
        years: 0,
        months: 0,
        days: totalDays,
        hours: 0,
        minutes: 0,
        seconds: 0,
        totalDays: totalDays,
      );
    }

    var anchor = s;
    var years = 0;
    var months = 0;

    while (true) {
      final next = _addMonths(anchor, 12);
      if (next.isAfter(today)) break;
      anchor = next;
      years++;
    }
    while (true) {
      final next = _addMonths(anchor, 1);
      if (next.isAfter(today)) break;
      anchor = next;
      months++;
    }
    final days = today.difference(anchor).inDays;

    return MilestoneElapsed(
      years: years,
      months: months,
      days: days,
      hours: now.hour,
      minutes: now.minute,
      seconds: now.second,
      totalDays: totalDays,
    );
  }

  /// 加 [months] 个月，日数夹到目标月的最后一天。
  static DateTime _addMonths(DateTime d, int months) {
    final m = d.month + months;
    final year = d.year + (m - 1) ~/ 12;
    final month = (m - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(year, month, day);
  }
}

/// 一个纪念日（正计时：从某个日子起，已经过了多久）
class Milestone {
  const Milestone({
    this.id,
    required this.title,
    required this.startDate,
    this.note = '',
    this.theme = MilestoneTheme.blackGold,
    this.pinned = false,
    this.digitFont = DigitFont.classic,
    required this.createdAt,
  });

  final int? id;
  final String title;

  /// 起始日，只用到年月日
  final DateTime startDate;

  final String note;
  final int theme;

  /// 在列表里置顶显示（同一时刻顶多置顶一个）
  final bool pinned;

  /// 那个超大天数用什么字体（见 [DigitFont]）
  final int digitFont;

  final DateTime createdAt;

  /// 从起始日到现在的实时拆解
  MilestoneElapsed get elapsed =>
      MilestoneElapsed.since(startDate, DateTime.now());

  /// 已经第几天（第 0 天 = 起始当天；"在一起的第 100 天"这种说法常加 1）
  int get dayNumber => elapsed.totalDays + 1;

  Milestone copyWith({
    int? id,
    String? title,
    DateTime? startDate,
    String? note,
    int? theme,
    bool? pinned,
    int? digitFont,
    DateTime? createdAt,
  }) {
    return Milestone(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      note: note ?? this.note,
      theme: theme ?? this.theme,
      pinned: pinned ?? this.pinned,
      digitFont: digitFont ?? this.digitFont,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'title': title,
    'start_date': startDate.millisecondsSinceEpoch,
    'note': note,
    'theme': theme,
    'pinned': pinned ? 1 : 0,
    'digit_font': digitFont,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Milestone fromMap(Map<String, Object?> m) => Milestone(
    id: m['id'] as int?,
    title: m['title'] as String,
    startDate: DateTime.fromMillisecondsSinceEpoch(m['start_date'] as int),
    note: (m['note'] as String?) ?? '',
    theme: m['theme'] as int? ?? MilestoneTheme.blackGold,
    pinned: (m['pinned'] as int? ?? 0) == 1,
    digitFont: m['digit_font'] as int? ?? DigitFont.classic,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );
}
