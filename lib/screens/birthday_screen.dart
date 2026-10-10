import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/countdown_event.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/pressable.dart';

/// 生日当天的「小惊喜」。
///
/// 触发条件见 [CountdownEvent.isBirthdayToday]（名称或备注里提到"生日"，且就是今天）。
/// 一天只弹一次，记录写在 [SettingsProvider.birthdayCelebrated] 里。
///
/// 蛋糕、蜡烛火苗、彩纸**全部是代码画的**（CustomPainter），没有图片素材：
/// 风格能和 App 一致，也不会让包变大。
class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({super.key, required this.event});

  final CountdownEvent event;

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen>
    with TickerProviderStateMixin {
  /// 彩纸飘落
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  /// 烛火摇曳
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  /// 固定种子：每次打开彩纸的位置一样，不会"随机到难看的那一次"
  final List<_Confetto> _pieces = _buildPieces();

  static List<_Confetto> _buildPieces() {
    final rnd = math.Random(20260916);
    const colors = <Color>[
      Color(0xFFE8833A),
      Color(0xFFD45D8C),
      Color(0xFF4F6BD8),
      Color(0xFF2E9E6B),
      Color(0xFFC9A227),
      Color(0xFF8A5CD1),
    ];
    return List<_Confetto>.generate(46, (i) {
      return _Confetto(
        x: rnd.nextDouble(),
        delay: rnd.nextDouble() * 0.6,
        speed: 0.7 + rnd.nextDouble() * 0.6,
        size: 5 + rnd.nextDouble() * 6,
        spin: (rnd.nextDouble() - 0.5) * 8,
        sway: 0.03 + rnd.nextDouble() * 0.06,
        color: colors[i % colors.length],
        round: rnd.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _flicker.dispose();
    super.dispose();
  }

  void _close() {
    Haptics.impact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // 生日这一屏刻意换一套暖色，和平时青玉色的界面区分开，才有"今天不一样"的感觉
    const top = Color(0xFF2B6B5C);
    const mid = Color(0xFF7A4E6B);
    const bottom = Color(0xFFB5654A);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, mid, bottom],
          ),
        ),
        child: Stack(
          children: [
            // 飘落的彩纸铺在最底层
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _ConfettiPainter(_pieces, _confetti.value),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            '生日快乐',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '今天 · ${widget.event.title}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          // 蛋糕：入场时从小弹到大
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutBack,
                            builder: (context, t, child) => Transform.scale(
                              scale: 0.6 + 0.4 * t,
                              child: Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: child,
                              ),
                            ),
                            child: AnimatedBuilder(
                              animation: _flicker,
                              builder: (context, _) => CustomPaint(
                                size: const Size(240, 214),
                                painter: _CakePainter(_flicker.value),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Column(
                              children: [
                                if (widget.event.note.trim().isNotEmpty) ...[
                                  Text(
                                    widget.event.note.trim(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.7,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  '愿你想要的都拥有，得不到的都释怀。\n'
                                  '新的一岁，平安喜乐。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.9,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${formatFullDate(DateTime.now())} · 日贝',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                    child: Column(
                      children: [
                        Pressable(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: Colors.white,
                              foregroundColor: p.jadeDeep,
                            ),
                            onPressed: _close,
                            child: const Text('收下祝福'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '这一天只弹一次，明年今天还会来',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 彩纸

class _Confetto {
  const _Confetto({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.spin,
    required this.sway,
    required this.color,
    required this.round,
  });

  /// 横向起始位置 0..1
  final double x;
  final double delay;
  final double speed;
  final double size;
  final double spin;
  final double sway;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);

  final List<_Confetto> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      // 每片有自己的出发延迟；走完一轮就重来
      var local = (t - piece.delay) * piece.speed;
      if (local <= 0) continue;
      local = local % 1.0;

      final dy = -30 + local * (size.height + 60);
      final dx =
          piece.x * size.width +
          math.sin(local * math.pi * 3 + piece.x * 10) * piece.sway * size.width;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(local * piece.spin * math.pi);
      final paint = Paint()
        ..color = piece.color.withValues(alpha: 0.85)
        ..isAntiAlias = true;
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size,
              height: piece.size * 0.6,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ---------------------------------------------------------------- 蛋糕

class _CakePainter extends CustomPainter {
  const _CakePainter(this.flicker);

  /// 0..1，来回振荡，用来让火苗大小抖动
  final double flicker;

  static const _plateColor = Color(0xFFEFE7DC);
  static const _sponge = Color(0xFFE9B872);
  static const _spongeDark = Color(0xFFD9A45C);
  static const _cream = Color(0xFFFFF6E9);
  static const _candleA = Color(0xFFE8833A);
  static const _candleB = Color(0xFF4F6BD8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;

    // ---------- 盘子 ----------
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 16),
        width: w * 0.88,
        height: 26,
      ),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.16),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 22),
        width: w * 0.86,
        height: 30,
      ),
      Paint()..color = _plateColor,
    );

    // ---------- 下层蛋糕 ----------
    final bottomTop = size.height - 66;
    final bottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 74, bottomTop, 148, 46),
      const Radius.circular(10),
    );
    canvas.drawRRect(bottomRect, Paint()..color = _sponge);

    // ---------- 上层蛋糕 ----------
    final topTop = size.height - 116;
    final topRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 50, topTop, 100, 50),
      const Radius.circular(9),
    );
    canvas.drawRRect(topRect, Paint()..color = _spongeDark);

    // ---------- 奶油（波浪边 + 挂下来的小尖）----------
    _drawCream(canvas, cx, bottomTop, 148, 14, 7);
    _drawCream(canvas, cx, topTop, 100, 13, 5);

    // ---------- 糖粒 ----------
    final rnd = math.Random(7);
    const sprinkleColors = <Color>[
      Color(0xFFE0526B),
      Color(0xFF4F6BD8),
      Color(0xFF2E9E6B),
      Color(0xFFC9A227),
    ];
    for (var i = 0; i < 14; i++) {
      final x = cx - 70 + rnd.nextDouble() * 140;
      final y = bottomTop + 22 + rnd.nextDouble() * 16;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.nextDouble() * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3.5, -1.1, 7, 2.2),
          const Radius.circular(1.1),
        ),
        Paint()..color = sprinkleColors[i % sprinkleColors.length],
      );
      canvas.restore();
    }

    // ---------- 蜡烛 + 火苗 ----------
    for (var i = 0; i < 3; i++) {
      final x = cx + (i - 1) * 26;
      final candleTop = topTop - 34;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 3.4, candleTop, 6.8, 34),
          const Radius.circular(3),
        ),
        Paint()..color = i.isEven ? _candleA : _candleB,
      );
      // 烛芯
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 1, candleTop - 4, 2, 5),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF5A4632),
      );
      // 每一根的火苗抖得不一样，才像真的在动
      final wobble = math.sin((flicker + i * 0.33) * math.pi * 2);
      _drawFlame(canvas, Offset(x, candleTop - 6), 1 + wobble * 0.16);
    }
  }

  /// 奶油层：一条波浪边，再挂几个小尖
  void _drawCream(
    Canvas canvas,
    double cx,
    double y,
    double width,
    double waveHeight,
    int bumps,
  ) {
    final left = cx - width / 2;
    final path = Path()..moveTo(left, y + waveHeight);
    final step = width / bumps;
    for (var i = 0; i < bumps; i++) {
      final x0 = left + i * step;
      path.quadraticBezierTo(x0 + step / 2, y - waveHeight * 0.35, x0 + step, y + waveHeight * 0.55);
    }
    path
      ..lineTo(left + width, y + 20)
      ..lineTo(left, y + 20)
      ..close();
    canvas.drawPath(path, Paint()..color = _cream);

    // 挂下来的小尖
    for (var i = 0; i < bumps; i++) {
      final x = left + step * (i + 0.5);
      final dropH = 9.0 + (i.isEven ? 5 : 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x - 4.5, y + waveHeight * 0.4, 9, dropH),
          bottomLeft: const Radius.circular(4.5),
          bottomRight: const Radius.circular(4.5),
        ),
        Paint()..color = _cream,
      );
    }
  }

  /// 火苗：外圈橙、内圈黄
  void _drawFlame(Canvas canvas, Offset base, double scale) {
    final h = 20.0 * scale;
    final w = 7.0 * scale;
    final outer = Path()
      ..moveTo(base.dx, base.dy - h)
      ..quadraticBezierTo(base.dx + w, base.dy - h * 0.45, base.dx, base.dy)
      ..quadraticBezierTo(base.dx - w, base.dy - h * 0.45, base.dx, base.dy - h)
      ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFC24B), Color(0xFFE8522A)],
        ).createShader(
          Rect.fromCenter(
            center: Offset(base.dx, base.dy - h / 2),
            width: w * 2,
            height: h,
          ),
        )
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    final inner = Path()
      ..moveTo(base.dx, base.dy - h * 0.62)
      ..quadraticBezierTo(
        base.dx + w * 0.45,
        base.dy - h * 0.3,
        base.dx,
        base.dy - h * 0.06,
      )
      ..quadraticBezierTo(
        base.dx - w * 0.45,
        base.dy - h * 0.3,
        base.dx,
        base.dy - h * 0.62,
      )
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFF3B0));
  }

  @override
  bool shouldRepaint(covariant _CakePainter oldDelegate) =>
      oldDelegate.flicker != flicker;
}
