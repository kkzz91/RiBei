import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/countdown_event.dart';
import '../providers/countdown_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/digit_fonts.dart';
import '../utils/formatters.dart';
import '../utils/lunar_date.dart';
import '../widgets/digit_font_picker.dart';
import '../widgets/theme_picker.dart';

class AddCountdownScreen extends StatefulWidget {
  const AddCountdownScreen({super.key, this.existing});

  final CountdownEvent? existing;

  @override
  State<AddCountdownScreen> createState() => _AddCountdownScreenState();
}

class _AddCountdownScreenState extends State<AddCountdownScreen> {
  static const _leadOptions = <int>[1, 2, 3, 5, 7, 14, 30];

  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late int _calendar;
  late int _lunarMonth;
  late int _lunarDay;
  late int _repeat;
  late int _leadDays;
  late bool _remind;
  late int _hour;
  late int _minute;

  /// 详情页海报的背景主题（取值见 `MilestoneTheme`，和纪念日共用同一套）
  late int _theme;

  /// 那个超大天数用什么字体（见 `DigitFont`）
  late int _digitFont;

  /// 在「日子」列表里置顶放大（全局最多一个）
  late bool _pinned;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _isLunar => _calendar == CountdownCalendar.lunar;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    final now = DateTime.now();
    _date = e?.targetDate ?? DateTime(now.year, now.month, now.day + 7);
    _calendar = e?.calendar ?? CountdownCalendar.solar;
    _repeat = e?.repeat ?? CountdownRepeat.none;
    _leadDays = e?.leadDays ?? 3;
    _remind = e?.remindEnabled ?? true;
    _hour = e?.remindHour ?? 9;
    _minute = e?.remindMinute ?? 0;
    _theme = e?.theme ?? 0;
    _digitFont = e?.digitFont ?? DigitFont.classic;
    _pinned = e?.pinned ?? false;

    // 农历字段：老数据没有就从当前公历日期反推，给用户一个合理起点
    if (e != null && e.isLunar) {
      _lunarMonth = e.lunarMonth;
      _lunarDay = e.lunarDay;
    } else {
      final (month, day) = LunarDate.fromSolar(_date);
      _lunarMonth = month;
      _lunarDay = day;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 用真实模型算预览，避免这里再写一套日期逻辑
  CountdownEvent get _draft => CountdownEvent(
    id: widget.existing?.id,
    title: _title.text.trim().isEmpty ? '（未命名）' : _title.text.trim(),
    targetDate: _date,
    calendar: _calendar,
    lunarMonth: _lunarMonth,
    lunarDay: _lunarDay,
    repeat: _repeat,
    leadDays: _leadDays,
    remindEnabled: _remind,
    remindHour: _hour,
    remindMinute: _minute,
    theme: _theme,
    digitFont: _digitFont,
    pinned: _pinned,
    createdAt: widget.existing?.createdAt ?? DateTime.now(),
  );

  Future<void> _pickSolarDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(now.year + 50),
      helpText: '选择目标日期',
    );
    if (picked != null) {
      setState(() => _date = picked);
      if (_isLunar) _syncLunarFromSolar(picked);
    }
  }

  /// 公历改了以后，农历字段跟着变（给用户一个合理起点）
  void _syncLunarFromSolar(DateTime solar) {
    final (month, day) = LunarDate.fromSolar(solar);
    _lunarMonth = month;
    _lunarDay = day;
  }

  Future<void> _pickLunarMonth() async {
    final year = LunarDate.lunarYearOf(DateTime.now());
    final months = LunarDate.monthsOf(year);
    final picked = await _pickFromList<int>(
      title: '选择农历月份',
      values: months,
      selected: _lunarMonth,
      labelOf: (m) => '${LunarDate.monthName(m)}月',
    );
    if (picked != null) {
      setState(() {
        _lunarMonth = picked;
        final maxDay = LunarDate.daysInMonth(year, picked);
        if (_lunarDay > maxDay) _lunarDay = maxDay;
      });
    }
  }

  Future<void> _pickLunarDay() async {
    final year = LunarDate.lunarYearOf(DateTime.now());
    final maxDay = LunarDate.daysInMonth(year, _lunarMonth);
    final picked = await _pickFromList<int>(
      title: '选择农历日期',
      values: List<int>.generate(maxDay, (i) => i + 1),
      selected: _lunarDay,
      labelOf: LunarDate.dayName,
    );
    if (picked != null) setState(() => _lunarDay = picked);
  }

  Future<T?> _pickFromList<T>({
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: context.palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: values.length,
                  itemBuilder: (_, i) {
                    final v = values[i];
                    final active = v == selected;
                    return ListTile(
                      dense: true,
                      title: Text(
                        labelOf(v),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active ? p.jade : p.ink,
                        ),
                      ),
                      trailing: active
                          ? Icon(Icons.check, size: 20, color: p.jade)
                          : null,
                      onTap: () => Navigator.pop(ctx, v),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      helpText: '选择每天提醒的时间',
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先给它起个名字')),
      );
      return;
    }

    setState(() => _saving = true);

    final event = CountdownEvent(
      id: widget.existing?.id,
      title: title,
      targetDate: _date,
      note: _note.text.trim(),
      remindEnabled: _remind,
      remindHour: _hour,
      remindMinute: _minute,
      calendar: _calendar,
      lunarMonth: _lunarMonth,
      lunarDay: _lunarDay,
      repeat: _repeat,
      leadDays: _leadDays,
      theme: _theme,
      digitFont: _digitFont,
      pinned: _pinned,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await context.read<CountdownProvider>().save(event);

    if (_remind) {
      final granted = await NotificationService.instance.ensurePermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知权限未开启，倒计时不会提醒你')),
        );
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final draft = _draft;
    final days = draft.daysLeft;
    final color = p.urgencyOf(days);
    final target = draft.effectiveTarget;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑倒计时' : '新建倒计时'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // 实时预览
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                Text(
                  '${days.abs()}',
                  style: AppText.dayHero(context).copyWith(
                    fontSize: 54,
                    color: color,
                    // 预览也跟着选的字体走，所见即所得
                    fontFamily: DigitFont.familyOf(_digitFont),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  days < 0 ? '天前' : (days == 0 ? '就是今天' : '天后'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  formatFullDate(target),
                  style: AppText.label(context),
                ),
                if (_isLunar) ...[
                  const SizedBox(height: 2),
                  Text(
                    '农历 ${LunarDate.monthName(_lunarMonth)}月'
                    '${LunarDate.dayName(_lunarDay)}',
                    style: AppText.label(context).copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          const _FieldLabel('名称'),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '比如：期末考试、生日、还款日',
            ),
          ),
          const SizedBox(height: 18),

          const _FieldLabel('日历'),
          _Segmented(
            values: const [CountdownCalendar.solar, CountdownCalendar.lunar],
            selected: _calendar,
            labelOf: (v) =>
                v == CountdownCalendar.lunar ? '农历' : '公历',
            onChanged: (v) => setState(() => _calendar = v),
          ),
          const SizedBox(height: 12),
          if (_isLunar)
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_month_outlined,
                    text: '${LunarDate.monthName(_lunarMonth)}月',
                    sub: '农历月份',
                    onTap: _pickLunarMonth,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.event_outlined,
                    text: LunarDate.dayName(_lunarDay),
                    sub: '农历日期',
                    onTap: _pickLunarDay,
                  ),
                ),
              ],
            )
          else
            _PickerTile(
              icon: Icons.calendar_today_outlined,
              text: formatFullDate(_date),
              sub: '${weekdayLabel(_date)} · 公历',
              onTap: _pickSolarDate,
            ),
          const SizedBox(height: 18),

          const _FieldLabel('重复'),
          _Segmented(
            values: CountdownRepeat.labels.keys.toList(),
            selected: _repeat,
            labelOf: (v) => CountdownRepeat.labels[v] ?? '',
            onChanged: (v) => setState(() => _repeat = v),
          ),
          if (_repeat != CountdownRepeat.none) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _repeat == CountdownRepeat.monthly
                    ? '每个月的这一天自动轮到下一次，不用手动改日期'
                    : '每年的这一天自动轮到下一次（农历按农历算）',
                style: AppText.label(context).copyWith(fontSize: 11.5),
              ),
            ),
          ],
          const SizedBox(height: 18),

          const _FieldLabel('提醒'),
          Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _remind,
                  onChanged: (v) => setState(() => _remind = v),
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                  title: const Text(
                    '临近时每天提醒',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '从目标日期前 $_leadDays 天开始，每天一次，共 ${_leadDays + 1} 次',
                      style: AppText.label(context).copyWith(fontSize: 12),
                    ),
                  ),
                ),
                if (_remind) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: [
                        Text(
                          '提前几天起',
                          style: TextStyle(fontSize: 13, color: p.inkSoft),
                        ),
                        const Spacer(),
                        Text(
                          '$_leadDays 天',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.jade,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in _leadOptions)
                          _Chip(
                            label: '$d 天',
                            active: _leadDays == d,
                            onTap: () => setState(() => _leadDays = d),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _PickerTile(
                    icon: Icons.alarm_outlined,
                    text: '每天 ${formatClock(_hour, _minute)} 提醒',
                    sub: '手机上按这个时间弹出通知',
                    onTap: _pickTime,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _FieldLabel('背景主题'),
          ThemePicker(value: _theme, onChanged: (v) {
            setState(() => _theme = v);
          }),
          const SizedBox(height: 18),

          const _FieldLabel('数字字体'),
          DigitFontPicker(
            value: _digitFont,
            onChanged: (v) => setState(() => _digitFont = v),
          ),
          const SizedBox(height: 18),

          Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: SwitchListTile(
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
              title: const Text(
                '置顶',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '在「日子」列表里放大显示在最上面（同一时刻只置顶一个）',
                  style: AppText.label(context).copyWith(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          const _FieldLabel('备注'),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(hintText: '可选，比如要准备的资料'),
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
  });

  final List<int> values;
  final int selected;
  final String Function(int) labelOf;
  final ValueChanged<int> onChanged;

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
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == v ? p.jade : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labelOf(v),
                    style: TextStyle(
                      fontSize: 14,
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
                : p.inkSoft,
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
    this.dense = false,
  });

  final IconData icon;
  final String text;
  final String sub;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: dense ? Colors.transparent : p.card,
      borderRadius: BorderRadius.circular(dense ? 0 : 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: dense ? 12 : 14,
          ),
          decoration: dense
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.line),
                ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: p.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: dense ? 14.5 : 15,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(sub, style: AppText.label(context)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: p.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
