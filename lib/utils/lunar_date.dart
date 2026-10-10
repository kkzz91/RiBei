import 'package:lunar/lunar.dart';

/// 农历工具。
///
/// 依赖 `lunar` 包（纯 Dart，无原生代码）。几个容易踩的点：
///  * `Lunar.fromYmd` 里**闰月用负数表示**（-8 = 闰八月）
///  * 农历月只有 29 或 30 天，用户设的"三十"可能在当月不存在，要夹到月末
///  * 公历日期的农历年份不等于公历年份（春节前还算上一年），必须查表
class LunarDate {
  const LunarDate._();

  static const _monthNames = <String>[
    '正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊',
  ];

  static String monthName(int month) {
    final abs = month.abs();
    if (abs < 1 || abs > 12) return '';
    return (month < 0 ? '闰' : '') + _monthNames[abs - 1];
  }

  /// 农历 → 公历。month 为负表示闰月。日期不存在时返回 null。
  static DateTime? toSolar(int lunarYear, int lunarMonth, int lunarDay) {
    try {
      final month = LunarMonth.fromYm(lunarYear, lunarMonth);
      if (month == null) return null;
      // 二十九 / 三十 在部分月份不存在，夹到当月最后一天
      final day = lunarDay > month.getDayCount()
          ? month.getDayCount()
          : lunarDay;
      final solar = Lunar.fromYmd(lunarYear, lunarMonth, day).getSolar();
      return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
    } catch (_) {
      return null;
    }
  }

  /// 公历 → 农历月/日。月为负表示闰月。
  ///
  /// 用户在公历模式下选了一个日期时，用这个给出农历字段的合理起点。
  static (int, int) fromSolar(DateTime solarDate) {
    try {
      final lunar = Lunar.fromDate(
        DateTime(solarDate.year, solarDate.month, solarDate.day),
      );
      return (lunar.getMonth(), lunar.getDay());
    } catch (_) {
      return (1, 1);
    }
  }

  /// 公历 → 农历，用于在界面上标注「= 农历八月十五」
  static String describe(DateTime solarDate) {
    try {
      final lunar = Lunar.fromDate(
        DateTime(solarDate.year, solarDate.month, solarDate.day),
      );
      return '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    } catch (_) {
      return '';
    }
  }

  /// 公历日期所属的农历年（春节前算上一年）
  static int lunarYearOf(DateTime solarDate) {
    try {
      return Lunar.fromDate(
        DateTime(solarDate.year, solarDate.month, solarDate.day),
      ).getYear();
    } catch (_) {
      return solarDate.year;
    }
  }

  /// 从 [from] 起，农历 month/day 的下一个公历日期。
  ///
  /// month 为负表示闰月；闰月不是每年都有，找不到就自然落到下一年。
  static DateTime nextOccurrence({
    required int lunarMonth,
    required int lunarDay,
    DateTime? from,
  }) {
    final base = from ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final startYear = lunarYearOf(today);

    for (var year = startYear; year <= startYear + 4; year++) {
      final solar = toSolar(year, lunarMonth, lunarDay);
      if (solar != null && !solar.isBefore(today)) return solar;
    }
    // 理论上不会走到这里（4 年内必有），兜底避免死循环
    return today.add(const Duration(days: 30));
  }

  /// 某农历年的月份列表，含闰月（闰月用负数）
  static List<int> monthsOf(int lunarYear) {
    try {
      final leap = LunarYear.fromYear(lunarYear).getLeapMonth();
      return <int>[
        for (var m = 1; m <= 12; m++) ...[
          m,
          if (leap > 0 && m == leap) -m,
        ],
      ];
    } catch (_) {
      return List<int>.generate(12, (i) => i + 1);
    }
  }

  /// 某农历月的天数（29 或 30），拿不到就按 30 算
  static int daysInMonth(int lunarYear, int lunarMonth) {
    try {
      return LunarMonth.fromYm(lunarYear, lunarMonth)?.getDayCount() ?? 30;
    } catch (_) {
      return 30;
    }
  }

  /// 初一到三十
  static String dayName(int day) {
    const names = <String>[
      '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
      '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十',
    ];
    if (day < 1 || day > 30) return '';
    return names[day - 1];
  }
}
