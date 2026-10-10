import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/milestone.dart';
import '../providers/milestone_provider.dart';
import '../theme/app_theme.dart';
import '../theme/milestone_themes.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/pressable.dart';

/// 新建 / 编辑一个纪念日。
class EditMilestoneScreen extends StatefulWidget {
  const EditMilestoneScreen({super.key, this.existing});

  final Milestone? existing;

  @override
  State<EditMilestoneScreen> createState() => _EditMilestoneScreenState();
}

class _EditMilestoneScreenState extends State<EditMilestoneScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _start;
  late int _theme;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _start = e?.startDate ?? DateTime.now();
    _theme = e?.theme ?? MilestoneTheme.blackGold;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: '选择起始日期',
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      AppToast.show(
        context,
        '给这个纪念日起个名字',
        icon: Icons.error_outline,
        tint: context.palette.warn,
      );
      return;
    }
    Haptics.impact();
    setState(() => _saving = true);

    final milestone = Milestone(
      id: widget.existing?.id,
      title: title,
      startDate: _start,
      note: _note.text.trim(),
      theme: _theme,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    await context.read<MilestoneProvider>().save(milestone);
    if (!mounted) return;
    AppToast.show(context, _isEditing ? '已更新' : '已记下这个纪念日');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个纪念日？'),
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
    await context.read<MilestoneProvider>().remove(widget.existing!.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑纪念日' : '新建纪念日'),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            controller: _title,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '名字，比如「在一起」「入职」「搬进新家」',
              prefixIcon: Icon(Icons.favorite_outline, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '备注（可选）',
              prefixIcon: Icon(Icons.edit_note, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: p.inkSoft),
                  const SizedBox(width: 10),
                  Text(
                    '起始于 ${formatFullDate(_start)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: p.inkFaint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('背景主题', style: AppText.sectionTitle(context)),
          const SizedBox(height: 10),
          _ThemePicker(value: _theme, onChanged: (v) {
            Haptics.tap();
            setState(() => _theme = v);
          }),
          const SizedBox(height: 26),
          Pressable(
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5 套主题的色块选择器：每个格子直接就是那套主题的渐变，所见即所得
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: milestoneThemeStyles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, i) {
        final style = milestoneThemeStyles[i];
        final selected = i == value;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: style.gradient,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? p.jade : Colors.transparent,
                width: 2.4,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    style.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: style.text,
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: style.accent,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
