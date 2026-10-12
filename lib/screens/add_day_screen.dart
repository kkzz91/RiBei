import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/countdown_event.dart';
import '../models/milestone.dart';
import '../providers/countdown_provider.dart';
import '../providers/milestone_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/digit_fonts.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../utils/lunar_date.dart';
import '../widgets/app_toast.dart';
import '../widgets/digit_font_picker.dart';
import '../widgets/theme_picker.dart';

/// 新建 / 编辑一个"日子"。
///
/// **用户要求（v1.6.12）：不要再在新建时分「倒计时 / 纪念日」** ——
/// 填名字 → 选公历/农历 → 选日期，**系统按日期自动决定**：
///   · 选的日子**已经过去** ⇒ 存成**纪念日**（正计时，"已经 N 天"）
///   · 选的是**今天或以后** ⇒ 存成**倒计时**（"还有 N 天"，带提醒）
///   · 选**农历** ⇒ 一定是倒计时（农历每年轮转，由 `LunarDate.nextOccurrence` 算下一次）
///
/// 库里仍然是两张表（字段差别太大），这里负责"按日期选表"。
/// ⚠️ **编辑时如果日期跨过了今天，类型会切换** —— 那就必须"删旧行 + 插新行"，
/// 所以 **id 会变**。界面上有一条提示，别让用户以为是 bug。
class AddDayScreen extends StatefulWidget {
  const AddDayScreen({super.key, this.milestone, this.countdown});

  /// 编辑纪念日时传这个
  final Milestone? milestone;

  /// 编辑倒计时时传这个
  final CountdownEvent? countdown;

  @override
  State<AddDayScreen> createState() => _AddDayScreenState();
}

class _AddDayScreenState extends State<AddDayScreen> {
  static const _leadOptions = <int>[1, 2, 3, 5, 7, 14, 30];

  late final TextEditingController _title;
  late final TextEditingController _note;

  /// 公历锚点日期（农历事件也存一个，用于展示与排序）
  late DateTime _date;
  late int _calendar; // CountdownCalendar.solar / lunar
  late int _lunarMonth;
  late int _lunarDay;
  late int _repeat;
  late int _leadDays;
  late bool _remind;
  late int _hour;
  late int _minute;
  late int _theme;
  late int _digitFont;
  late bool _pinned;
  bool _saving = false;

  bool get _isEditing =>
      widget.milestone != null || widget.countdown != null;
  bool get _isLunar => _calendar == CountdownCalendar.lunar;

  /// 选的日子是不是"已经过去了" —— **这一条决定它存成纪念日还是倒计时**
  bool get _willBeMilestone {
    if (_isLunar) return false; // 农历一定按"下一次"算，属于未来
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
    ).isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    final m = widget.milestone;
    final c = widget.countdown;
    _title = TextEditingController(text: m?.title ?? c?.title ?? '');
    _note = TextEditingController(text: m?.note ?? c?.note ?? '');
    final now = DateTime.now();
    _date = m?.startDate ?? c?.targetDate ?? DateTime(now.year, now.month, now.day + 7);
    _calendar = c?.calendar ?? CountdownCalendar.solar;
    _repeat = c?.repeat ?? CountdownRepeat.none;
    _leadDays = c?.leadDays ?? 3;
    _remind = c?.remindEnabled ?? true;
    _hour = c?.remindHour ?? 9;
    _minute = c?.remindMinute ?? 0;
    _theme = m?.theme ?? c?.theme ?? 0;
    _digitFont = m?.digitFont ?? c?.digitFont ?? DigitFont.classic;
    _pinned = m?.pinned ?? c?.pinned ?? false;

    if (c != null && c.isLunar) {
      _lunarMonth = c.lunarMonth;
      _lunarDay = c.lunarDay;
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

  // ---------------------------------------------------------------- 选择

  Future<void> _pickSolarDate() async {
    // 允许选过去的日子 —— 那才会存成"纪念日"
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(DateTime.now().year + 50),
      helpText: '选择这一天',
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      if (_isLunar) _syncLunarFromSolar(picked);
    });
  }

  void _syncLunarFromSolar(DateTime solar) {
    final (month, day) = LunarDate.fromSolar(solar);
    _lunarMonth = month;
    _lunarDay = day;
  }

  Future<void> _pickLunarMonth() async {
    final year = LunarDate.lunarYearOf(DateTime.now());
    final picked = await _pickFromList<int>(
      title: '选择农历月份',
      values: LunarDate.monthsOf(year),
      selected: _lunarMonth,
      labelOf: (v) => '${LunarDate.monthName(v)}月',
    );
    if (picked == null) return;
    setState(() {
      _lunarMonth = picked;
      final maxDay = LunarDate.daysInMonth(year, picked);
      if (_lunarDay > maxDay) _lunarDay = maxDay;
    });
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      helpText: '选择每天提醒的时间',
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
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

  // ---------------------------------------------------------------- 保存

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      AppToast.show(
        context,
        '先给它起个名字',
        icon: Icons.error_outline,
        tint: context.palette.warn,
      );
      return;
    }
    Haptics.impact();
    setState(() => _saving = true);

    final countdowns = context.read<CountdownProvider>();
    final milestones = context.read<MilestoneProvider>();

    // 置顶是"全局最多一个"（列表里只有头条卡那一张会放大）——
    // 这里开了置顶，就先把别的都取消掉，**和长按菜单那条路径守同一条规矩**。
    // 之前只有长按菜单做了互斥、这个开关没做，于是"长按置顶会顶掉上一个、
    // 但在编辑页却能同时置顶好几个"，用户发现两处行为对不上。
    if (_pinned) {
      await countdowns.unpinAll();
      await milestones.unpinAll();
    }

    final now = DateTime.now();
    final asMilestone = _willBeMilestone;

    // 日期跨过了今天 ⇒ 类型变了，而两张表字段不同 ⇒ 只能"删旧的 + 插新的"（id 会变）
    final wasMilestone = widget.milestone != null;
    final switched = _isEditing && asMilestone != wasMilestone;

    if (asMilestone) {
      await milestones.save(
        Milestone(
          id: switched ? null : widget.milestone?.id,
          title: title,
          startDate: _date,
          note: _note.text.trim(),
          theme: _theme,
          pinned: _pinned,
          digitFont: _digitFont,
          createdAt: widget.milestone?.createdAt ?? now,
        ),
      );
      if (switched) await countdowns.remove(widget.countdown!.id!);
    } else {
      final target = _isLunar
          ? LunarDate.nextOccurrence(
              lunarMonth: _lunarMonth,
              lunarDay: _lunarDay,
            )
          : _date;
      await countdowns.save(
        CountdownEvent(
          id: switched ? null : widget.countdown?.id,
          title: title,
          targetDate: target,
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
          pinned: _pinned,
          digitFont: _digitFont,
          createdAt: widget.countdown?.createdAt ?? now,
        ),
      );
      if (switched) await milestones.remove(widget.milestone!.id!);

      if (_remind) {
        final granted = await NotificationService.instance.ensurePermissions();
        if (!granted && mounted) {
          AppToast.show(
            context,
            '通知权限没开，它不会提醒你',
            icon: Icons.notifications_off_outlined,
            tint: context.palette.warn,
          );
        }
      }
    }

    if (!mounted) return;
    AppToast.show(context, _isEditing ? '已更新' : '已记下这一天');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这一天？'),
        content: const Text('删掉后就没有了。'),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ctx.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (widget.milestone != null) {
      await context.read<MilestoneProvider>().remove(widget.milestone!.id!);
    } else if (widget.countdown != null) {
      await context.read<CountdownProvider>().remove(widget.countdown!.id!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final asMilestone = _willBeMilestone;
    final editingTypeChanged =
        _isEditing && asMilestone != (widget.milestone != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑这一天' : '添加日子'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        // 顶栏是彩色条，内容顶部留 14 不贴上去
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // ① 名字
          const _Label('名字'),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '比如：期末考试、在一起、发工资',
            ),
          ),
          const SizedBox(height: 18),

          // ② 公历 / 农历
          const _Label('日历'),
          _Segmented(
            values: const [
              CountdownCalendar.solar,
              CountdownCalendar.lunar,
            ],
            selected: _calendar,
            labelOf: (v) => v == CountdownCalendar.lunar ? '农历' : '公历',
            onChanged: (v) => setState(() => _calendar = v),
          ),
          const SizedBox(height: 12),

          // ③ 选日期
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
              sub: '${weekdayLabel(_date)} · 点一下改日期',
              onTap: _pickSolarDate,
            ),
          const SizedBox(height: 10),

          // ④ 自动判定结果：让用户明白它会存成哪一种
          _VerdictBanner(
            asMilestone: asMilestone,
            typeChanged: editingTypeChanged,
          ),
          const SizedBox(height: 18),

          // ⑤ 只有"未来的日子"才需要提醒 / 重复
          if (!asMilestone) ...[
            const _Label('重复'),
            _Segmented(
              values: CountdownRepeat.labels.keys.toList(),
              selected: _repeat,
              labelOf: (v) => CountdownRepeat.labels[v] ?? '',
              onChanged: (v) => setState(() => _repeat = v),
            ),
            const SizedBox(height: 18),
            const _Label('提醒'),
            // 用 Material 而不是 Container：ListTile 的按压水波是画在**最近的 Material** 上的，
            // 中间夹一层"带底色的 Container"会把水波盖掉（Flutter 会为此发断言，
            // release 下断言被关掉、表现就成了"这一行按下去没任何反应"）。
            Material(
              color: p.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.line),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _remind,
                    onChanged: (v) => setState(() => _remind = v),
                    contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                    title: const Text(
                      '临近时每天提醒',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '从这天前 $_leadDays 天开始，每天一次，共 ${_leadDays + 1} 次',
                        style: AppText.label(context).copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                  if (_remind) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                      sub: '手机上按这个时间弹通知',
                      onTap: _pickTime,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ⑥ 外观：主题 + 数字字体 + 置顶
          const _Label('背景主题'),
          ThemePicker(
            value: _theme,
            onChanged: (v) {
              Haptics.tap();
              setState(() => _theme = v);
            },
          ),
          const SizedBox(height: 18),
          const _Label('数字字体'),
          DigitFontPicker(
            value: _digitFont,
            onChanged: (v) => setState(() => _digitFont = v),
          ),
          const SizedBox(height: 18),
          // 同上：必须是 Material，不能是带底色的 Container（否则按压水波不可见）
          Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.line),
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
                  '在列表里放大显示在最上面（同一时刻只置顶一个）',
                  style: AppText.label(context).copyWith(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ⑦ 备注
          const _Label('备注'),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(hintText: '可选'),
          ),
          const SizedBox(height: 26),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 零件

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: AppText.sectionTitle(context)),
    );
  }
}

/// "它会被存成哪一种" —— 用户要求系统按日期自动决定，那就得让他看得见结果。
class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.asMilestone, required this.typeChanged});

  final bool asMilestone;
  final bool typeChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = asMilestone ? const Color(0xFFE08A1E) : const Color(0xFF2E7DD1);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: p.isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                asMilestone ? Icons.history : Icons.hourglass_bottom,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  asMilestone
                      ? '这一天已经过去了 ⇒ 存成「纪念日」，帮你正计时'
                      : '这一天还没到 ⇒ 存成「倒计时」，临近时提醒你',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (typeChanged) ...[
            const SizedBox(height: 6),
            Text(
              '⚠️ 日期跨过了今天，保存后它会换成另一种（数据不会丢，但列表里的位置会变）',
              style: TextStyle(fontSize: 11.5, color: p.inkSoft),
            ),
          ],
        ],
      ),
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
                onTap: () {
                  Haptics.tap();
                  onChanged(v);
                },
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
