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

  /// 重复方式（记事本里点一行 → 底部弹一个列表）
  Future<void> _pickRepeat() async {
    final picked = await _pickFromList<int>(
      title: '重复',
      values: CountdownRepeat.labels.keys.toList(),
      selected: _repeat,
      labelOf: (v) => CountdownRepeat.labels[v] ?? '',
    );
    if (picked != null) setState(() => _repeat = picked);
  }

  /// 提前几天开始提醒
  Future<void> _pickLeadDays() async {
    final picked = await _pickFromList<int>(
      title: '提前几天开始提醒',
      values: _leadOptions,
      selected: _leadDays,
      labelOf: (v) => '$v 天',
    );
    if (picked != null) setState(() => _leadDays = picked);
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
          // 用户要求（v1.6.15）：**不要一个一个独立的小方框**，要像记事本那样
          // 一行一行、一行一个字段 —— 整页就是一张"纸"，行间走一条细线。
          _NoteGroup(
            children: [
              // ① 第一行：小公文包 + 直接写名字
              _NoteRow(
                icon: Icons.work_outline,
                child: TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '名字，比如：期末考试',
                    // 这一页的输入框都融进"纸"里，不要自己那一圈边框
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              // ② 公历 / 农历
              _NoteRow(
                icon: Icons.public_outlined,
                label: '日历',
                trailing: SizedBox(
                  width: 128,
                  child: _Segmented(
                    values: const [
                      CountdownCalendar.solar,
                      CountdownCalendar.lunar,
                    ],
                    selected: _calendar,
                    labelOf: (v) => v == CountdownCalendar.lunar ? '农历' : '公历',
                    onChanged: (v) => setState(() => _calendar = v),
                  ),
                ),
              ),
              // ③ 日期
              if (_isLunar) ...[
                _NoteRow(
                  icon: Icons.calendar_month_outlined,
                  label: '农历月份',
                  value: '${LunarDate.monthName(_lunarMonth)}月',
                  onTap: _pickLunarMonth,
                ),
                _NoteRow(
                  icon: Icons.event_outlined,
                  label: '农历日期',
                  value: LunarDate.dayName(_lunarDay),
                  onTap: _pickLunarDay,
                ),
              ] else
                _NoteRow(
                  icon: Icons.calendar_today_outlined,
                  label: '日期',
                  value: '${formatFullDate(_date)} · ${weekdayLabel(_date)}',
                  onTap: _pickSolarDate,
                ),
              // ④ 只有"未来的日子"才需要重复 / 提醒
              if (!asMilestone) ...[
                _NoteRow(
                  icon: Icons.repeat_outlined,
                  label: '重复',
                  value: CountdownRepeat.labels[_repeat] ?? '',
                  onTap: _pickRepeat,
                ),
                _NoteRow(
                  icon: Icons.notifications_none_outlined,
                  label: '提醒',
                  trailing: Switch(
                    value: _remind,
                    onChanged: (v) => setState(() => _remind = v),
                  ),
                ),
                if (_remind) ...[
                  _NoteRow(
                    icon: Icons.hourglass_empty_outlined,
                    label: '提前',
                    value: '$_leadDays 天',
                    onTap: _pickLeadDays,
                  ),
                  _NoteRow(
                    icon: Icons.alarm_outlined,
                    label: '提醒时间',
                    value: formatClock(_hour, _minute),
                    onTap: _pickTime,
                  ),
                ],
              ],
              // ⑤ 外观：主题 / 数字字体 / 置顶
              // 主题选择器自带"收起 → 点开 → 选完收回"，正好就是本子上的一行
              ThemePicker(
                value: _theme,
                flat: true,
                onChanged: (v) {
                  Haptics.tap();
                  setState(() => _theme = v);
                },
              ),
              _NoteExpandRow(
                icon: Icons.text_fields_outlined,
                label: '数字字体',
                value: DigitFont.labels[_digitFont] ?? '',
                child: DigitFontPicker(
                  value: _digitFont,
                  onChanged: (v) => setState(() => _digitFont = v),
                ),
              ),
              _NoteRow(
                icon: Icons.push_pin_outlined,
                label: '置顶',
                trailing: Switch(
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                ),
              ),
              // ⑥ 备注
              _NoteRow(
                icon: Icons.edit_note_outlined,
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: '备注（可选）',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ⑦ 自动判定结果：让用户明白它会存成哪一种
          _VerdictBanner(
            asMilestone: asMilestone,
            typeChanged: editingTypeChanged,
          ),
          const SizedBox(height: 22),

          // ⑧ 保存 —— 单独一个方框（用户："最后一个独立的方框显示保存"）
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

/// 一页"纸"：把若干 [_NoteRow] 装在一个白底框里，行与行之间走一条细线。
///
/// 用户 v1.6.15："不要一个一个独立的小方框，要像记事本那种列表，一行一行"。
/// ⚠️ 必须是 `Material` 不是 `Container` —— 里面的行用 `InkWell`，
/// 水波画在**最近的 Material** 上，中间夹一层带底色的 `Container` 会把水波盖掉
/// （和 v1.6.13 修 `SwitchListTile` 是同一个坑）。
class _NoteGroup extends StatelessWidget {
  const _NoteGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: p.line,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 记事本上的一行：**左边一个图标**，然后是字段名，右边是当前值 / 控件。
///
/// 两种用法：
///  * 给 [child]（名字、备注这种要放输入框的）—— 图标右边整片交给它；
///  * 给 [value] / [trailing] / [onTap]（日期、重复、提醒这种）—— 右边显示值、
///    放个开关，或者给个箭头表示"点一下能改"。
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.icon,
    this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.child,
  });

  final IconData icon;
  final String? label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 19, color: p.inkSoft),
            const SizedBox(width: 12),
            if (child != null)
              Expanded(child: child!)
            else ...[
              Text(
                label ?? '',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              // 值要吃掉**剩下的全部宽度**（不给 Spacer 跟它抢，否则像
              // "2026年10月20日 · 周一" 这种长值会被挤成省略号）
              if (value != null)
                Expanded(
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.inkSoft),
                  ),
                )
              else
                const Spacer(),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 20, color: p.inkFaint),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 点一下**就地展开**的一行（数字字体这种需要一排选择的）。
/// 主题选择器自己有收起/展开，没走这个。
class _NoteExpandRow extends StatefulWidget {
  const _NoteExpandRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.child,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget child;

  @override
  State<_NoteExpandRow> createState() => _NoteExpandRowState();
}

class _NoteExpandRowState extends State<_NoteExpandRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NoteRow(
          icon: widget.icon,
          label: widget.label,
          value: widget.value,
          onTap: () => setState(() => _open = !_open),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
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
    // 倒计时用玉青、纪念日用橙 —— 和倒计时列表徽标（`days_screen` 的 `_badgeColor`）
    // 同一套语义色。用户 v1.6.15："不要蓝的，橙的留着"。
    final color = asMilestone ? const Color(0xFFE08A1E) : p.jade;
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.isDark ? p.jadeSoft : p.paper,
        borderRadius: BorderRadius.circular(11),
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
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == v ? p.jade : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labelOf(v),
                    style: TextStyle(
                      fontSize: 13,
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

