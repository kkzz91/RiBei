import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00', 'zh_CN');
final _moneyCompact = NumberFormat('#,##0.##', 'zh_CN');

/// ¥1,234.56
String formatMoney(double value) => '¥${_money.format(value)}';

/// 无小数位（用于图表轴、概览）
String formatMoneyCompact(double value) => '¥${_moneyCompact.format(value)}';

/// 2026年1月10日
String formatFullDate(DateTime d) => DateFormat('yyyy年M月d日', 'zh_CN').format(d);

/// 1月10日
String formatShortDate(DateTime d) => DateFormat('M月d日', 'zh_CN').format(d);

/// 2026年1月
String formatMonth(DateTime d) => DateFormat('yyyy年M月', 'zh_CN').format(d);

/// 周一 / 周一 1月10日
String weekdayLabel(DateTime d) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][d.weekday - 1];

String dateWithWeekday(DateTime d) => '${weekdayLabel(d)} · ${formatShortDate(d)}';

/// 记账列表的分组标题：今天 / 昨天 / 1月8日 周四
String groupHeader(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  return '${formatShortDate(d)} ${weekdayLabel(d)}';
}

/// 倒计时的相对描述
String countdownLabel(int daysLeft) {
  if (daysLeft > 0) return '还有 $daysLeft 天';
  if (daysLeft == 0) return '就是今天';
  return '已过 ${-daysLeft} 天';
}

/// 09:00
String formatClock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 待办的到期时间：今天 20:00 / 明天 09:00 / 3月5日 14:30
String formatDueAt(DateTime due) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(due.year, due.month, due.day);
  final diff = target.difference(today).inDays;
  final clock = formatClock(due.hour, due.minute);

  if (diff == 0) return '今天 $clock';
  if (diff == 1) return '明天 $clock';
  if (diff == -1) return '昨天 $clock';
  if (diff < -1) return '逾期 ${formatShortDate(due)} $clock';
  return '${formatShortDate(due)} $clock';
}

/// 日期区间：重复的部分省略不写
///
/// 同一天 → `2026年9月3日`
/// 同月   → `2026年9月3日 – 28日`
/// 同年   → `2026年9月3日 – 10月8日`
/// 跨年   → `2025年12月3日 – 2026年1月8日`
String formatDateRange(DateTime from, DateTime to) {
  if (from.year == to.year && from.month == to.month && from.day == to.day) {
    return formatFullDate(from);
  }
  if (from.year == to.year && from.month == to.month) {
    return '${from.year}年${from.month}月${from.day}日 – ${to.day}日';
  }
  if (from.year == to.year) {
    return '${from.year}年${from.month}月${from.day}日 – ${to.month}月${to.day}日';
  }
  return '${formatFullDate(from)} – ${formatFullDate(to)}';
}

/// 清洗"系统键盘输金额"时的输入：只留数字和一个小数点，
/// 最多两位小数、整数最多 9 位、空串归为 '0'。
///
/// 纯函数，方便单测 —— 这是记账金额的入口，规则不对会记错钱。
String sanitizeAmountInput(String raw) {
  var s = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  final dot = s.indexOf('.');
  if (dot >= 0) {
    s = s.substring(0, dot + 1) + s.substring(dot + 1).replaceAll('.', '');
  }
  final parts = s.split('.');
  var head = parts[0];
  if (head.length > 9) head = head.substring(0, 9);
  if (parts.length > 1) {
    var tail = parts[1];
    if (tail.length > 2) tail = tail.substring(0, 2);
    s = '$head.$tail';
  } else {
    s = head;
  }
  return s.isEmpty ? '0' : s;
}


