import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/milestone_themes.dart';
import 'milestone_pattern.dart';

/// 背景主题选择器。
///
/// 用户要求（v1.6.13）：**别再一上来就把 8 套全铺开**（"一下子全部看到、不够高大上"）
/// —— 收起来只显示**当前这套**，点一下才把 8 个展开一起选。
///
/// 每个格子就是那套主题**真实的样子**（底色渐变 + 背景图案），
/// 所见即所得 —— 直接复用 `MilestonePatternPainter`，不另画一套缩略图。
///
/// 纪念日和倒计时共用这一个 —— 两边的主题本来就是同一套（`MilestoneTheme`）。
class ThemePicker extends StatefulWidget {
  const ThemePicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<ThemePicker> createState() => _ThemePickerState();
}

class _ThemePickerState extends State<ThemePicker> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final current = themeStyleOf(widget.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 收起来时的一行：当前背景的**真实缩略图** + 名字 → 点一下展开
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 46,
                    height: 34,
                    child: _Swatch(style: current),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前背景', style: AppText.label(context)),
                      const SizedBox(height: 2),
                      Text(
                        current.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _open ? '收起' : '换一个',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.jade,
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Icon(Icons.expand_more, size: 22, color: p.inkFaint),
                ),
              ],
            ),
          ),
        ),
        // 展开 / 收起那 8 个。用 AnimatedSize 让高度平滑长出来，
        // 而不是"啪"地跳一下 —— 收起时给一个撑满宽度的零高盒子，避免宽度也一起缩。
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _grid(p),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _grid(AppPalette p) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: milestoneThemeStyles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, i) {
        final style = milestoneThemeStyles[i];
        final selected = i == widget.value;
        return GestureDetector(
          // 选完就收起来 —— 收起那一行会立刻变成刚选的那套，反馈很直接
          onTap: () {
            widget.onChanged(i);
            setState(() => _open = false);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? p.jade : Colors.transparent,
                width: 2.4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.5),
              child: Stack(
                children: [
                  Positioned.fill(child: _Swatch(style: style)),
                  // 名字压在底部一条深色带上 —— 不管主题是深是浅都读得清，
                  // 免得把字直接放在图案上、浅色主题下糊成一片
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      color: Colors.black.withValues(alpha: 0.28),
                      child: Text(
                        style.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, size: 12, color: p.jade),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 一套主题的"真实样子"：底色渐变 + 背景图案。
class _Swatch extends StatelessWidget {
  const _Swatch({required this.style});

  final MilestoneThemeStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.gradient,
        ),
      ),
      child: CustomPaint(
        painter: MilestonePatternPainter(style),
        child: const SizedBox.expand(),
      ),
    );
  }
}
