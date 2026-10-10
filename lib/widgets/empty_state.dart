import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 统一的空状态：一小幅矢量插画 + 一句话 + 可选的操作按钮。
///
/// 全部用代码画（没有图片素材）：柔色圆斑 + 微微歪着的"纸片" + 图标 + 小星点，
/// 四个页面共用一套，风格天然一致，也不会让 APK 变大。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.tint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;

  /// 主题色，默认玉青。倒计时/待办可以传各自的强调色。
  final Color? tint;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = tint ?? p.jade;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 46),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
              ),
              child: _Illustration(icon: icon, accent: accent),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: p.ink,
                height: 1.4,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 7),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: p.inkSoft,
                  height: 1.6,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 134,
      height: 122,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背后的大柔色圆斑
          Positioned(
            left: 4,
            top: 8,
            child: _Blob(size: 100, color: accent.withValues(alpha: 0.09)),
          ),
          // 歪着的一张"纸片"，让画面不那么规整
          Positioned(
            right: 10,
            top: 4,
            child: Transform.rotate(
              angle: 0.24,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
          // 正中的卡片 + 图标
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: p.line),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: p.isDark ? 0.22 : 0.13),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, size: 37, color: accent),
          ),
          // 小星点
          Positioned(
            right: 2,
            bottom: 26,
            child: _Sparkle(size: 17, color: accent.withValues(alpha: 0.62)),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _Sparkle(size: 10, color: accent.withValues(alpha: 0.38)),
          ),
          Positioned(
            left: 2,
            top: 16,
            child: _Blob(size: 11, color: accent.withValues(alpha: 0.20)),
          ),
        ],
      ),
    );
  }
}

/// 柔色圆斑
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 四角星：四个内凹的尖角，画起来比圆形有趣
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(color),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final waist = r * 0.23;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + waist, c.dy - waist, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + waist, c.dy + waist, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - waist, c.dy + waist, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - waist, c.dy - waist, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
