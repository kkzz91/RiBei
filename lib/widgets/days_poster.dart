import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/milestone_themes.dart';
import '../utils/formatters.dart';
import 'milestone_pattern.dart';

/// "还有 / 已经 N 天"那张海报。**纪念日和倒计时共用这一个组件**。
///
/// 版式抄的参考图 `E:\ribei\样图.jpg`，自上而下是：
///   ① 最顶上居中一行小字"店名"（参考图的 Days Matter）
///   ② 一条极细的装饰线（菱形 + 两道短线）—— 仪式感靠这些细节堆
///   ③ **名字当主角**：大字、宽字距、金色浮雕
///   ④ 一张**日历纸**：标题条只写「还有 / 已经」，白纸上一行**超大天数**，
///      下面接分析行，最底一条浅灰日期条
///   ⑤ [actions]：详情页那排缩小药丸按钮（分享 / 背景 / 编辑）。
///      **分享截图时会传 null**，所以分享出去的图里没有按钮。
///   ⑥ 备注（有的话）套一个圆角框 —— 单摆一行字飘在背景上会显得很零碎
///
/// ⚠️ 配色一律走 [MilestoneThemeStyle] 的**固定配色**，不跟随 App 深浅色（红线 24）。
///
/// ⚠️ **不显示秒**（用户原话"页面数秒都来了"）。别在这里挂每秒重画的定时器。
///
/// ⚠️ 外层必须给**有界约束**（`Stack` 的要求），否则 release 下会整个 App 卡死 ——
/// 详见红线 28 ④ 和 `poster_screen.dart`。
class DaysPoster extends StatelessWidget {
  const DaysPoster({
    super.key,
    required this.title,
    required this.theme,
    required this.headerLabel,
    required this.days,
    required this.breakdown,
    required this.dateLabel,
    required this.date,
    required this.footer,
    this.note = '',
    this.actions,
  });

  /// 纪念日/倒计时的名字 —— 海报上的**主角**，大字显示
  final String title;
  final int theme;

  /// 卡片标题条上的字：「还有」/「已经」/「已过」
  final String headerLabel;

  /// 大字那个数（传进来必须是非负数，方向由调用方决定）
  final int days;

  /// 数字下面的"分析"行，比如 `4 个月 4 天`
  final String breakdown;

  /// `目标日` / `起始日`
  final String dateLabel;
  final DateTime date;

  /// 最顶上那行"店名"，比如 `日贝 · 倒计时`
  final String footer;

  final String note;

  /// 卡片下面那排按钮（详情页传进来；分享截图时传 null）
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final style = themeStyleOf(theme);
    // "店名"要贴着手机最顶上，所以只让开状态栏这一点点
    final topInset = MediaQuery.paddingOf(context).top;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.gradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: MilestonePatternPainter(style)),
          ),
          // 上下压一层暗角：四周暗下去，中间的卡片才"浮"出来
          Positioned.fill(child: _Vignette(isDark: style.isDark)),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, c) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        // 内容整体偏上（用户反馈"偏下"）—— 上半屏是海报的黄金位置，
                        // 下半屏留白，和参考图一个观感。
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ① 店名：参考图里"Days Matter"那个位置
                          Text(
                            footer,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 6,
                              color: style.accent.withValues(alpha: 0.9),
                              shadows: <Shadow>[
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  offset: const Offset(0, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ② 装饰线：仪式感
                          _Ornament(color: style.accent),
                          const SizedBox(height: 20),
                          // ③ 名字当主角
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              height: 1.18,
                              color: style.accent,
                              // "浮雕金字"：一道下投影 + 一道上高光做出来。
                              // 引字体要进 assets 声明（红线 10），所以不引。
                              shadows: <Shadow>[
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.38),
                                  offset: const Offset(0, 3),
                                  blurRadius: 7,
                                ),
                                if (!style.isDark)
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    offset: const Offset(0, -1),
                                    blurRadius: 2,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          // ④ 日历纸
                          _CalendarPage(
                            style: style,
                            header: headerLabel,
                            days: days,
                            breakdown: breakdown,
                            dateLabel: dateLabel,
                            date: date,
                          ),
                          // ⑤ 按钮：紧贴卡片下沿（参考图就是这样）
                          if (actions != null) ...[
                            const SizedBox(height: 14),
                            actions!,
                          ],
                          // ⑥ 备注
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _NotePill(text: note, style: style),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 一条极细的装饰线（两道短线夹一个菱形）。就为了那点"仪式感"。
class _Ornament extends StatelessWidget {
  const _Ornament({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final line = color.withValues(alpha: 0.55);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 34, height: 1.2, color: line),
        const SizedBox(width: 9),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 6, height: 6, color: line),
        ),
        const SizedBox(width: 9),
        Container(width: 34, height: 1.2, color: line),
      ],
    );
  }
}

/// 整屏四周那层暗角。
class _Vignette extends StatelessWidget {
  const _Vignette({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final edge = Colors.black.withValues(alpha: isDark ? 0.34 : 0.12);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[edge, Colors.transparent, Colors.transparent, edge],
          stops: const <double>[0, 0.20, 0.74, 1],
        ),
      ),
    );
  }
}

/// 备注。**单摆一行字飘在海报上会显得很零碎**（用户反馈），所以套个圆角框。
class _NotePill extends StatelessWidget {
  const _NotePill({required this.text, required this.style});

  final String text;
  final MilestoneThemeStyle style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: (style.isDark ? Colors.white : Colors.black).withValues(
            alpha: style.isDark ? 0.10 : 0.05,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: style.text.withValues(alpha: 0.16)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: style.textSoft,
          ),
        ),
      ),
    );
  }
}

/// 参考图里那张"日历纸"：顶部彩色标题条 + 白纸 + 一行超大天数 +
/// 数字下面的分析行 + 底部浅灰日期条。
class _CalendarPage extends StatelessWidget {
  const _CalendarPage({
    required this.style,
    required this.header,
    required this.days,
    required this.breakdown,
    required this.dateLabel,
    required this.date,
  });

  final MilestoneThemeStyle style;
  final String header;
  final int days;
  final String breakdown;
  final String dateLabel;
  final DateTime date;

  /// 底部日期条的底色（比纸略深一档）
  static const Color _strip = Color(0xFFF1EFEA);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          // 双层投影：近的一层收紧轮廓、远的一层铺开。
          // 单层投影在浅背景上会显脏，双层才有参考图那种"纸压在桌上"的手感。
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // ⚠️ 必须 stretch：默认是 center，那样标题条只会包住字、
          // 不撑满卡片宽度，整张卡片就变成"内容多大就多大"。
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_buildHeader(), _buildPaper()],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 46,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: style.headerBar)),
          // 上亮下暗一层薄渐变，标题条才不像一块纯色塑料板
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.07),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              header,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                // 字距会在最后一个字后面也垫一份，往左补偿一下才视觉居中
                height: 1,
                color: style.headerInk,
              ),
            ),
          ),
          // 参考图标题条底边那条"缝线"
          const Positioned(
            left: 0,
            right: 0,
            bottom: 5,
            child: SizedBox(
              height: 2,
              child: CustomPaint(painter: _StitchPainter()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaper() {
    return ColoredBox(
      color: MilestoneThemeStyle.paper,
      child: CustomPaint(
        painter: const _PaperTexturePainter(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 26, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 超大天数：这是整张海报的视觉中心，宁可大一点
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$days',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 150,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -5,
                        color: MilestoneThemeStyle.paperInk,
                        shadows: <Shadow>[
                          Shadow(
                            color: Color(0x1F000000),
                            offset: Offset(0, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 「分析」放在数字下面 —— 用户明确要求的
                  Text(
                    breakdown,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: Color(0xB81B1B1B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: const BoxDecoration(
                color: _strip,
                border: Border(
                  top: BorderSide(color: MilestoneThemeStyle.paperLine),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Text(
                '$dateLabel：${isoDateWithWeekday(date)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: MilestoneThemeStyle.paperSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标题条底边那条白色虚线（参考图里的"缝线"）。
class _StitchPainter extends CustomPainter {
  const _StitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.width.isFinite) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    final y = size.height / 2;
    for (var x = 10.0; x + dash < size.width - 10; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
    }
  }

  @override
  bool shouldRepaint(_StitchPainter oldDelegate) => false;
}

/// 纸面：极淡的方格 + 标题条在纸上投下的一道内阴影。
///
/// 内阴影是关键 —— 没有它，彩色标题条和白纸是"贴"在一起的，
/// 看着像两块色块拼接；有了它才像一条压住纸的日历头。
class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter();

  static const double _step = 24;

  @override
  void paint(Canvas canvas, Size size) {
    // ⚠️ 安全兜底，别删：尺寸无穷时这里的循环会永远转不完（真发生过，
    // 见红线 28 ④ —— 海报被套进 SingleChildScrollView，Stack 尺寸变无限）。
    if (!size.width.isFinite || !size.height.isFinite) return;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = MilestoneThemeStyle.paperLine;
    for (var x = _step; x < size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = _step; y < size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final shadowBand = Rect.fromLTWH(0, 0, size.width, 16);
    canvas.drawRect(
      shadowBand,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.11),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(shadowBand),
    );
  }

  @override
  bool shouldRepaint(_PaperTexturePainter oldDelegate) => false;
}
