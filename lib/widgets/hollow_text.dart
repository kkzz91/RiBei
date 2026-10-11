import 'package:flutter/material.dart';

/// "镂空透明立体字"：**描边 + 极淡填充 + 一道向下的暗色深度**。
///
/// 用户要的是参考图那种质感 —— 字是"空心的"，只有一圈亮边，里面透出背景，
/// 底下再垫一层暗色做出厚度。纯用 `TextStyle` 做不出来，得叠三层 `Text`。
class HollowText extends StatelessWidget {
  const HollowText(
    this.text, {
    super.key,
    required this.size,
    required this.color,
    this.tracking = 5,
    this.depth = 1.8,
    this.strokeWidth = 1.2,
  });

  final String text;
  final double size;

  /// 描边的颜色（一般给主题的强调色）
  final Color color;

  final double tracking;

  /// 立体感的"厚度"：暗色那层往下偏多少
  final double depth;

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
          // ③ 厚度：往右下偏一点的暗色。垫在最底下，露出来的那一线就是"立体"
          Transform.translate(
            offset: Offset(0, depth),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: base.copyWith(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          // ② 微微填充一点，不然空心字在浅色背景上会完全看不见
          Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              color: color.withValues(alpha: 0.16),
            ),
          ),
          // ① 描边：只画轮廓，中间是透的
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
