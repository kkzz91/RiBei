import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/digit_fonts.dart';

/// 数字字体选择：横向一排，**每个按钮直接用那种字体显示 126**，所见即所得。
///
/// 用的是 Android 自带字族（见 [DigitFont]），不需要往仓库塞字体文件。
class DigitFontPicker extends StatelessWidget {
  const DigitFontPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DigitFont.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final font = DigitFont.all[i];
          final selected = font == value;
          return GestureDetector(
            onTap: () => onChanged(font),
            child: Container(
              width: 78,
              decoration: BoxDecoration(
                color: selected ? p.jadeSoft : p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? p.jade : p.line,
                  width: selected ? 1.8 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '126',
                    maxLines: 1,
                    style: DigitFont.apply(
                      TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: p.ink,
                      ),
                      font,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DigitFont.labels[font] ?? '',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? p.jade : p.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
