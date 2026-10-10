import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 顶部落下的轻提示（右上角）。
///
/// 为什么不用 SnackBar：
/// 1. SnackBar 固定贴在底部，会被右下角的悬浮按钮压住；
/// 2. 它挂在当前页面的 Scaffold 上，页面一 pop 就跟着消失 ——
///    而「点常用项直接记账」正是"记完就退出"的场景，提示必须留在上一个页面。
///
/// 所以这里走 Overlay（且用 rootOverlay），提示不随页面进出而丢失。
class AppToast {
  AppToast._();

  /// 当前正显示的那一条，保证同一时刻只有一条
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_rounded,
    Color? tint,
  }) {
    final palette = context.palette;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // 连续操作时把上一条顶掉，避免堆成一列
    final previous = _current;
    if (previous != null && previous.mounted) previous.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastCard(
        message: message,
        icon: icon,
        tint: tint ?? palette.jade,
        onDismissed: () => _clearIfCurrent(entry),
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void _clearIfCurrent(OverlayEntry entry) {
    if (!identical(_current, entry)) return;
    if (entry.mounted) entry.remove();
    _current = null;
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.icon,
    required this.tint,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final Color tint;
  final VoidCallback onDismissed;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _hold = Timer(const Duration(milliseconds: 1700), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FadeTransition(
              opacity: _controller,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.6),
                  end: Offset.zero,
                ).animate(_curved),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 9, 16, 9),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: widget.tint.withValues(alpha: 0.28)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: p.isDark ? 0.4 : 0.13),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.tint.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.icon, size: 15, color: widget.tint),
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: p.ink,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
