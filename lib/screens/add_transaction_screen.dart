import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quick_entry.dart';
import '../models/transaction_record.dart';
import '../providers/ledger_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import '../widgets/app_toast.dart';
import '../widgets/pay_tag.dart';
import '../widgets/pressable.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.existing});

  /// 传入则为编辑模式
  final TransactionRecord? existing;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late int _type;
  late String _category;
  late DateTime _date;
  late final TextEditingController _note;
  late final TextEditingController _amountController;
  late final FocusNode _noteFocus;
  late int _payMethod;
  String _amount = '0';
  bool _saving = false;

  /// 连记模式：保存后不关页，清空金额和备注接着记下一笔
  bool _batchMode = false;
  int _batchCount = 0;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    _category = e?.category ?? categoriesOf(_type).first.name;
    _date = e?.date ?? DateTime.now();
    _note = TextEditingController(text: e?.note ?? '');
    _noteFocus = FocusNode()..addListener(_onNoteFocus);
    // 编辑老账目时保留它原本的"未记录"（-1），不替它认一个微信；
    // 新建时用默认档。
    _payMethod = e?.payMethod ?? PayMethod.defaultMethod;
    if (e != null) {
      _amount = e.amount == e.amount.roundToDouble()
          ? e.amount.toInt().toString()
          : e.amount.toString();
    }
    _amountController = TextEditingController(text: _amount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 备注框的焦点一变就重画，并把备注滚进可见区域。
  ///
  /// 为什么要靠"焦点"而不是只看系统键盘高度：焦点**立刻**可得，
  /// 而 `MediaQuery.viewInsets` 要靠机型上报 —— 有些 ROM 会晚一两帧、
  /// 甚至一直报 0。那几帧里自带数字键盘还占着屏幕，上半区被压成 0、
  /// 备注框被挤出屏幕，用户就在**看不见输入框的情况下盲打**。
  /// 所以下面 `keyboardOpen` 用的是"键盘高度 > 0 **或** 备注拿到了焦点"。
  void _onNoteFocus() {
    if (mounted) setState(() {});
    if (!_noteFocus.hasFocus) return;
    // 滚两次：第一次等本帧布局（自带键盘收起后上半区变高），
    // 第二次等输入法动画走完 —— 只滚一次会被随后变矮的视口又挤出去。
    _revealNote(const Duration(milliseconds: 220));
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_noteFocus.hasFocus) return;
      _revealNote(const Duration(milliseconds: 160));
    });
  }

  void _revealNote(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = _noteFocus.context;
      if (fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        // 别贴着头顶，留一点余量看着舒服
        alignment: 0.05,
        duration: duration,
        curve: Curves.easeOut,
      );
    });
  }

  void _switchType(int type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _category = categoriesOf(type).first.name;
    });
  }

  void _press(String key) {
    setState(() {
      if (key == 'del') {
        _amount = _amount.length <= 1
            ? '0'
            : _amount.substring(0, _amount.length - 1);
        if (_amount.isEmpty) _amount = '0';
        return;
      }
      if (key == '.') {
        if (!_amount.contains('.')) _amount = '$_amount.';
        return;
      }
      if (_amount == '0') {
        _amount = key;
        return;
      }
      final parts = _amount.split('.');
      if (parts.length == 2 && parts[1].length >= 2) return; // 最多两位小数
      if (_amount.replaceAll('.', '').length >= 9) return; // 金额上限
      _amount = '$_amount$key';
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择记账日期',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final value = double.tryParse(_amount) ?? 0;
    if (value <= 0) {
      AppToast.show(
        context,
        '请先输入金额',
        icon: Icons.error_outline,
        tint: context.palette.warn,
      );
      return;
    }
    Haptics.impact();
    setState(() => _saving = true);

    final record = TransactionRecord(
      id: widget.existing?.id,
      amount: value,
      type: _type,
      category: _category,
      note: _note.text.trim(),
      date: _date,
      payMethod: _payMethod,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await context.read<LedgerProvider>().save(record);

    if (!mounted) return;
    setState(() => _saving = false);

    // 连记模式：不关页，清空金额和备注，接着记下一笔。
    // 这是"批量记账"的核心手感 —— 对着小票/账单一路唰唰记完再退出。
    if (_batchMode && !_isEditing) {
      setState(() {
        _batchCount += 1;
        _amount = '0';
        _amountController.text = '0';
        _note.clear();
      });
      AppToast.show(
        context,
        '已记下 $_batchCount 笔 · $_category ${formatMoney(value)}',
      );
      return;
    }

    // 先弹提示再退出：提示挂在最外层 Overlay 上，不会跟着页面一起消失
    AppToast.show(
      context,
      _isEditing ? '已更新' : '已记下 · $_category ${formatMoney(value)}',
    );
    Navigator.of(context).pop();
  }

  /// 系统键盘输入金额时，把用户敲进来的内容清洗成合法金额文本
  void _onSystemAmountChanged(String raw) {
    final s = sanitizeAmountInput(raw);
    if (_amountController.text != s) {
      _amountController.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
    setState(() => _amount = s);
  }

  /// 点常用项：按今天直接记一笔并退出，不用再确认。
  ///
  /// 这是「常用」这个功能的全部意义 —— 常花的那几笔（比如午饭 15 块），
  /// 从打开到记完应该只要两下。
  Future<void> _recordQuick(QuickEntry entry) async {
    if (_saving) return;
    Haptics.impact();
    setState(() => _saving = true);

    // await 之前先取好依赖，之后就不再碰 context（除了收尾的提示）
    final ledger = context.read<LedgerProvider>();
    final settings = context.read<SettingsProvider>();
    final now = DateTime.now();

    await ledger.save(
      TransactionRecord(
        amount: entry.amount,
        type: entry.type,
        category: entry.category,
        note: entry.note,
        date: now,
        payMethod: entry.resolvedPayMethod,
        createdAt: now,
      ),
    );
    // 用过的提到最前，下次更好找
    await settings.touchQuickEntry(entry);

    if (!mounted) return;
    AppToast.show(
      context,
      '已记账 · ${entry.category} ${formatMoney(entry.amount)}',
    );
    Navigator.of(context).pop();
  }

  /// 把当前填的这整套（类型/分类/金额/备注/支付方式）存成常用项
  Future<void> _saveCurrentAsQuick() async {
    final value = double.tryParse(_amount) ?? 0;
    if (value <= 0) {
      AppToast.show(
        context,
        '先输入金额，再存为常用',
        icon: Icons.error_outline,
        tint: context.palette.warn,
      );
      return;
    }
    await context.read<SettingsProvider>().addQuickEntry(
      QuickEntry(
        type: _type,
        category: _category,
        amount: value,
        note: _note.text.trim(),
        payMethod: _payMethod,
      ),
    );
    if (!mounted) return;
    AppToast.show(
      context,
      '已存为常用 · $_category ${formatMoney(value)}',
      icon: Icons.bookmark_added_outlined,
    );
  }

  Future<void> _confirmDeleteQuick(QuickEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('不用这个常用了？'),
        content: Text('${entry.category}  ${formatMoney(entry.amount)}'),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<SettingsProvider>().removeQuickEntry(entry);
  }

  /// 「查看常用」：整份常用列表，点一下就走人
  Future<void> _openQuickSheet() async {
    Haptics.tap();
    // 界面是模态的，打开期间下面填的东西不会变，取个快照给「存为常用」用
    final snapshot = QuickEntry(
      type: _type,
      category: _category,
      amount: double.tryParse(_amount) ?? 0,
      note: _note.text.trim(),
      payMethod: _payMethod,
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _QuickSheet(
        current: snapshot,
        onPick: (entry) {
          Navigator.of(sheetContext).pop();
          _recordQuick(entry);
        },
        onDelete: (entry) {
          Navigator.of(sheetContext).pop();
          _confirmDeleteQuick(entry);
        },
        onSaveCurrent: () {
          Navigator.of(sheetContext).pop();
          _saveCurrentAsQuick();
        },
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这笔记录？'),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<LedgerProvider>().remove(widget.existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = categoriesOf(_type);
    final tint = _type == TxType.expense ? context.palette.expense : context.palette.income;

    // 系统键盘是否弹出来了。
    //
    // **这一个是本页布局的关键**（用户实测反馈的两个问题都源于它）：
    // ① 键盘占掉几百 dp 后，上面的可滚动区会被压到几乎为零，
    //    备注框被挤出屏幕 → 用户只能盲打、看不到自己写了什么；
    // ② App 自带的数字键盘还留在屏幕上，另一套键盘也在，
    //    用户去点那排数字，改的却是**金额**（他反馈的"数字串入支出价"）。
    // 所以键盘一出来就把自带键盘收起（顺手把不相关的「常用」也收起来让位）。
    // 注意后面那一条 `_noteFocus.hasFocus`：有些机型上报 viewInsets 会晚
    // 一两帧、甚至一直报 0。只看键盘高度的话，那几帧里两套键盘会同时留在
    // 屏幕上，老机型上半区还是被压成 0。焦点是立刻可得的信号，
    // 不依赖机型上报的时机 —— 两条件取"或"，谁先到就听谁的。
    final keyboardOpen =
        MediaQuery.viewInsetsOf(context).bottom > 0 || _noteFocus.hasFocus;

    // 用户在设置里选了"用系统键盘输金额"时，收起自带数字键盘、改用输入框
    final useSystemKeyboard = context.watch<SettingsProvider>().useSystemKeyboard;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑记录' : '记一笔'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: '删除',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          // 连记开关：只在新建时可用（编辑没有"连记"的概念）
          if (!_isEditing) ...[
            if (_batchMode)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Text('已记 $_batchCount 笔', style: AppText.label(context)),
                ),
              ),
            IconButton(
              tooltip: _batchMode ? '关闭连记' : '连记：保存后不关页，接着记下一笔',
              icon: Icon(
                _batchMode ? Icons.library_add : Icons.library_add_outlined,
              ),
              color: _batchMode ? context.palette.jade : null,
              onPressed: () {
                Haptics.tap();
                setState(() {
                  _batchMode = !_batchMode;
                  if (!_batchMode) _batchCount = 0;
                });
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TypeSwitch(type: _type, onChanged: _switchType),
                  const SizedBox(height: 18),
                  _CategoryGrid(
                    categories: categories,
                    selected: _category,
                    onSelected: (name) => setState(() => _category = name),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _note,
                    focusNode: _noteFocus,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: '备注（可选）',
                      prefixIcon: Icon(Icons.edit_note, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DateRow(date: _date, onTap: _pickDate),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            decoration: BoxDecoration(
              color: context.palette.card,
              border: Border(top: BorderSide(color: context.palette.line)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      _type == TxType.expense ? '支出' : '收入',
                      style: AppText.label(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // 金额**绝不能截断**：这是用户正在输入的数字，
                      // 看不全就不知道自己记了多少。
                      child: useSystemKeyboard
                          ? TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textAlign: TextAlign.right,
                              onChanged: _onSystemAmountChanged,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: tint,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                prefixText: '¥ ',
                                prefixStyle: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: tint,
                                ),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '¥${_display(_amount)}',
                                maxLines: 1,
                                softWrap: false,
                                style: AppText.amountHero(
                                  context,
                                ).copyWith(color: tint),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Pressable(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(84, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            backgroundColor: tint,
                          ),
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中' : '保存'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PayMethodPicker(
                  value: _payMethod,
                  onChanged: (v) {
                    Haptics.tap();
                    setState(() => _payMethod = v);
                  },
                ),
                // 系统键盘弹出来时，自带键盘和「常用」都收起来让位给备注框
                if (!keyboardOpen) ...[
                  const SizedBox(height: 10),
                  _QuickBar(
                    entries: context.watch<SettingsProvider>().quickEntries,
                    onPick: _recordQuick,
                    onLongPress: _confirmDeleteQuick,
                    onOpen: _openQuickSheet,
                  ),
                ],
                // 自带数字键盘：只有"没弹系统键盘 + 用户选了自带键盘"才显示
                if (!keyboardOpen && !useSystemKeyboard) ...[
                  const SizedBox(height: 8),
                  _Keypad(onKey: _press),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 给整数部分加千分位，便于读数
  static String _display(String raw) {
    if (raw.isEmpty) return '0';
    final parts = raw.split('.');
    final head = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    if (parts.length > 1) return '$head.${parts[1]}';
    return raw.endsWith('.') ? '$head.' : head;
  }
}

// ---------------------------------------------------------------- 类型切换

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.type, required this.onChanged});

  final int type;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        children: [
          _seg(context, TxType.expense, '支出', context.palette.expense),
          _seg(context, TxType.income, '收入', context.palette.income),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, int value, String label, Color tint) {
    final selected = type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
            Haptics.tap();
            onChanged(value);
          },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? tint : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.palette.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 分类

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<TxCategory> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // 用 LayoutBuilder 按**实际可用宽度**算格子高度，而不是写死 childAspectRatio。
    //
    // 之前写死 0.86 + 图标 46px：在窄屏上格子高度会小于内容高度，
    // 于是 Column 溢出 —— release 包不会显示溢出条纹，只会被悄悄裁掉，
    // 表现为"图标和文字贴着、看着别扭"。这里按内容反推高度，任何宽度都不会溢出。
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 5;
        const gap = 8.0;
        final cellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        // 图标方块跟着格子缩放，但夹在 34~46 之间，别小到看不清
        final iconSize = (cellWidth * 0.80).clamp(34.0, 46.0);
        const labelHeight = 17.0; // 11.5px 字 + 一点行高
        const labelGap = 6.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: gap,
            // 高度按内容反推（设了 mainAxisExtent 就不看 childAspectRatio 了）
            mainAxisExtent: iconSize + labelGap + labelHeight,
          ),
          itemBuilder: (context, i) {
            final c = categories[i];
            final active = c.name == selected;
            // 每个分类用自己的专属色 —— 和账本、统计里是同一个颜色
            final color = context.categoryColor(c.name);
            return GestureDetector(
              onTap: () {
                Haptics.tap();
                onSelected(c.name);
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: active
                          ? color
                          : color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(iconSize * 0.35),
                      border: Border.all(
                        color: active ? color : color.withValues(alpha: 0.22),
                        width: active ? 1.6 : 1,
                      ),
                    ),
                    child: Icon(
                      c.icon,
                      size: iconSize * 0.46,
                      color: active ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(height: labelGap),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? color : context.palette.inkSoft,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------- 日期

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.line),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: context.palette.inkSoft,
            ),
            const SizedBox(width: 10),
            Text(
              dateWithWeekday(date),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: context.palette.ink,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 20, color: context.palette.inkFaint),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 键盘

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = <List<String>>[
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    // 矮屏（老机型 / 开了大字体）把按键压扁一点。
    // 这块是页面里最高的一坨（4 行），键盘一弹出来就靠它让位给备注框；
    // 平时矮屏上也得留出余量，免得上面那半被挤得没法滚。
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyHeight = screenHeight < 700 ? 38.0 : 44.0;
    final keyGap = screenHeight < 700 ? 2.0 : 3.0;

    return Column(
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row)
                Expanded(child: _key(context, key, keyHeight, keyGap)),
            ],
          ),
      ],
    );
  }

  Widget _key(
    BuildContext context,
    String key,
    double keyHeight,
    double keyGap,
  ) {
    final isDelete = key == 'del';
    return Padding(
      padding: EdgeInsets.all(keyGap),
      child: Material(
        color: isDelete ? context.palette.expenseSoft : context.palette.paper,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Haptics.tap();
            onKey(key);
          },
          child: SizedBox(
            height: keyHeight,
            child: Center(
              child: isDelete
                  ? Icon(
                      Icons.backspace_outlined,
                      size: 20,
                      color: context.palette.expense,
                    )
                  : Text(
                      key,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: context.palette.ink,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------- 支付方式

/// 现金 / 微信 / 支付宝 / 银行卡 / 其他。
///
/// 老账目（支付方式这个字段出现之前记的）会显示成「未记录」且一个都不选中，
/// 保存时保持未记录 —— 不替过去的数据瞎认一个。
class _PayMethodPicker extends StatelessWidget {
  const _PayMethodPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = PayMethod.isRecorded(value) ? '支付' : '支付 · 未记录';
    return Row(
      children: [
        Text(label, style: AppText.label(context).copyWith(fontSize: 11.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              for (final m in PayMethod.all) ...[
                Expanded(child: _chip(context, m)),
                if (m != PayMethod.all.last) const SizedBox(width: 5),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, int method) {
    final p = context.palette;
    final selected = method == value;
    return GestureDetector(
      onTap: () => onChanged(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.jade : p.paper,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? p.jade : p.line),
        ),
        child: Text(
          PayMethod.labelOf(method),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                : p.inkSoft,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 常用

/// 键盘上方那一排：左边是常用项（点一下直接记账），右边是「常用」入口
class _QuickBar extends StatelessWidget {
  const _QuickBar({
    required this.entries,
    required this.onPick,
    required this.onLongPress,
    required this.onOpen,
  });

  final List<QuickEntry> entries;
  final ValueChanged<QuickEntry> onPick;
  final ValueChanged<QuickEntry> onLongPress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: entries.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '把常记的几笔存下来，下次点一下就记好',
                      style: AppText.label(context).copyWith(fontSize: 11.5),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (_, i) => _chip(context, entries[i]),
                  ),
          ),
          const SizedBox(width: 8),
          Pressable(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: p.jadeSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmarks_outlined, size: 14, color: p.jade),
                    const SizedBox(width: 4),
                    Text(
                      '常用',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

  Widget _chip(BuildContext context, QuickEntry entry) {
    final p = context.palette;
    final tint = entry.isExpense ? p.expense : p.income;
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onPick(entry);
      },
      onLongPress: () {
        Haptics.warn();
        onLongPress(entry);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: p.paper,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Icon(iconForCategory(entry.category), size: 13, color: tint),
            const SizedBox(width: 5),
            Text(
              entry.category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              entry.amountText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「查看常用」弹层：整份列表 + 把当前这笔存进去
class _QuickSheet extends StatelessWidget {
  const _QuickSheet({
    required this.current,
    required this.onPick,
    required this.onDelete,
    required this.onSaveCurrent,
  });

  /// 当前记一笔界面填的内容，给底部的「存为常用」用
  final QuickEntry current;

  final ValueChanged<QuickEntry> onPick;
  final ValueChanged<QuickEntry> onDelete;
  final VoidCallback onSaveCurrent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final entries = context.watch<SettingsProvider>().quickEntries;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('常用', style: AppText.sectionTitle(context)),
                const SizedBox(width: 8),
                if (entries.isNotEmpty)
                  Text('${entries.length} 条', style: AppText.label(context)),
                const Spacer(),
                Text(
                  '点一下直接记账',
                  style: AppText.label(context).copyWith(fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Text(
                    '还没有常用项。\n'
                    '把常花的那几笔（比如午饭 15 块）存下来，\n'
                    '下次点一下就记好了。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.inkSoft,
                      height: 1.7,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 330),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _QuickRow(
                    entry: entries[i],
                    onTap: () => onPick(entries[i]),
                    onDelete: () => onDelete(entries[i]),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Pressable(
              child: FilledButton.icon(
                onPressed: onSaveCurrent,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(
                  current.amount > 0
                      ? '把当前这笔存为常用 · ${current.category} '
                            '${formatMoneyCompact(current.amount)}'
                      : '把当前这笔存为常用',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final QuickEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = entry.isExpense ? p.expense : p.income;

    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(iconForCategory(entry.category), size: 17, color: tint),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.category,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.isExpense ? '支出' : '收入',
                        style: AppText.label(context).copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      PayTag(method: entry.resolvedPayMethod, compact: true),
                    ],
                  ),
                  if (entry.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(context).copyWith(fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${entry.isExpense ? '-' : '+'}${formatMoney(entry.amount)}',
              style: AppText.amount(
                context,
              ).copyWith(color: entry.isExpense ? p.ink : p.income),
            ),
            IconButton(
              onPressed: onDelete,
              iconSize: 18,
              color: p.inkFaint,
              tooltip: '删除',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
