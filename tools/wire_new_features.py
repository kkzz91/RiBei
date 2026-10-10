"""接上搜索入口、常用金额、重复任务滚动。"""
import io

LEDGER = r'E:\ribei\lib\screens\ledger_screen.dart'
TRANS = r'E:\ribei\lib\screens\add_transaction_screen.dart'
SHELL = r'E:\ribei\lib\screens\main_shell.dart'

# ---------- 1) 账本加搜索入口 ----------
LEDGER_IMPORT_OLD = "import 'add_transaction_screen.dart';"
LEDGER_IMPORT_NEW = (
    "import 'add_transaction_screen.dart';\nimport 'search_screen.dart';"
)

LEDGER_ACTION_OLD = """        actions: [
          IconButton(
            tooltip: '设置',"""
LEDGER_ACTION_NEW = """        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () {
              Haptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            tooltip: '设置',"""

# ---------- 2) 记一笔加常用金额 ----------
TRANS_IMPORT_OLD = "import '../providers/ledger_provider.dart';"
TRANS_IMPORT_NEW = (
    "import '../providers/ledger_provider.dart';\n"
    "import '../providers/settings_provider.dart';"
)

TRANS_UI_OLD = """                const SizedBox(height: 8),
                _Keypad(onKey: _press),"""
TRANS_UI_NEW = """                const SizedBox(height: 8),
                _QuickAmounts(
                  values: context.watch<SettingsProvider>().quickAmounts,
                  onPick: (v) => setState(() => _amount = _presetText(v)),
                  onSaveCurrent: () async {
                    final v = double.tryParse(_amount) ?? 0;
                    if (v <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('先输入金额再存为常用')),
                      );
                      return;
                    }
                    await context.read<SettingsProvider>().addQuickAmount(v);
                  },
                ),
                const SizedBox(height: 8),
                _Keypad(onKey: _press),"""

TRANS_METHOD_OLD = """  /// 给整数部分加千分位，便于读数"""
TRANS_METHOD_NEW = """  /// 把常用金额转成键盘能继续编辑的文本（整数不带小数点）
  static String _presetText(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  /// 给整数部分加千分位，便于读数"""

TRANS_WIDGETS = """

// ---------------------------------------------------------------- 常用金额

class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({
    required this.values,
    required this.onPick,
    required this.onSaveCurrent,
  });

  final List<double> values;
  final ValueChanged<double> onPick;
  final VoidCallback onSaveCurrent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: values.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '把常花的金额存下来，下次一点就填',
                      style: AppText.label(context).copyWith(fontSize: 11.5),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (_, i) {
                      final v = values[i];
                      return GestureDetector(
                        onTap: () {
                          Haptics.tap();
                          onPick(v);
                        },
                        onLongPress: () {
                          Haptics.warn();
                          context.read<SettingsProvider>().removeQuickAmount(v);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: p.paper,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: p.line),
                          ),
                          child: Text(
                            formatMoneyCompact(v).replaceAll('¥', ''),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: p.jade,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '把当前金额存为常用（长按已有金额可删除）',
            child: InkWell(
              onTap: () {
                Haptics.impact();
                onSaveCurrent();
              },
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: p.jadeSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_add_outlined, size: 14, color: p.jade),
                    const SizedBox(width: 4),
                    Text(
                      '存为常用',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: p.jade,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
"""

# ---------- 3) 启动时滚动重复任务 ----------
SHELL_OLD = """    await countdowns.load();
    await todos.load();
    await service.rescheduleAll("""
SHELL_NEW = """    await countdowns.load();
    await todos.load();
    // 重复任务到期后自动滚到下一个周期，
    // 免得"每周一交作业"很久没开 App 回来显示成逾期几十天
    await todos.rollForwardRepeating();
    await service.rescheduleAll("""


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


patch(
    LEDGER,
    [(LEDGER_IMPORT_OLD, LEDGER_IMPORT_NEW), (LEDGER_ACTION_OLD, LEDGER_ACTION_NEW)],
    'ledger',
)
patch(
    TRANS,
    [
        (TRANS_IMPORT_OLD, TRANS_IMPORT_NEW),
        (TRANS_UI_OLD, TRANS_UI_NEW),
        (TRANS_METHOD_OLD, TRANS_METHOD_NEW),
    ],
    'add_transaction',
)
patch(SHELL, [(SHELL_OLD, SHELL_NEW)], 'main_shell')

# 追加 _QuickAmounts 组件
with io.open(TRANS, encoding='utf-8') as f:
    t = f.read()
if 'class _QuickAmounts' in t:
    print('  -- _QuickAmounts 已存在')
else:
    t = t.rstrip('\n') + '\n' + TRANS_WIDGETS
    with io.open(TRANS, 'w', encoding='utf-8') as f:
        f.write(t)
    print('  == _QuickAmounts 已追加')
