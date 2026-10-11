import '../utils/lunar_date.dart';

/// 用公历还是农历记这个日子
class CountdownCalendar {
  const CountdownCalendar._();
  static const solar = 0;
  static const lunar = 1;
}

/// 周期性
class CountdownRepeat {
  const CountdownRepeat._();
  static const none = 0;
  static const monthly = 1;
  static const yearly = 2;

  static const labels = <int, String>{
    none: '不重复',
    monthly: '每月',
    yearly: '每年',
  };
}

/// 倒计时列表的排序方式
class CountdownSort {
  const CountdownSort._();

  /// 剩余天数由近及远（默认）
  static const byDays = 0;

  /// 最近添加的在前
  static const byCreated = 1;

  /// 按名称拼音顺序（中文按字符序，够用）
  static const byTitle = 2;

  static const labels = <int, String>{
    byDays: '剩余天数',
    byCreated: '添加时间',
    byTitle: '名称',
  };

  static const all = <int>[byDays, byCreated, byTitle];

  /// 列表排序的比较器（纯函数，方便单测）。
  ///
  /// 「名称」对中文是按字符码排，不是拼音序 —— 够用，不值得为它引一个拼音库。
  /// 同名的再按剩余天数排，保证顺序稳定。
  static int compare(int sort, CountdownEvent a, CountdownEvent b) {
    switch (sort) {
      case byCreated:
        // 最近添加的在前
        return b.createdAt.compareTo(a.createdAt);
      case byTitle:
        final byTitle = a.title.compareTo(b.title);
        return byTitle != 0 ? byTitle : a.daysLeft.compareTo(b.daysLeft);
      default:
        return a.daysLeft.compareTo(b.daysLeft);
    }
  }
}

/// 一个倒计时事件
class CountdownEvent {
  const CountdownEvent({
    this.id,
    required this.title,
    required this.targetDate,
    this.note = '',
    this.remindEnabled = true,
    this.remindHour = 9,
    this.remindMinute = 0,
    this.calendar = CountdownCalendar.solar,
    this.lunarMonth = 1,
    this.lunarDay = 1,
    this.repeat = CountdownRepeat.none,
    this.leadDays = 3,
    this.theme = 0,
    required this.createdAt,
  });

  final int? id;
  final String title;

  /// 公历目标日；农历 + 每年重复时只作为"首次设立"的锚点，实际日子由农历字段算
  final DateTime targetDate;

  final String note;
  final bool remindEnabled;
  final int remindHour;
  final int remindMinute;

  /// [CountdownCalendar.solar] 或 [CountdownCalendar.lunar]
  final int calendar;

  /// 农历月，负数表示闰月；仅在 calendar 为农历时有意义
  final int lunarMonth;
  final int lunarDay;

  /// [CountdownRepeat]
  final int repeat;

  /// 提前几天开始提醒（默认 3）
  final int leadDays;

  /// 详情页海报的背景主题。
  ///
  /// **取值和纪念日共用同一套** —— 就是 `MilestoneTheme` 里那串常量，
  /// 也就是 `milestoneThemeStyles` 的下标；存进库的值同样**只许往后加**。
  final int theme;

  final DateTime createdAt;

  bool get isLunar => calendar == CountdownCalendar.lunar;
  bool get isRepeating => repeat != CountdownRepeat.none;

  /// 是不是「生日」类事件。
  ///
  /// 判定方式就是**名称或备注里出现「生日」两个字** —— 按用户的原话
  /// 「如果提到生日」来的，好处是**不用改数据库**，现有的事件立刻就能用。
  /// 代价是「给妈妈买生日礼物」这种也会被算成生日；真需要精确的话
  /// 得加一个显式开关（那就要动 schema 了）。
  bool get isBirthday =>
      title.contains('生日') ||
      title.contains('诞辰') ||
      note.contains('生日');

  /// 今天正好是这一天 —— 用来触发生日那个小惊喜
  bool get isBirthdayToday => isBirthday && daysLeft == 0;

  /// 真正要倒数到的那个日子。重复事件会自动滚到下一次。
  DateTime get effectiveTarget {
    switch (repeat) {
      case CountdownRepeat.monthly:
        return _rollMonthly();
      case CountdownRepeat.yearly:
        return _rollYearly();
      default:
        return targetDate;
    }
  }

  /// 距离目标日期的天数：>0 未到，0 就是今天，<0 已过
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = effectiveTarget;
    return DateTime(
      target.year,
      target.month,
      target.day,
    ).difference(today).inDays;
  }

  bool get isPast => daysLeft < 0;

  /// 是否已进入"提前提醒"窗口
  bool get isUrgentWindow {
    final d = daysLeft;
    return d >= 0 && d <= leadDays;
  }

  /// 是否已很临近（3 天内），用于卡片上的红色标记
  bool get isClosingIn {
    final d = daysLeft;
    return d >= 0 && d <= 3;
  }

  /// 进度条用：0 = 刚开始，1 = 到日子了
  double get progress {
    final target = effectiveTarget;
    final start = _progressStart(target);
    final total = target.difference(start).inSeconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// 距离目标还有多少天时该开始提醒
  int get safeLeadDays => leadDays < 1 ? 1 : (leadDays > 60 ? 60 : leadDays);

  // ---------- 内部 ----------

  DateTime _rollMonthly() {
    final today = _today();
    var candidate = _dayInMonth(today.year, today.month, targetDate.day);
    if (candidate.isBefore(today)) {
      final next = DateTime(today.year, today.month + 1);
      candidate = _dayInMonth(next.year, next.month, targetDate.day);
    }
    return candidate;
  }

  DateTime _rollYearly() {
    if (isLunar) {
      return LunarDate.nextOccurrence(
        lunarMonth: lunarMonth,
        lunarDay: lunarDay,
      );
    }
    final today = _today();
    var candidate = _dayInMonth(today.year, targetDate.month, targetDate.day);
    if (candidate.isBefore(today)) {
      candidate = _dayInMonth(
        today.year + 1,
        targetDate.month,
        targetDate.day,
      );
    }
    return candidate;
  }

  DateTime _progressStart(DateTime target) {
    switch (repeat) {
      case CountdownRepeat.monthly:
        final prev = DateTime(target.year, target.month - 1);
        return _dayInMonth(prev.year, prev.month, target.day);
      case CountdownRepeat.yearly:
        // 农历年约 354 天，用它近似上一轮；公历就是去年同一天
        return isLunar
            ? target.subtract(const Duration(days: 354))
            : _dayInMonth(target.year - 1, target.month, target.day);
      default:
        final created = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );
        return created.isBefore(target)
            ? created
            : target.subtract(const Duration(days: 1));
    }
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 某些月份没有 31 号，夹到当月最后一天
  static DateTime _dayInMonth(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > last ? last : day);
  }

  CountdownEvent copyWith({
    int? id,
    String? title,
    DateTime? targetDate,
    String? note,
    bool? remindEnabled,
    int? remindHour,
    int? remindMinute,
    int? calendar,
    int? lunarMonth,
    int? lunarDay,
    int? repeat,
    int? leadDays,
    int? theme,
    DateTime? createdAt,
  }) {
    return CountdownEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      note: note ?? this.note,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      remindHour: remindHour ?? this.remindHour,
      remindMinute: remindMinute ?? this.remindMinute,
      calendar: calendar ?? this.calendar,
      lunarMonth: lunarMonth ?? this.lunarMonth,
      lunarDay: lunarDay ?? this.lunarDay,
      repeat: repeat ?? this.repeat,
      leadDays: leadDays ?? this.leadDays,
      theme: theme ?? this.theme,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'title': title,
    'target_date': targetDate.millisecondsSinceEpoch,
    'note': note,
    'remind_enabled': remindEnabled ? 1 : 0,
    'remind_hour': remindHour,
    'remind_minute': remindMinute,
    'calendar': calendar,
    'lunar_month': lunarMonth,
    'lunar_day': lunarDay,
    'repeat_rule': repeat,
    'lead_days': leadDays,
    'theme': theme,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static CountdownEvent fromMap(Map<String, Object?> m) => CountdownEvent(
    id: m['id'] as int?,
    title: m['title'] as String,
    targetDate: DateTime.fromMillisecondsSinceEpoch(m['target_date'] as int),
    note: (m['note'] as String?) ?? '',
    remindEnabled: (m['remind_enabled'] as int? ?? 1) == 1,
    remindHour: m['remind_hour'] as int? ?? 9,
    remindMinute: m['remind_minute'] as int? ?? 0,
    calendar: m['calendar'] as int? ?? CountdownCalendar.solar,
    lunarMonth: m['lunar_month'] as int? ?? 1,
    lunarDay: m['lunar_day'] as int? ?? 1,
    repeat: m['repeat_rule'] as int? ?? CountdownRepeat.none,
    leadDays: m['lead_days'] as int? ?? 3,
    theme: m['theme'] as int? ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );
}
