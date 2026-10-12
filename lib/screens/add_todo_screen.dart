import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class AddTodoScreen extends StatefulWidget {
  const AddTodoScreen({super.key, this.existing});

  final TodoItem? existing;

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> {
  /// 逾期宽限的可选时长（分钟）
  static const _graceOptions = <int>[0, 15, 30, 60, 120, 240];

  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _dueAt;
  late bool _remind;
  late int _priority;
  late int _repeat;
  late int _graceMinutes;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _dueAt = e?.dueAt ?? _defaultDue();
    _remind = e?.remindEnabled ?? true;
    _priority = e?.priority ?? TodoPriority.normal;
    _repeat = e?.repeat ?? TodoRepeat.none;
    _graceMinutes = e?.graceMinutes ?? 0;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 默认提醒时间：下一个整点；太晚（21 点后）顺延到明天 9 点
  static DateTime _defaultDue() {
    final now = DateTime.now();
    if (now.hour >= 21) {
      final t = now.add(const Duration(days: 1));
      return DateTime(t.year, t.month, t.day, 9, 0);
    }
    final next = now.add(const Duration(hours: 1));
    return DateTime(next.year, next.month, next.day, next.hour, 0);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt.isBefore(now) ? now : _dueAt,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: '选择日期',
    );
    if (picked != null) {
      setState(() {
        _dueAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _dueAt.hour,
          _dueAt.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _dueAt.hour, minute: _dueAt.minute),
      helpText: '选择提醒时间',
    );
    if (picked != null) {
      setState(() {
        _dueAt = DateTime(
          _dueAt.year,
          _dueAt.month,
          _dueAt.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _quickDay(int daysFromToday) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day + daysFromToday);
    setState(() {
      _dueAt = DateTime(
        day.year,
        day.month,
        day.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先写点要做什么')),
      );
      return;
    }

    setState(() => _saving = true);

    final todo = TodoItem(
      id: widget.existing?.id,
      title: title,
      note: _note.text.trim(),
      dueAt: _dueAt,
      remindEnabled: _remind,
      done: widget.existing?.done ?? false,
      completedAt: widget.existing?.completedAt,
      priority: _priority,
      repeat: _repeat,
      graceMinutes: _graceMinutes,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await context.read<TodoProvider>().save(todo);

    if (_remind) {
      final granted = await NotificationService.instance.ensurePermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知权限未开启，到点不会提醒你')),
        );
      }
    }

    if (!mounted) return;
    if (_remind && _dueAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个时间已经过了，提醒排不上（待办会显示为逾期）')),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final overdue = _dueAt.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑待办' : '新建待办'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        // 顶栏是彩色条，内容顶部留 14 不贴上去
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          TextField(
            controller: _title,
            autofocus: !_isEditing,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '要做什么？'),
          ),
          const SizedBox(height: 20),

          const _FieldLabel('优先级'),
          _Segmented(
            values: const [
              TodoPriority.low,
              TodoPriority.normal,
              TodoPriority.high,
              TodoPriority.urgent,
            ],
            selected: _priority,
            labelOf: (v) => TodoPriority.labels[v] ?? '',
            colorOf: (v) => _priorityColor(p, v),
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '优先级高的会排在待办列表最前面',
              style: AppText.label(context).copyWith(fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 20),

          const _FieldLabel('提醒时间'),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_outlined,
                  text: formatShortDate(_dueAt),
                  sub: weekdayLabel(_dueAt),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule,
                  text: formatClock(_dueAt.hour, _dueAt.minute),
                  sub: overdue ? '已过' : '到点提醒',
                  subColor: overdue ? p.danger : null,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Chip(label: '今天', active: false, onTap: () => _quickDay(0)),
              const SizedBox(width: 8),
              _Chip(label: '明天', active: false, onTap: () => _quickDay(1)),
              const SizedBox(width: 8),
              _Chip(label: '后天', active: false, onTap: () => _quickDay(2)),
              const SizedBox(width: 8),
              _Chip(label: '+7 天', active: false, onTap: () => _quickDay(7)),
            ],
          ),
          const SizedBox(height: 20),

          const _FieldLabel('重复'),
          _Segmented(
            values: TodoRepeat.labels.keys.toList(),
            selected: _repeat,
            labelOf: (v) => TodoRepeat.labels[v] ?? '',
            onChanged: (v) => setState(() => _repeat = v),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _repeat == TodoRepeat.none
                  ? '勾选后就完成了'
                  : '勾选不会消失，而是推到下一个周期（按当前日期的'
                        '${_repeat == TodoRepeat.weekly ? "星期" : _repeat == TodoRepeat.monthly ? "日" : "时间"}算）',
              style: AppText.label(context).copyWith(fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 20),

          const _FieldLabel('多久算逾期'),
          _Segmented(
            values: _graceOptions,
            selected: _graceMinutes,
            labelOf: (v) => v == 0 ? '立刻' : (v >= 60 ? '${v ~/ 60} 小时' : '$v 分钟'),
            onChanged: (v) => setState(() => _graceMinutes = v),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _graceMinutes == 0
                  ? '过了提醒时间就算逾期'
                  : '过了提醒时间再等 $_graceLabel 才标成逾期，之前只算"进行中"',
              style: AppText.label(context).copyWith(fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 20),

          const _FieldLabel('备注'),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(hintText: '可选，比如要带的东西'),
          ),
          const SizedBox(height: 20),

          const _FieldLabel('提醒'),
          // 用 Material 而不是带底色的 Container：否则 ListTile 的按压水波会被盖掉
          // （Flutter 会为此发断言，release 下断言没了、表现就是"按下去没反应"）。
          Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.line),
            ),
            child: SwitchListTile(
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
              title: const Text(
                '到点弹通知提醒',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '到设定时间提醒一次，不会重复',
                  style: AppText.label(context).copyWith(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),

          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }

  String get _graceLabel => _graceMinutes >= 60
      ? '${_graceMinutes ~/ 60} 小时'
      : '$_graceMinutes 分钟';

  static Color _priorityColor(AppPalette p, int priority) => switch (priority) {
    TodoPriority.urgent => p.danger,
    TodoPriority.high => p.warn,
    TodoPriority.low => p.inkFaint,
    _ => p.jade,
  };
}

// ---------------------------------------------------------------- 零件

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: AppText.sectionTitle(context)),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.colorOf,
  });

  final List<int> values;
  final int selected;
  final String Function(int) labelOf;
  final ValueChanged<int> onChanged;
  final Color Function(int)? colorOf;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == v
                        ? (colorOf?.call(v) ?? p.jade)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labelOf(v),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: selected == v
                          ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                          : p.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? p.jade : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? p.jade : p.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active
                ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                : p.jade,
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.text,
    required this.sub,
    required this.onTap,
    this.subColor,
  });

  final IconData icon;
  final String text;
  final String sub;
  final VoidCallback onTap;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: p.inkSoft),
              const SizedBox(height: 7),
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: AppText.label(
                  context,
                ).copyWith(fontSize: 11.5, color: subColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
