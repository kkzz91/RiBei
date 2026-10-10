"""ledger_provider 加搜索；settings_provider 加常用金额。"""
import io

LEDGER = r'E:\ribei\lib\providers\ledger_provider.dart'
SETTINGS = r'E:\ribei\lib\providers\settings_provider.dart'

SEARCH_METHOD = """
  /// 关键字搜索：匹配备注、分类，也支持金额片段（如输入 12.5）
  List<TransactionRecord> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <TransactionRecord>[];
    return _records.where((r) {
      if (r.note.toLowerCase().contains(q)) return true;
      if (r.category.toLowerCase().contains(q)) return true;
      if (r.amount.toStringAsFixed(2).contains(q)) return true;
      return false;
    }).toList();
  }
"""

SETTINGS_FIELD_OLD = "  static const _kHapticStrength = 'haptic_strength'; // 0 轻 / 1 标准 / 2 明显"
SETTINGS_FIELD_NEW = (
    SETTINGS_FIELD_OLD
    + "\n  static const _kQuickAmounts = 'quick_amounts';"
)

SETTINGS_LOAD_OLD = """    _ready = true;
    notifyListeners();
  }"""
SETTINGS_LOAD_NEW = """    final stored = prefs.getStringList(_kQuickAmounts);
    if (stored != null) {
      final parsed = stored
          .map(double.tryParse)
          .whereType<double>()
          .where((v) => v > 0)
          .toList();
      if (parsed.isNotEmpty) _quickAmounts = parsed;
    }
    _ready = true;
    notifyListeners();
  }"""

SETTINGS_TAIL_OLD = """  Future<void> setHapticStrength(HapticStrength value) async {
    if (value == _hapticStrength) return;
    _hapticStrength = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHapticStrength, value.index);
  }
}"""

SETTINGS_TAIL_NEW = """  Future<void> setHapticStrength(HapticStrength value) async {
    if (value == _hapticStrength) return;
    _hapticStrength = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHapticStrength, value.index);
  }

  // ---------- 常用金额 ----------

  List<double> _quickAmounts = const <double>[10, 20, 30, 50, 100];

  /// 记一笔界面上的一排快捷金额
  List<double> get quickAmounts => _quickAmounts;

  Future<void> setQuickAmounts(List<double> values) async {
    _quickAmounts = List<double>.unmodifiable(values);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kQuickAmounts,
      _quickAmounts.map((v) => v.toString()).toList(),
    );
  }

  /// 把当前金额存成常用（最多 12 个）
  Future<void> addQuickAmount(double value) async {
    if (value <= 0 || _quickAmounts.contains(value)) return;
    final next = <double>[..._quickAmounts, value]..sort();
    await setQuickAmounts(next.length > 12 ? next.sublist(0, 12) : next);
  }

  Future<void> removeQuickAmount(double value) async {
    if (!_quickAmounts.contains(value)) return;
    await setQuickAmounts(_quickAmounts.where((v) => v != value).toList());
  }
}"""


def patch(path, pairs, label):
    with io.open(path, encoding='utf-8') as f:
        src = f.read()
    for i, (old, new) in enumerate(pairs, 1):
        n = src.count(old)
        if n != 1:
            print('  !! %s 规则 %d 命中 %d 次' % (label, i, n))
            continue
        src = src.replace(old, new, 1)
        print('  == %s 规则 %d ok' % (label, i))
    with io.open(path, 'w', encoding='utf-8') as f:
        f.write(src)


# ---- ledger：把 search 插在类的最后一个右括号之前 ----
with io.open(LEDGER, encoding='utf-8') as f:
    led = f.read()
if 'List<TransactionRecord> search(' in led:
    print('  -- ledger search 已存在')
else:
    stripped = led.rstrip()
    if stripped.endswith('}'):
        idx = len(stripped) - 1
        led = stripped[:idx] + SEARCH_METHOD + '}' + '\n'
        with io.open(LEDGER, 'w', encoding='utf-8') as f:
            f.write(led)
        print('  == ledger search 已加入')
    else:
        print('  !! ledger 结尾不是 }，未改动')

patch(
    SETTINGS,
    [
        (SETTINGS_FIELD_OLD, SETTINGS_FIELD_NEW),
        (SETTINGS_LOAD_OLD, SETTINGS_LOAD_NEW),
        (SETTINGS_TAIL_OLD, SETTINGS_TAIL_NEW),
    ],
    'settings',
)
