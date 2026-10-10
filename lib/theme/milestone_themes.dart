import 'package:flutter/material.dart';

/// 一套纪念日主题的配色。
///
/// 这些是**自带的固定配色**，不跟随 App 的浅色/深色模式 ——
/// 因为纪念日页面和分享出去的图都应该"永远长这样"，不然分享图颜色会乱。
class MilestoneThemeStyle {
  const MilestoneThemeStyle({
    required this.label,
    required this.gradient,
    required this.accent,
    required this.accentSoft,
    required this.text,
    required this.textSoft,
    required this.divider,
    required this.isDark,
  });

  final String label;

  /// 背景渐变（自上而下）
  final List<Color> gradient;

  /// 主强调色：大数字、圆环、小标签
  final Color accent;

  /// accent 的低透明度版，做柔光/蒙层
  final Color accentSoft;

  final Color text;
  final Color textSoft;
  final Color divider;

  /// 背景是深色、文字是浅色
  final bool isDark;
}

const List<MilestoneThemeStyle> milestoneThemeStyles =
    <MilestoneThemeStyle>[
  // 0 黑金 —— 参考图那种"氛围感"
  MilestoneThemeStyle(
    label: '黑金',
    gradient: <Color>[Color(0xFF1C1915), Color(0xFF050403)],
    accent: Color(0xFFD4B375),
    accentSoft: Color(0x22D4B375),
    text: Color(0xFFF8F8F8),
    textSoft: Color(0xFFA89E8B),
    divider: Color(0xFF2C2822),
    isDark: true,
  ),
  // 1 玉青 —— 延续 App 主色
  MilestoneThemeStyle(
    label: '玉青',
    gradient: <Color>[Color(0xFF1F5E52), Color(0xFF0E332C)],
    accent: Color(0xFFE9D8A6),
    accentSoft: Color(0x22E9D8A6),
    text: Color(0xFFF6F2EA),
    textSoft: Color(0xFFB9CDC5),
    divider: Color(0xFF2A4A43),
    isDark: true,
  ),
  // 2 深空蓝
  MilestoneThemeStyle(
    label: '深空蓝',
    gradient: <Color>[Color(0xFF0B1B33), Color(0xFF081426)],
    accent: Color(0xFF7FB4E8),
    accentSoft: Color(0x227FB4E8),
    text: Color(0xFFEDF3FA),
    textSoft: Color(0xFF9FB4CC),
    divider: Color(0xFF22334C),
    isDark: true,
  ),
  // 3 暖橙日暮
  MilestoneThemeStyle(
    label: '暖橙日暮',
    gradient: <Color>[Color(0xFF3A1C14), Color(0xFF1C0E0A)],
    accent: Color(0xFFF0B46A),
    accentSoft: Color(0x22F0B46A),
    text: Color(0xFFFFF3E7),
    textSoft: Color(0xFFD9A98C),
    divider: Color(0xFF4A2E24),
    isDark: true,
  ),
  // 4 极简白
  MilestoneThemeStyle(
    label: '极简白',
    gradient: <Color>[Color(0xFFFFFFFF), Color(0xFFF3EEE7)],
    accent: Color(0xFF1F5E52),
    accentSoft: Color(0x141F5E52),
    text: Color(0xFF1C1B19),
    textSoft: Color(0xFF6B6760),
    divider: Color(0xFFE7E0D6),
    isDark: false,
  ),
];

/// 按主题编号取样式；编号越界时兜到黑金（不能崩）
MilestoneThemeStyle themeStyleOf(int theme) {
  if (theme >= 0 && theme < milestoneThemeStyles.length) {
    return milestoneThemeStyles[theme];
  }
  return milestoneThemeStyles.first;
}
