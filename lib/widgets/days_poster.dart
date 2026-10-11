import 'package:flutter/material.dart';

import '../theme/milestone_themes.dart';
import '../utils/formatters.dart';
import 'milestone_pattern.dart';

/// "还有 / 已经 N 天"那张海报。**纪念日和倒计时共用这一个组件** ——
/// 两边的核心都是"离那个日子还有多少天"，只是取数方向不同。
///
/// 版式抄的参考图 `E:\ribei\样图.jpg`，自上而下是四段：
///   ① 最顶上居中一行"店名"（参考图的 Days Matter，我们放「日贝 · 纪念 / 倒计时」）
///   ② 一张**日历纸**卡片：标题条上写着「**名字 + 还有/已经**」
///      （参考图名字就是那个小飞机），白纸上是一行超大天数，**天数下面是分析**，
///      最底下一条浅灰日期条
///   ③ 备注（有的话）—— 套一个圆角框，单摆一行字会显得很零碎
///
/// ⚠️ 配色一律走 [MilestoneThemeStyle] 的**固定配色**，不跟随 App 深浅色（红线 24）——
/// 分享出去的图必须"永远长这样"。
///
/// ⚠️ **不显示秒**（用户原话"页面数秒都来了"）。别在这里挂每秒重画的定时器。
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
  });

  /// 纪念日/倒计时的名字 —— 显示在**卡片标题条**上，不是卡片外面
  final String title;
  final int theme;

  /// 标题条上跟在名字后面的字：「还有」/「已经」/「已过」
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

  @override
  Widget build(BuildContext context) {
    final style = themeStyleOf(theme);

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
          // 内容层。外层（PosterScreen）给的是**紧约束**，所以这里 c.maxHeight 有界，
          // 可以拿它当"至少一屏高"：内容比一屏矮就垂直居中，比一屏高就退回可滚动。
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, c) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Padding(
                      // 上 92 给浮动的"返回/编辑"让位，下 96 给"分享"让位
                      padding: const EdgeInsets.fromLTRB(20, 92, 20, 96),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        // ★ 整块内容在视口里**垂直居中**。
                        // 生效的前提是上方约束里带 minHeight（这里由 ConstrainedBox 给），
                        // RenderFlex 会把 余量 对半分 —— 所以上面那层不能省。
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ① 店名：参考图里"Days Matter"那个位置
                          Text(
                            footer,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 5,
                              color: style.accent,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.32),
                                  offset: const Offset(0, 2),
                                  blurRadius: 5,
                                ),
                                if (!style.isDark)
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    offset: const Offset(0, -1),
                                    blurRadius: 2,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          // ② 日历纸
                          _CalendarPage(
                            style: style,
                            title: title,
                            header: headerLabel,
                            days: days,
                            breakdown: breakdown,
                            dateLabel: dateLabel,
                            date: date,
                          ),
                          // ③ 备注：给它一个框
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 18),
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

/// 参考图里那张"日历纸"：顶部彩色标题条（**名字 + 还有/已经**）+ 白纸 +
/// 一行超大天数 + 天数下面的分析 + 底部浅灰日期条。
class _CalendarPage extends StatelessWidget {
  const _CalendarPage({
    required this.style,
    required this.title,
    required this.header,
    required this.days,
    required this.breakdown,
    required this.dateLabel,
    required this.date,
  });

  final MilestoneThemeStyle style;
  final String title;
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          // 双层投影：近的一层收紧轮廓、远的一层铺开。
          // 单层投影在浅背景上会显脏，双层才有参考图那种"纸压在桌上"的手感。
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
      height: 48,
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
          // 名字 + 还有/已经。名字小一号、淡一点 —— 参考图里那个小飞机就是名字
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: style.headerInk.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    header,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: style.headerInk,
                    ),
                  ),
                ],
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$days',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 118,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -3,
                        color: MilestoneThemeStyle.paperInk,
                        shadows: <Shadow>[
                          Shadow(
                            color: Color(0x1A000000),
                            offset: Offset(0, 2),
                            blurRadius: 3,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xB31B1B1B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: const BoxDecoration(
                color: _strip,
                border: Border(
                  top: BorderSide(color: MilestoneThemeStyle.paperLine),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    // ⚠️ 安全兜底，别删：尺寸无穷时这里会永远转不完（真发生过一次，
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
