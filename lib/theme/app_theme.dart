import 'package:flutter/material.dart';

/// 「日贝」的一整套配色。
///
/// 做成 [ThemeExtension] 是为了支持深色模式：颜色必须能随主题动态解析，
/// 早期版本用 `static const` 写死，控件不会跟着主题变。
///
/// 深色不是把浅色反转：底色取暖调近黑（延续"纸质"质感），
/// 强调色整体提亮一档，否则在深底上会发闷、对比度不足。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.outline,
    required this.jade,
    required this.jadeDeep,
    required this.jadeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.income,
    required this.incomeSoft,
    required this.deficit,
    required this.deficitDeep,
    required this.warn,
    required this.danger,
  });

  final Brightness brightness;

  // 中性色
  final Color paper;
  final Color card;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color outline;

  // 主色
  final Color jade;
  final Color jadeDeep;
  final Color jadeSoft;

  // 收支
  final Color expense;
  final Color expenseSoft;
  final Color income;
  final Color incomeSoft;

  // 入不敷出
  final Color deficit;
  final Color deficitDeep;

  // 状态
  final Color warn;
  final Color danger;

  bool get isDark => brightness == Brightness.dark;

  /// 倒计时按「还剩几天」取色，越近越醒目。
  Color urgencyOf(int daysLeft) {
    if (daysLeft < 0) return inkFaint;
    if (daysLeft <= 3) return danger;
    if (daysLeft <= 7) return warn;
    return jade;
  }

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? paper,
    Color? card,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? line,
    Color? outline,
    Color? jade,
    Color? jadeDeep,
    Color? jadeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? income,
    Color? incomeSoft,
    Color? deficit,
    Color? deficitDeep,
    Color? warn,
    Color? danger,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      paper: paper ?? this.paper,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      outline: outline ?? this.outline,
      jade: jade ?? this.jade,
      jadeDeep: jadeDeep ?? this.jadeDeep,
      jadeSoft: jadeSoft ?? this.jadeSoft,
      expense: expense ?? this.expense,
      expenseSoft: expenseSoft ?? this.expenseSoft,
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      deficit: deficit ?? this.deficit,
      deficitDeep: deficitDeep ?? this.deficitDeep,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? b;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      paper: mix(paper, other.paper),
      card: mix(card, other.card),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      inkFaint: mix(inkFaint, other.inkFaint),
      line: mix(line, other.line),
      outline: mix(outline, other.outline),
      jade: mix(jade, other.jade),
      jadeDeep: mix(jadeDeep, other.jadeDeep),
      jadeSoft: mix(jadeSoft, other.jadeSoft),
      expense: mix(expense, other.expense),
      expenseSoft: mix(expenseSoft, other.expenseSoft),
      income: mix(income, other.income),
      incomeSoft: mix(incomeSoft, other.incomeSoft),
      deficit: mix(deficit, other.deficit),
      deficitDeep: mix(deficitDeep, other.deficitDeep),
      warn: mix(warn, other.warn),
      danger: mix(danger, other.danger),
    );
  }
}

/// 浅色：暖纸底 + 玉青主色
const AppPalette lightPalette = AppPalette(
  brightness: Brightness.light,
  paper: Color(0xFFFAF8F5),
  card: Color(0xFFFFFFFF),
  ink: Color(0xFF1C1B19),
  inkSoft: Color(0xFF6B6760),
  inkFaint: Color(0xFFA29B92),
  line: Color(0xFFEDE8E1),
  outline: Color(0xFFCFC8BF),
  // 品牌玉青。v1.6.9 曾试过改成蓝色（顶栏配蓝），用户实测后觉得"不清新"，
  // v1.6.13 起**改回青色**：顶栏 / 按钮 / 选中的 Tab / 结余卡 / 图表
  // 全部走这一套，保持一致（顶栏用其中更深的 jadeDeep）。
  jade: Color(0xFF1F5E52),
  jadeDeep: Color(0xFF123F37),
  jadeSoft: Color(0xFFE2EDE9),
  expense: Color(0xFFC4553D),
  expenseSoft: Color(0xFFF8E7E2),
  income: Color(0xFF2E7D6B),
  incomeSoft: Color(0xFFE1EFEB),
  deficit: Color(0xFF9E4232),
  deficitDeep: Color(0xFF6B2A1F),
  warn: Color(0xFFD98E3F),
  danger: Color(0xFFC4553D),
);

/// 深色：暖调近黑底 + 提亮后的玉青
const AppPalette darkPalette = AppPalette(
  brightness: Brightness.dark,
  paper: Color(0xFF14110F),
  card: Color(0xFF1E1B18),
  ink: Color(0xFFF3EFE9),
  inkSoft: Color(0xFFA9A29A),
  inkFaint: Color(0xFF6F6862),
  line: Color(0xFF2C2724),
  outline: Color(0xFF3E3833),
  // 深色下玉青提亮一档，否则压在近黑底上发闷
  jade: Color(0xFF52A692),
  jadeDeep: Color(0xFF2E7565),
  jadeSoft: Color(0xFF1A2E29),
  expense: Color(0xFFE2846C),
  expenseSoft: Color(0xFF33221D),
  income: Color(0xFF62C4A6),
  incomeSoft: Color(0xFF172B24),
  deficit: Color(0xFFC4604A),
  deficitDeep: Color(0xFF7C3325),
  warn: Color(0xFFE3A862),
  danger: Color(0xFFE2846C),
);

/// 便捷取色：`context.palette.ink`
extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? lightPalette;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(lightPalette);

  static ThemeData dark() => _build(darkPalette);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.jade,
      brightness: p.brightness,
    ).copyWith(
      primary: p.jade,
      onPrimary: p.isDark ? const Color(0xFF0B1F1A) : Colors.white,
      primaryContainer: p.jadeSoft,
      onPrimaryContainer: p.isDark ? const Color(0xFFBFE8DC) : p.jadeDeep,
      surface: p.card,
      onSurface: p.ink,
      onSurfaceVariant: p.inkSoft,
      outlineVariant: p.line,
      error: p.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.paper,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[p],
      // 显式指定页面过渡。
      // Flutter 现在 Android 的默认是 PredictiveBackPageTransitionsBuilder（预测式返回）：
      // 返回手势进行到一半时页面会跟着手指走，观感像"拖动整页"。
      // 换成 M3 的横向滑入淡入，进退都是干净的一步到位。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      // 顶栏做成**独立的一条彩色条**（用户要求：像微信聊天页顶上那块名字栏 ——
      // 每个页面都要有、而且要和页面内容明确分开）。
      // 颜色 = 品牌玉青的深色档（`p.jadeDeep`，浅深色两种模式各自取各自的档，
      // 不用硬编码 —— 硬编码过一次蓝色，用户觉得不如青色清新，v1.6.13 改回）；
      // 底下压一条 1px 暗线做"分界"，**不用阴影** —— 阴影会让它显得是"浮在屏幕上的一层"（用户明确不喜欢）。
      appBarTheme: AppBarTheme(
        backgroundColor: p.jadeDeep,
        // 用户："顶栏有点宽过头，窄一点" —— 56（M3 默认）→ 48。
        // 注意：别低于 44，不然顶栏上那些 48dp 的 IconButton 会顶到边。
        toolbarHeight: 48,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        shape: const Border(
          bottom: BorderSide(color: Color(0x33000000), width: 1),
        ),
      ),
      // 顶栏上那些按钮：给一层**半透明圆底**，看起来才像个"按键"（用户要求）。
      // ⚠️ 只设底色，**不动前景色** —— 前景由 appBarTheme 给白色；
      // 如果这里也把前景设成白，正文里那些 IconButton 就全废了。
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.jade,
        foregroundColor: p.isDark ? const Color(0xFF0B1F1A) : Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.jade,
          foregroundColor: p.isDark ? const Color(0xFF0B1F1A) : Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.jade,
          side: BorderSide(color: p.line),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: p.inkFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.jade, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: p.jadeSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.jade : p.inkFaint,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? p.jade : p.inkFaint,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? const Color(0xFF35302B) : p.ink,
        contentTextStyle: TextStyle(
          color: p.isDark ? p.ink : Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// 常用文本样式。需要跟随主题，所以是接收 context 的函数而非常量。
class AppText {
  const AppText._();

  static TextStyle amountHero(BuildContext c) => TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.1,
    color: c.palette.ink,
  );

  static TextStyle amountLarge(BuildContext c) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: c.palette.ink,
  );

  static TextStyle amount(BuildContext c) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: c.palette.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle sectionTitle(BuildContext c) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: c.palette.ink,
    letterSpacing: 0.2,
  );

  static TextStyle label(BuildContext c) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: c.palette.inkSoft,
  );

  static TextStyle dayHero(BuildContext c) => TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1.0,
    color: c.palette.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
