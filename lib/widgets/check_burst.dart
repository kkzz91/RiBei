import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 「勾掉一项」时在点击位置炸开的一小圈反馈。
///
/// 为什么要走 Overlay：勾完之后那一项**立刻就从列表里消失了**
/// （未完成列表默认不显示已完成项），挂在列表项上的动画会跟着一起没。
/// 放进最外层 Overlay，动画就和列表的重建无关了，每次都能完整放完。
class CheckBurst {
  CheckBurst._();

  static void show(BuildContext context, Offset position, {Color? tint}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BurstLayer(
        position: position,
        color: tint ?? context.palette.jade,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({
    required this.position,
    required this.color,
    required this.onDone,
  });

  final Offset position;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      // ⚠️ 不要写 `if (mounted)`：动画播完时组件可能已经卸载，
      // 那样 overlay 里那条就**永远不摘**了（和 AppToast 是同一个坑，见那个文件的注释）。
      // 这里外面套了 IgnorePointer，所以不会吃点击，但会白留一层看不见的浮层。
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // 纯装饰，绝不能挡住底下的点击
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _BurstPainter(
              progress: _controller.value,
              color: widget.color,
              center: widget.position,
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.progress,
    required this.color,
    required this.center,
  });

  final double progress;
  final Color color;
  final Offset center;

  static const _dotCount = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);

    // ① 往外扩的环，扩完即淡出
    final ringT = Curves.easeOut.transform((t / 0.7).clamp(0.0, 1.0));
    canvas.drawCircle(
      center,
      13 + 30 * ringT,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * (1 - ringT) + 0.6
        ..color = color.withValues(alpha: 0.5 * (1 - ringT))
        ..isAntiAlias = true,
    );

    // ② 六个小点向外飞散
    final dotT = Curves.easeOut.transform((t / 0.8).clamp(0.0, 1.0));
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.65 * (1 - dotT))
      ..isAntiAlias = true;
    for (var i = 0; i < _dotCount; i++) {
      final angle = (math.pi * 2 / _dotCount) * i - math.pi / 2;
      final r = 10 + 26 * dotT;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * r, math.sin(angle) * r),
        2.6 * (1 - dotT) + 0.5,
        dotPaint,
      );
    }

    // ③ 正中的勾：先弹出来、后段淡出
    final popIn = const Interval(
      0.05,
      0.5,
      curve: Curves.easeOutBack,
    ).transform(t);
    final fadeOut = 1 -
        const Interval(0.7, 1.0, curve: Curves.easeIn).transform(t);
    if (popIn > 0 && fadeOut > 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(popIn);
      canvas.drawPath(
        Path()
          ..moveTo(-6.4, 0.6)
          ..lineTo(-1.8, 5.0)
          ..lineTo(6.6, -4.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: fadeOut)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.center != center ||
      oldDelegate.color != color;
}
