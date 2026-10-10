import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/check_burst.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';
import '../widgets/reminder_status_banner.dart';
import 'add_todo_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  bool _showCompleted = false;

  Future<void> _openEditor([TodoItem? existing]) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AddTodoScreen(existing: existing)),
  );

  /// 勾选 / 取消勾选。
  ///
  /// 勾掉的那一项会立刻从列表里消失，所以庆祝动画走 Overlay 放，
  /// 并且**在 await 之前就插进去** —— 等 provider 跑完再插就来不及了。
  Future<void> _toggle(TodoItem todo, Offset position) async {
    final provider = context.read<TodoProvider>();
    final wasDone = todo.done;

    if (wasDone) {
      Haptics.tap();
    } else {
      Haptics.impact();
      CheckBurst.show(context, position);
    }

    await provider.toggleDone(todo);
    if (!mounted) return;

    if (wasDone) {
      AppToast.show(
        context,
        '已恢复 · ${todo.title}',
        icon: Icons.undo_rounded,
        tint: context.palette.inkSoft,
      );
      return;
    }
    // 重复任务不是"完成"，而是推到了下一个周期
    if (todo.isRepeating) {
      final updated = provider.items.firstWhere(
        (t) => t.id == todo.id,
        orElse: () => todo,
      );
      AppToast.show(
        context,
        '已完成 · 下一次 ${formatDueAt(updated.dueAt)}',
        icon: Icons.repeat_rounded,
      );
      return;
    }
    final left = provider.pending.length;
    AppToast.show(
      context,
      left == 0 ? '全部待办都清完了' : '完成 · 还剩 $left 项',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  Future<void> _confirmDelete(TodoItem todo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条待办？'),
        content: Text('「${todo.title}」删除后，它的提醒也会一并取消。'),
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
    if (ok == true && mounted) {
      await context.read<TodoProvider>().remove(todo.id!);
    }
  }

  Future<void> _clearCompleted(List<TodoItem> completed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('清空 ${completed.length} 条已完成？'),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ctx.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<TodoProvider>();
    for (final todo in completed) {
      await provider.remove(todo.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final groups = provider.grouped;
    final completed = provider.completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
        actions: [
          if (provider.pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${provider.pending.length} 项待完成',
                  style: AppText.label(context),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Pressable(
        scale: 0.94,
        child: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('添加待办'),
        ),
      ),
      body: !provider.ready
          ? const SizedBox.shrink()
          : groups.isEmpty && completed.isEmpty
          ? const EmptyState(
              icon: Icons.checklist_rtl,
              title: '还没有待办',
              hint: '加一条，到点会提醒你。\n提醒要在系统里把权限开全才会稳。',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
              children: [
                const ReminderStatusBanner(),
                // 全部处理完的那一下，给个明确的"收工"信号
                if (groups.isEmpty && completed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: context.palette.jade,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '待办都清完了',
                          style: AppText.sectionTitle(context),
                        ),
                      ],
                    ),
                  ),
                for (final group in groups) ...[
                  _GroupHeader(
                    label: group.label,
                    count: group.items.length,
                    urgent: group.urgent,
                  ),
                  for (final todo in group.items)
                    _TodoTile(
                      todo: todo,
                      onTap: () => _openEditor(todo),
                      onToggle: (position) => _toggle(todo, position),
                      onLongPress: () => _confirmDelete(todo),
                    ),
                ],
                if (completed.isNotEmpty) ...[
                  InkWell(
                    onTap: () =>
                        setState(() => _showCompleted = !_showCompleted),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                      child: Row(
                        children: [
                          Text(
                            '已完成 · ${completed.length}',
                            style: AppText.sectionTitle(context),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showCompleted
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: context.palette.inkSoft,
                          ),
                          const Spacer(),
                          if (_showCompleted)
                            TextButton(
                              onPressed: () => _clearCompleted(completed),
                              style: TextButton.styleFrom(
                                foregroundColor: context.palette.inkSoft,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('清空'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_showCompleted)
                    for (final todo in completed)
                      _TodoTile(
                        todo: todo,
                        onTap: () => _openEditor(todo),
                        onToggle: (position) => _toggle(todo, position),
                        onLongPress: () => _confirmDelete(todo),
                      ),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- 零件

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    this.urgent = false,
  });

  final String label;
  final int count;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = urgent ? p.danger : p.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          if (urgent) ...[
            Icon(Icons.error_outline, size: 15, color: p.danger),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppText.label(context).copyWith(fontSize: 12.5),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: p.line, height: 1)),
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.todo,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
  });

  final TodoItem todo;
  final VoidCallback onTap;

  /// 回调带上点击的屏幕坐标，用于在那一处放"打勾爆开"的动画
  final ValueChanged<Offset> onToggle;

  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // 宽限期内不算逾期，用橙色提示"已过点，但还没到期"
    final dueColor = todo.done
        ? p.inkFaint
        : todo.isOverdue
        ? p.danger
        : todo.isWithinGrace
        ? p.warn
        : todo.isDueSoon
        ? p.warn
        : p.inkSoft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧优先级色条
                Container(width: 4, color: _priorityColor(p, todo.priority)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CheckCircle(done: todo.done, onTap: onToggle),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    todo.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: todo.done ? p.inkFaint : p.ink,
                                      decoration: todo.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: p.inkFaint,
                                    ),
                                  ),
                                ),
                                if (_showPriorityTag(todo.priority)) ...[
                                  const SizedBox(width: 6),
                                  _Tag(
                                    text: todo.priorityLabel,
                                    color: _priorityColor(p, todo.priority),
                                  ),
                                ],
                                if (todo.isRepeating) ...[
                                  const SizedBox(width: 6),
                                  _Tag(
                                    text: todo.repeatLabel,
                                    color: p.inkSoft,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 12, color: dueColor),
                                const SizedBox(width: 4),
                                Text(
                                  formatDueAt(todo.dueAt),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: dueColor,
                                  ),
                                ),
                                if (todo.isWithinGrace) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '宽限中',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: p.warn,
                                    ),
                                  ),
                                ],
                                if (todo.remindEnabled) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 12,
                                    color: todo.done ? p.inkFaint : p.jade,
                                  ),
                                ],
                              ],
                            ),
                            if (todo.note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                todo.note,
                                style: AppText.label(
                                  context,
                                ).copyWith(fontSize: 11.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 6),
                        child: Icon(
                          Icons.chevron_right,
                          size: 19,
                          color: p.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 「中」不标，减少视觉噪音；低/高/急才显示
  static bool _showPriorityTag(int priority) => priority != TodoPriority.normal;

  static Color _priorityColor(AppPalette p, int priority) => switch (priority) {
    TodoPriority.urgent => p.danger,
    TodoPriority.high => p.warn,
    TodoPriority.low => p.inkFaint,
    _ => p.jade,
  };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.done, required this.onTap});

  final bool done;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTapUp: (details) => onTap(details.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // 视觉上是个小圆，但可点区域放大到 34 见方，手指够得着
        padding: const EdgeInsets.all(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done ? p.jade : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? p.jade : p.outline,
              width: 1.8,
            ),
          ),
          child: done
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
