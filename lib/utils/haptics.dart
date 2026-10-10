import 'package:flutter/services.dart';

/// 触感强度。不同机型马达素质差异很大，让用户自己调比写死更靠谱。
enum HapticStrength {
  light('轻柔'),
  standard('标准'),
  strong('明显');

  const HapticStrength(this.label);

  final String label;
}

/// 触感反馈的统一入口。
///
/// 走系统 HapticFeedback（底层 View.performHapticFeedback），
/// 所以它**遵循系统设置**：手机上「设置 → 声音与触感 → 触感反馈」关掉的话，
/// 这里调用也不会有反应 —— 这是系统行为，不是 bug。
///
/// Flutter 到 Android 常量的映射（决定了手感）：
///   selectionClick -> CLOCK_TICK    最轻
///   lightImpact    -> VIRTUAL_KEY   虚拟键
///   mediumImpact   -> KEYBOARD_TAP  键盘敲击 ← 输入法/微信用的就是这一档
///   heavyImpact    -> CONTEXT_CLICK 较重
///   vibrate        -> LONG_PRESS    最重
class Haptics {
  Haptics._();

  static bool enabled = true;
  static HapticStrength strength = HapticStrength.standard;

  /// 轻点：数字键盘、选分类、切收支、切 tab 这类高频轻交互
  static void tap() {
    if (!enabled) return;
    switch (strength) {
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.standard:
        HapticFeedback.mediumImpact();
      case HapticStrength.strong:
        HapticFeedback.heavyImpact();
    }
  }

  /// 落点：勾选完成、保存这类有明确结果的操作
  static void impact() {
    if (!enabled) return;
    switch (strength) {
      case HapticStrength.light:
        HapticFeedback.mediumImpact();
      case HapticStrength.standard:
        HapticFeedback.heavyImpact();
      case HapticStrength.strong:
        HapticFeedback.vibrate();
    }
  }

  /// 警告：删除、清空这类破坏性操作
  static void warn() {
    if (!enabled) return;
    switch (strength) {
      case HapticStrength.light:
        HapticFeedback.heavyImpact();
      case HapticStrength.standard:
        HapticFeedback.vibrate();
      case HapticStrength.strong:
        HapticFeedback.vibrate();
    }
  }
}
