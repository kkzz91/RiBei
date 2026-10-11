import 'package:flutter/material.dart';

/// "镂空透明立体字"：**一圈深色外描边 + 一圈亮色描边 + 极淡填充**。
///
/// 用户要的是参考图那种质感 —— 字是"空心"的、只有轮廓，里面透出背景。
///
/// ⚠️ 第一版画得不好：用了一层"往下偏移的暗色副本"做厚度，结果**在花纹背景上
/// 一团糊**，在浅色背景上又像半透明。现在改成**只靠两道描边**：
/// 一道更粗的深色在外（给字一圈"托底"，任何背景上都立得住），
/// 一道亮色在内（字的主体），最后垫一层极淡填充让笔画内部有一点体积。
/// **不要再加偏移副本** —— 那就是糊的来源。
class HollowText extends StatelessWidget {
  const HollowText(
    this.text, {
    super.key,
    required this.size,
    required this.color,
    this.tracking = 5,
    this.strokeWidth = 1.4,
  });

  final String text;
  final double size;

  /// 描边的颜色（一般给主题的强调色）
  final Color color;

  final double tracking;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: tracking,
      height: 1.1,
    );
    // letterSpacing 会在最后一个字后面也垫一份，往左补偿一下才视觉居中
    return Transform.translate(
      offset: Offset(tracking / 2, 0),
      child: Stack(
        children: [
          // ① 外圈深色描边：托底，让字在浅色/花纹背景上也立得住
          Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth * 2.8
                ..color = Colors.black.withValues(alpha: 0.38),
            ),
          ),
          // ② 亮色描边：字的主体。**中间完全是透的** ——
          // ⚠️ 这里**刻意不再叠一层填充**：描边 + 填充叠在同一个字形上，
          // 会看成"字里面又写了一遍"（用户原话"像字里面写重复了"）。
          Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..color = color,
            ),
          ),
        ],
      ),
    );
  }
}
