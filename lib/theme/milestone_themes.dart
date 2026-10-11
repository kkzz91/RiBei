import 'package:flutter/material.dart';

/// 背景图案的种类。
///
/// 图案是用代码画出来的（见 `widgets/milestone_pattern.dart`），不是图片：
/// 图片要进 `pubspec.yaml` 声明（漏了不报错、只在运行时加载不出来，见红线 10），
/// 而且分享图按 1080 宽放大时会糊。代码画则任何尺寸都清晰，也不占包体积。
enum MilestonePattern {
  /// 不用图案，只留渐变
  plain,

  /// 竖纹木板（抄的参考图那种原木墙）
  wood,

  /// 斜条纹 + 重复的爱心
  hearts,

  /// 夜空星点
  stars,

  /// 横向水波
  waves,

  /// 错开的圆点
  dots,

  /// 细格纸
  grid,

  /// 45° 斜条
  diagonal,

  /// 菱形暗纹
  diamonds,
}

/// 一套纪念日主题：底色 + 背景图案 + 日历纸卡片的配色。
///
/// 这些是**自带的固定配色**，不跟随 App 的浅色/深色模式 ——
/// 因为纪念日页面和分享出去的图都该"永远长这样"，不然分享图颜色会乱。
class MilestoneThemeStyle {
  const MilestoneThemeStyle({
    required this.label,
    required this.pattern,
    required this.gradient,
    required this.accent,
    required this.accentSoft,
    required this.text,
    required this.textSoft,
    required this.divider,
    required this.isDark,
    required this.headerBar,
    required this.headerInk,
    required this.patternInk,
    required this.patternInkSoft,
  });

  final String label;

  /// 背景图案
  final MilestonePattern pattern;

  /// 背景渐变（自上而下），图案画在它上面
  final List<Color> gradient;

  /// 主强调色：标题、按钮、列表里的天数
  final Color accent;

  /// accent 的低透明度版
  final Color accentSoft;

  final Color text;
  final Color textSoft;
  final Color divider;

  /// 背景是深色、文字是浅色
  final bool isDark;

  /// 日历纸卡片顶部那条标题条的底色 / 字色
  final Color headerBar;
  final Color headerInk;

  /// 图案的两支画笔（都已经带好透明度）
  final Color patternInk;
  final Color patternInkSoft;

  /// ⚠️ 日历纸本身在**所有主题下都是同一张纸**，只换顶部标题条的颜色。
  ///
  /// 这样"这是一张日历纸"的观感在 8 套主题下都一致，也免得每套主题
  /// 各调一遍纸的颜色（调不好就会出现一张脏纸）。纸上的字一律用近黑和灰，
  /// 所以不管背景是深是浅都读得清。
  static const Color paper = Color(0xFFFBFAF7);
  static const Color paperInk = Color(0xFF1B1B1B);
  static const Color paperSoft = Color(0xFF8E8E8E);
  static const Color paperLine = Color(0x0D000000);
}

/// ⚠️ **这个列表的下标就是存进数据库的 `theme` 值**（见 `MilestoneTheme`）。
/// 只许往后加，不许插入或调整顺序 —— 否则老数据会集体换主题（红线 9 的同族规矩）。
const List<MilestoneThemeStyle> milestoneThemeStyles = <MilestoneThemeStyle>[
  // 0 黑金
  MilestoneThemeStyle(
    label: '黑金',
    pattern: MilestonePattern.diamonds,
    gradient: <Color>[Color(0xFF1C1915), Color(0xFF050403)],
    accent: Color(0xFFD4B375),
    accentSoft: Color(0x22D4B375),
    text: Color(0xFFF8F8F8),
    textSoft: Color(0xFFA89E8B),
    divider: Color(0xFF2C2822),
    isDark: true,
    headerBar: Color(0xFF8A6E3C),
    headerInk: Color(0xFFFDF6E7),
    patternInk: Color(0x24D4B375),
    patternInkSoft: Color(0x12D4B375),
  ),
  // 1 玉青
  MilestoneThemeStyle(
    label: '玉青',
    pattern: MilestonePattern.waves,
    gradient: <Color>[Color(0xFF1F5E52), Color(0xFF0E332C)],
    accent: Color(0xFFE9D8A6),
    accentSoft: Color(0x22E9D8A6),
    text: Color(0xFFF6F2EA),
    textSoft: Color(0xFFB9CDC5),
    divider: Color(0xFF2A4A43),
    isDark: true,
    headerBar: Color(0xFF2E8C78),
    headerInk: Color(0xFFF3FFFB),
    patternInk: Color(0x28E9D8A6),
    patternInkSoft: Color(0x16E9D8A6),
  ),
  // 2 深空蓝
  MilestoneThemeStyle(
    label: '深空蓝',
    pattern: MilestonePattern.stars,
    gradient: <Color>[Color(0xFF0B1B33), Color(0xFF081426)],
    accent: Color(0xFF7FB4E8),
    accentSoft: Color(0x227FB4E8),
    text: Color(0xFFEDF3FA),
    textSoft: Color(0xFF9FB4CC),
    divider: Color(0xFF22334C),
    isDark: true,
    headerBar: Color(0xFF28527F),
    headerInk: Color(0xFFECF5FF),
    patternInk: Color(0xCCFFFFFF),
    patternInkSoft: Color(0x77A8CBF0),
  ),
  // 3 暖橙日暮
  MilestoneThemeStyle(
    label: '暖橙日暮',
    pattern: MilestonePattern.dots,
    gradient: <Color>[Color(0xFF3A1C14), Color(0xFF1C0E0A)],
    accent: Color(0xFFF0B46A),
    accentSoft: Color(0x22F0B46A),
    text: Color(0xFFFFF3E7),
    textSoft: Color(0xFFD9A98C),
    divider: Color(0xFF4A2E24),
    isDark: true,
    headerBar: Color(0xFFB4632E),
    headerInk: Color(0xFFFFF3E7),
    patternInk: Color(0x30F0B46A),
    patternInkSoft: Color(0x1CF0B46A),
  ),
  // 4 极简白
  MilestoneThemeStyle(
    label: '极简白',
    pattern: MilestonePattern.grid,
    gradient: <Color>[Color(0xFFFFFFFF), Color(0xFFF3EEE7)],
    accent: Color(0xFF1F5E52),
    accentSoft: Color(0x141F5E52),
    text: Color(0xFF1C1B19),
    textSoft: Color(0xFF6B6760),
    divider: Color(0xFFE7E0D6),
    isDark: false,
    headerBar: Color(0xFF1F5E52),
    headerInk: Color(0xFFFFFFFF),
    patternInk: Color(0x1A1F5E52),
    patternInkSoft: Color(0x121F5E52),
  ),
  // 5 粉雾爱心（新增）
  MilestoneThemeStyle(
    label: '粉雾爱心',
    pattern: MilestonePattern.hearts,
    gradient: <Color>[Color(0xFFFFF0F6), Color(0xFFFFD2E3)],
    accent: Color(0xFFD33D7C),
    accentSoft: Color(0x22D33D7C),
    text: Color(0xFF67223E),
    textSoft: Color(0xFFA9728C),
    divider: Color(0xFFF7D3E1),
    isDark: false,
    headerBar: Color(0xFFEE5B94),
    headerInk: Color(0xFFFFFFFF),
    patternInk: Color(0x8AFFFFFF),
    patternInkSoft: Color(0x4CFFFFFF),
  ),
  // 6 原木（新增，抄参考图那面木墙）
  MilestoneThemeStyle(
    label: '原木',
    pattern: MilestonePattern.wood,
    gradient: <Color>[Color(0xFFE9CE97), Color(0xFFD6AC6C)],
    accent: Color(0xFF6E4711),
    accentSoft: Color(0x226E4711),
    text: Color(0xFF4A3210),
    textSoft: Color(0xFF8A6A38),
    divider: Color(0x337A4E12),
    isDark: false,
    headerBar: Color(0xFF2F6EAB),
    headerInk: Color(0xFFFFFFFF),
    patternInk: Color(0x446B4A16),
    patternInkSoft: Color(0x28FFF6DE),
  ),
  // 7 薄荷（新增）
  MilestoneThemeStyle(
    label: '薄荷',
    pattern: MilestonePattern.diagonal,
    gradient: <Color>[Color(0xFFEAF9F3), Color(0xFFBEE9DA)],
    accent: Color(0xFF12705A),
    accentSoft: Color(0x1412705A),
    text: Color(0xFF14453A),
    textSoft: Color(0xFF5E8C7E),
    divider: Color(0xFFCDE8DE),
    isDark: false,
    headerBar: Color(0xFF2AA98A),
    headerInk: Color(0xFFFFFFFF),
    patternInk: Color(0x44FFFFFF),
    patternInkSoft: Color(0x280E6B55),
  ),
];

/// 按主题编号取样式；编号越界时兜到黑金（不能崩）
MilestoneThemeStyle themeStyleOf(int theme) {
  if (theme >= 0 && theme < milestoneThemeStyles.length) {
    return milestoneThemeStyles[theme];
  }
  return milestoneThemeStyles.first;
}
