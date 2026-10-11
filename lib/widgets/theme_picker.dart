import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/milestone_themes.dart';
import 'milestone_pattern.dart';

/// 背景主题选择器：每个格子就是那套主题**真实的样子**（底色渐变 + 背景图案），
/// 所见即所得 —— 直接复用 `MilestonePatternPainter`，不另画一套缩略图。
///
/// 纪念日和倒计时共用这一个 —— 两边的主题本来就是同一套（`MilestoneTheme`）。
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
        final selected = i == value;
        return GestureDetector(
          onTap: () => onChanged(i),
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: style.gradient,
                  ),
                ),
                child: CustomPaint(
                  painter: MilestonePatternPainter(style),
                  child: Stack(
                    children: [
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
            ),
          ),
        );
      },
    );
  }
}
