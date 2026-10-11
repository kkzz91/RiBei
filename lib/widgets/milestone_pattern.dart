import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/milestone_themes.dart';

/// 把主题的背景图案画到画布上。
///
/// 约定：**底色由调用方铺**（那一层渐变），这里只画图案的线条/点，
/// 而且都带透明度、允许画到边界之外（内部会 clip）。
///
/// ⚠️ 所有随机都用**固定种子**：同一套主题在屏幕上和分享图里必须长得一模一样，
/// 不然每次截图纹理都在变，分享出去的图和看到的对不上。
class MilestonePatternPainter extends CustomPainter {
  const MilestonePatternPainter(this.style);

  final MilestoneThemeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (style.pattern) {
      case MilestonePattern.plain:
        break;
      case MilestonePattern.wood:
        _wood(canvas, size);
      case MilestonePattern.hearts:
        _hearts(canvas, size);
      case MilestonePattern.stars:
        _stars(canvas, size);
      case MilestonePattern.waves:
        _waves(canvas, size);
      case MilestonePattern.dots:
        _dots(canvas, size);
      case MilestonePattern.grid:
        _grid(canvas, size);
      case MilestonePattern.diagonal:
        _diagonal(canvas, size);
      case MilestonePattern.diamonds:
        _diamonds(canvas, size);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MilestonePatternPainter oldDelegate) =>
      oldDelegate.style != style;

  // ------------------------------------------------------------------ 木纹

  /// 竖纹木板：几条板缝 + 每条板上几十根轻微摆动的"年轮线" + 几个木节。
  /// 关键是**每条线都沿高度做正弦摆动**，直的竖线看起来像栅栏不像木头。
  void _wood(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rnd = math.Random(70117);
    const planks = 3;
    final plankW = w / planks;

    for (var p = 0; p < planks; p++) {
      final left = p * plankW;
      for (var i = 0; i < 34; i++) {
        final baseX = left + (i + rnd.nextDouble() * 0.8) * plankW / 34;
        final amp = 1.2 + rnd.nextDouble() * 7.5;
        final cycles = 0.7 + rnd.nextDouble() * 2.2;
        final phase = rnd.nextDouble() * math.pi * 2;
        final path = Path()..moveTo(baseX, -6);
        const steps = 20;
        for (var s = 1; s <= steps; s++) {
          final t = s / steps;
          path.lineTo(
            baseX + amp * math.sin(phase + cycles * math.pi * 2 * t),
            h * t,
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7 + rnd.nextDouble() * 1.4
            ..color = i % 3 == 0 ? style.patternInk : style.patternInkSoft,
        );
      }
      // 板缝 = 一道深线 + 一道高光，木板才有厚度
      canvas.drawRect(
        Rect.fromLTWH(left - 1.1, 0, 2.2, h),
        Paint()..color = style.patternInk,
      );
      canvas.drawRect(
        Rect.fromLTWH(left + 1.3, 0, 0.9, h),
        Paint()..color = style.patternInkSoft,
      );
    }

    for (final k in const <Offset>[
      Offset(0.21, 0.15),
      Offset(0.69, 0.62),
      Offset(0.43, 0.89),
      Offset(0.55, 0.34),
    ]) {
      final c = Offset(k.dx * w, k.dy * h);
      for (var ring = 1; ring <= 4; ring++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: w * 0.022 * ring,
            height: w * 0.045 * ring,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = style.patternInk,
        );
      }
    }
  }

  // ------------------------------------------------------- 爱心 + 斜条纹

  void _hearts(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 45° 斜条纹
    final stripe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..color = style.patternInkSoft;
    final stripeStep = w * 0.30;
    for (var x = -h; x < w + h; x += stripeStep) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), stripe);
    }

    // 爱心错行铺开
    final heart = Paint()..color = style.patternInk;
    final heartW = w * 0.070;
    final dx = w * 0.30;
    final dy = h * 0.105;
    var row = 0;
    for (var y = h * 0.045; y < h + dy; y += dy) {
      final shift = row.isOdd ? dx / 2 : 0.0;
      for (var x = dx * 0.35 + shift; x < w + dx; x += dx) {
        _heartPath(canvas, Offset(x, y), heartW, heart);
      }
      row++;
    }
  }

  void _heartPath(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.95)
      ..cubicTo(
        c.dx - r * 1.55,
        c.dy - r * 0.25,
        c.dx - r * 0.55,
        c.dy - r * 1.25,
        c.dx,
        c.dy - r * 0.38,
      )
      ..cubicTo(
        c.dx + r * 0.55,
        c.dy - r * 1.25,
        c.dx + r * 1.55,
        c.dy - r * 0.25,
        c.dx,
        c.dy + r * 0.95,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  // ------------------------------------------------------------------ 星空

  void _stars(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rnd = math.Random(9013);

    // 两团很淡的星云，底色才不至于死平
    for (final c in const <Offset>[Offset(0.20, 0.28), Offset(0.80, 0.70)]) {
      final center = Offset(c.dx * w, c.dy * h);
      final r = w * 0.72;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              style.patternInkSoft.withValues(alpha: 0.20),
              style.patternInkSoft.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    for (var i = 0; i < 240; i++) {
      final c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final r = 0.6 + rnd.nextDouble() * 1.9;
      canvas.drawCircle(
        c,
        r,
        Paint()..color = style.patternInk.withValues(
          alpha: 0.25 + rnd.nextDouble() * 0.7,
        ),
      );
    }

    for (var i = 0; i < 7; i++) {
      final c = Offset(
        w * (0.08 + rnd.nextDouble() * 0.84),
        h * (0.06 + rnd.nextDouble() * 0.88),
      );
      final r = 5.0 + rnd.nextDouble() * 9.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = style.patternInkSoft.withValues(alpha: 0.7);
      canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
      canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
    }
  }

  // ------------------------------------------------------------------ 水波

  void _waves(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final step = h * 0.052;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    var i = 0;
    for (var y = -step; y < h + step; y += step) {
      paint.color = i.isEven ? style.patternInk : style.patternInkSoft;
      final path = Path()..moveTo(-10, y);
      const seg = 6;
      final segW = (w + 20) / seg;
      for (var s = 0; s < seg; s++) {
        path.relativeQuadraticBezierTo(
          segW / 2,
          (s.isEven ? -1 : 1) * step * 0.62,
          segW,
          0,
        );
      }
      canvas.drawPath(path, paint);
      i++;
    }
  }

  // ------------------------------------------------------------------ 波点

  void _dots(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = style.patternInk;
    final r = w * 0.031;
    final dx = w * 0.20;
    final dy = h * 0.085;
    var row = 0;
    for (var y = dy * 0.5; y < h + dy; y += dy) {
      final shift = row.isOdd ? dx / 2 : 0.0;
      for (var x = dx * 0.5 + shift; x < w + dx; x += dx) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
      row++;
    }
  }

  // ------------------------------------------------------------------ 格纸

  void _grid(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final step = w * 0.062;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = style.patternInk;
    for (var x = 0.0; x <= w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    }
    for (var y = 0.0; y <= h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
  }

  // ------------------------------------------------------------------ 斜纹

  void _diagonal(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final step = w * 0.17;
    var i = 0;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + h, h),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i.isEven ? step * 0.46 : step * 0.20
          ..color = i.isEven ? style.patternInkSoft : style.patternInk,
      );
      i++;
    }
  }

  // ------------------------------------------------------------------ 菱格

  void _diamonds(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final step = w * 0.125;
    final strong = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = style.patternInk;
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = style.patternInkSoft;
    var i = 0;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), i.isEven ? strong : soft);
      canvas.drawLine(Offset(x + h, 0), Offset(x, h), i.isEven ? soft : strong);
      i++;
    }
  }
}
