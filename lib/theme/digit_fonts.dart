import 'package:flutter/material.dart';

/// 大数字的字体风格。
///
/// 用的是 **Android 自带的字族**（serif / monospace / condensed / cursive …），
/// 所以**不用往仓库里塞字体文件** —— 加字体要进 `pubspec.yaml` 的 assets 声明，
/// 漏声明不报错、只在运行时加载不出来（红线 10）。这些字族对**数字**的观感差别很明显，够用。
///
/// ⚠️ 各机型预装的字族不完全一样，缺哪个就会自动回退到系统默认 ——
/// 所以**每种都给个名字**，用户看到"手写"没变手写会来反馈，别当成代码 bug 去查。
class DigitFont {
  const DigitFont._();

  static const classic = 0; // 跟随系统（默认）
  static const serif = 1; // 衬线：老派日历的味道
  static const italic = 2; // 斜体：衬线 + 倾斜
  static const mono = 3; // 等宽：数字一样宽，冷峻
  static const condensed = 4; // 窄体：同样宽度塞得下更多位
  static const thin = 5; // 细体：轻盈
  static const hand = 6; // 手写：有点笔记感（依赖机型自带的手写字族）

  static const all = <int>[classic, serif, italic, mono, condensed, thin, hand];

  static const labels = <int, String>{
    classic: '经典',
    serif: '衬线',
    italic: '斜体',
    mono: '等宽',
    condensed: '窄体',
    thin: '细体',
    hand: '手写',
  };

  /// 字族名；返回 null 表示用系统默认
  static String? familyOf(int font) {
    switch (font) {
      case serif:
      case italic:
        return 'serif';
      case mono:
        return 'monospace';
      case condensed:
        return 'sans-serif-condensed';
      case thin:
        return 'sans-serif-thin';
      case hand:
        return 'cursive';
      default:
        return null;
    }
  }

  /// 是否倾斜
  static FontStyle styleOf(int font) =>
      font == italic ? FontStyle.italic : FontStyle.normal;

  /// 一次性拿到该字体要设的那两样，省得每处都写一遍
  static TextStyle apply(TextStyle base, int font) => base.copyWith(
    fontFamily: familyOf(font),
    fontStyle: styleOf(font),
  );

  /// 越界的值兜到"经典"，不崩
  static int clamp(int font) =>
      (font >= 0 && font < all.length) ? font : classic;
}
