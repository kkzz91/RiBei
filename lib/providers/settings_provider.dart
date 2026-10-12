import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';
import '../models/countdown_event.dart';
import '../models/quick_entry.dart';
import '../utils/haptics.dart';

/// 用户偏好：主题模式、触感反馈。存在 SharedPreferences 里，重启保留。
class SettingsProvider extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode'; // 0 跟随系统 / 1 浅色 / 2 深色
  static const _kHaptics = 'haptics_enabled';
  static const _kHapticStrength = 'haptic_strength'; // 0 轻 / 1 标准 / 2 明显
  static const _kQuickEntries = 'quick_entries';
  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kCountdownSort = 'countdown_sort';
  static const _kBirthdayPrefix = 'birthday_shown_';
  static const _kUseSystemKeyboard = 'use_system_keyboard';
  static const _kBudget = 'monthly_budget';

  ThemeMode _themeMode = ThemeMode.system;
  bool _haptics = true;
  HapticStrength _hapticStrength = HapticStrength.standard;
  bool _ready = false;
  bool _onboardingSeen = false;
  int _countdownSort = CountdownSort.byDays;
  bool _useSystemKeyboard = false;

  ThemeMode get themeMode => _themeMode;
  bool get hapticsEnabled => _haptics;
  HapticStrength get hapticStrength => _hapticStrength;

  /// 首次启动的教程页是否已看过
  bool get onboardingSeen => _onboardingSeen;

  /// 倒计时列表的排序方式，见 [CountdownSort]
  int get countdownSort => _countdownSort;

  /// 记账金额是否改用系统键盘输入（默认 false，用自带键盘）
  bool get useSystemKeyboard => _useSystemKeyboard;

  bool get ready => _ready;

  String get themeModeLabel => switch (_themeMode) {
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
    ThemeMode.system => '跟随系统',
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getInt(_kThemeMode) ?? 0) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _haptics = prefs.getBool(_kHaptics) ?? true;
    _hapticStrength = switch (prefs.getInt(_kHapticStrength) ?? 1) {
      0 => HapticStrength.light,
      2 => HapticStrength.strong,
      _ => HapticStrength.standard,
    };
    final storedEntries = prefs.getStringList(_kQuickEntries);
    if (storedEntries != null) {
      _quickEntries = List<QuickEntry>.unmodifiable(
        storedEntries.map(QuickEntry.decode).whereType<QuickEntry>(),
      );
    }
    _onboardingSeen = prefs.getBool(_kOnboardingSeen) ?? false;
    final sort = prefs.getInt(_kCountdownSort);
    if (sort != null && CountdownSort.all.contains(sort)) {
      _countdownSort = sort;
    }
    _useSystemKeyboard = prefs.getBool(_kUseSystemKeyboard) ?? false;
    final storedBudget = prefs.getString(_kBudget);
    if (storedBudget != null) _budget = BudgetPlan.decode(storedBudget);
    // 生日惊喜：只记"哪个事件在哪天庆祝过了"，键名带前缀，扫一遍即可
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kBirthdayPrefix)) continue;
      final id = int.tryParse(key.substring(_kBirthdayPrefix.length));
      final day = prefs.getString(key);
      if (id != null && day != null) _birthdayShown[id] = day;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, switch (mode) {
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
      ThemeMode.system => 0,
    });
  }

  Future<void> setHaptics(bool enabled) async {
    if (enabled == _haptics) return;
    _haptics = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHaptics, enabled);
  }

  Future<void> setHapticStrength(HapticStrength value) async {
    if (value == _hapticStrength) return;
    _hapticStrength = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHapticStrength, value.index);
  }

  // ---------- 常用（一整套记账） ----------

  /// 最多存这么多条，超了从最旧的开始丢
  static const _maxQuickEntries = 12;

  List<QuickEntry> _quickEntries = const <QuickEntry>[];

  /// 记一笔界面上的「常用」列表，最近用过的排在最前
  List<QuickEntry> get quickEntries => _quickEntries;

  Future<void> setQuickEntries(List<QuickEntry> entries) async {
    _quickEntries = List<QuickEntry>.unmodifiable(entries);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kQuickEntries,
      _quickEntries.map((e) => e.encode()).toList(),
    );
  }

  /// 存一条常用。同一条（分类+金额+备注+方向都一样）已存在时，
  /// 不重复添加而是提到最前，并顺手更新它的支付方式。
  Future<void> addQuickEntry(QuickEntry entry) async {
    final next = <QuickEntry>[
      entry,
      ..._quickEntries.where((e) => e.key != entry.key),
    ];
    await setQuickEntries(
      next.length > _maxQuickEntries ? next.sublist(0, _maxQuickEntries) : next,
    );
  }

  Future<void> removeQuickEntry(QuickEntry entry) async {
    if (!_quickEntries.any((e) => e.key == entry.key)) return;
    await setQuickEntries(
      _quickEntries.where((e) => e.key != entry.key).toList(),
    );
  }

  /// 用过一次就提到最前，下次更好找
  Future<void> touchQuickEntry(QuickEntry entry) async {
    if (_quickEntries.isEmpty) return;
    if (_quickEntries.first.key == entry.key) return;
    await addQuickEntry(entry);
  }

  // ---------- 首次教程 ----------

  /// 教程看过了。只写不撤 —— 教程是一次性的。
  Future<void> markOnboardingSeen() async {
    if (_onboardingSeen) return;
    _onboardingSeen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeen, true);
  }

  // ---------- 倒计时排序 ----------

  Future<void> setCountdownSort(int value) async {
    if (value == _countdownSort) return;
    _countdownSort = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCountdownSort, value);
  }

  // ---------- 记账金额输入方式 ----------

  Future<void> setUseSystemKeyboard(bool value) async {
    if (value == _useSystemKeyboard) return;
    _useSystemKeyboard = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseSystemKeyboard, value);
  }

  // ---------- 月度预算 ----------

  BudgetPlan _budget = BudgetPlan.none;

  /// 月度预算：总额 + 用户自己加的那几条金额红线（见 [BudgetPlan]）
  BudgetPlan get budget => _budget;

  Future<void> setBudget(BudgetPlan plan) async {
    _budget = plan;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBudget, plan.encode());
  }

  // ---------- 生日惊喜 ----------

  /// 事件 id → 上次庆祝的日期（yyyy-M-d）。
  /// 存的是"日期"而不是"是否庆祝过"，所以到了明年同一天会自动再触发一次。
  final Map<int, String> _birthdayShown = <int, String>{};

  /// 这个生日在 [day] 这天已经庆祝过了吗
  bool birthdayCelebrated(int eventId, String day) =>
      _birthdayShown[eventId] == day;

  Future<void> markBirthdayCelebrated(int eventId, String day) async {
    if (_birthdayShown[eventId] == day) return;
    _birthdayShown[eventId] = day;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kBirthdayPrefix$eventId', day);
  }
}
