/// 大数字的字体风格。
///
/// 用的是 **Android 自带的字族**（serif / monospace / condensed …），
/// 所以**不用往仓库里塞字体文件** —— 加字体要进 `pubspec.yaml` 的 assets 声明，
/// 漏声明不报错、只在运行时加载不出来（红线 10）。这些字族对**数字**的观感差别很明显，够用。
class DigitFont {
  const DigitFont._();

  static const classic = 0; // 跟随系统（默认）
  static const serif = 1; // 衬线：有点"老派日历"的味道
  static const mono = 2; // 等宽：数字一样宽，冷峻
  static const condensed = 3; // 窄体：同样宽度塞得下更多位
  static const thin = 4; // 细体：轻盈

  static const all = <int>[classic, serif, mono, condensed, thin];

  static const labels = <int, String>{
    classic: '经典',
    serif: '衬线',
    mono: '等宽',
    condensed: '窄体',
    thin: '细体',
  };

  /// Android 的字族名；返回 null 表示用系统默认
  static String? familyOf(int font) {
    switch (font) {
      case serif:
        return 'serif';
      case mono:
        return 'monospace';
      case condensed:
        return 'sans-serif-condensed';
      case thin:
        return 'sans-serif-thin';
      default:
        return null;
    }
  }

  /// 越界的值兜到"经典"，不崩
  static int clamp(int font) =>
      (font >= 0 && font < all.length) ? font : classic;
}
