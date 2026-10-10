import 'package:flutter/material.dart';

/// 按下时整体微微缩小，松开弹回 —— 给按钮一点"手感"。
///
/// 只做"动画"，**不接管点击**：用 [Listener] 旁听指针事件，
/// 手势仍然由里面的按钮自己处理。
/// 这样任何现成控件（FilledButton / Card / 自定义块）都能直接套一层，不用改它的行为。
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.scale = 0.955,
    this.duration = const Duration(milliseconds: 110),
  });

  final Widget child;

  /// 按下时缩到原尺寸的几成（0.9~1 之间比较自然）
  final double scale;

  final Duration duration;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 入场动画：淡入 + 轻轻上浮。
///
/// 列表里的卡片按 [index] 依次延后一点点出现，看起来是"铺"出来的，
/// 比整屏同时闪出来舒服。
class StaggeredFadeIn extends StatelessWidget {
  const StaggeredFadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    // 只让前若干个有延迟，否则长列表最后几项要等很久
    final delay = step * (index.clamp(0, 6));
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) {
        // 延迟期间保持透明：把总时长拉长、再按比例偏移，等效于"先等后动"
        final total = (duration + delay).inMilliseconds;
        final offset = delay.inMilliseconds / total;
        final local = offset >= 1
            ? 1.0
            : t <= offset
            ? 0.0
            : (t - offset) / (1 - offset);
        return Opacity(
          opacity: local,
          child: Transform.translate(
            offset: Offset(0, (1 - local) * 12),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}
