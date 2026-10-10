import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/todo_dao.dart';
import '../models/todo_item.dart';
import '../services/notification_service.dart';

/// 列表分组：逾期 / 今天 / 明天 / 本周内 / 更晚
class TodoGroup {
  const TodoGroup({
    required this.label,
    required this.items,
    this.urgent = false,
  });

  final String label;
  final List<TodoItem> items;

  /// 逾期组，界面上标红
  final bool urgent;
}

class TodoProvider extends ChangeNotifier {
  TodoProvider({TodoDao? dao}) : _dao = dao ?? const TodoDao();

  final TodoDao _dao;

  List<TodoItem> _items = const <TodoItem>[];
  bool _ready = false;
  String? _loadError;

  List<TodoItem> get items => _items;
  bool get ready => _ready;

  /// 上次读取失败的原因；正常时是 null。理由同 LedgerProvider.loadError
  String? get loadError => _loadError;

  /// 未完成：**优先级高的在前**，同优先级按到期时间由近及远
  List<TodoItem> get pending {
    final list = _items.where((t) => !t.done).toList();
    list.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return a.dueAt.compareTo(b.dueAt);
    });
    return list;
  }

  /// 已完成：按完成时间倒序
  List<TodoItem> get completed {
    final list = _items.where((t) => t.done).toList();
    list.sort((a, b) {
      final at = a.completedAt ?? a.dueAt;
      final bt = b.completedAt ?? b.dueAt;
      return bt.compareTo(at);
    });
    return list;
  }

  List<TodoGroup> get grouped {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = <TodoItem>[];
    final dueToday = <TodoItem>[];
    final tomorrow = <TodoItem>[];
    final thisWeek = <TodoItem>[];
    final later = <TodoItem>[];

    for (final todo in pending) {
      if (todo.isOverdue) {
        overdue.add(todo);
        continue;
      }
      final day = DateTime(todo.dueAt.year, todo.dueAt.month, todo.dueAt.day);
      final diff = day.difference(today).inDays;
      if (diff <= 0) {
        dueToday.add(todo);
      } else if (diff == 1) {
        tomorrow.add(todo);
      } else if (diff <= 7) {
        thisWeek.add(todo);
      } else {
        later.add(todo);
      }
    }

    return <TodoGroup>[
      if (overdue.isNotEmpty)
        TodoGroup(label: '已逾期', items: overdue, urgent: true),
      if (dueToday.isNotEmpty)
        TodoGroup(label: '今天', items: dueToday),
      if (tomorrow.isNotEmpty)
        TodoGroup(label: '明天', items: tomorrow),
      if (thisWeek.isNotEmpty)
        TodoGroup(label: '本周内', items: thisWeek),
      if (later.isNotEmpty) TodoGroup(label: '更晚', items: later),
    ];
  }

  int get overdueCount => _items.where((t) => t.isOverdue).length;

  int get todayCount {
    final now = DateTime.now();
    return _items
        .where(
          (t) =>
              !t.done &&
              t.dueAt.year == now.year &&
              t.dueAt.month == now.month &&
              t.dueAt.day == now.day,
        )
        .length;
  }

  /// 处在宽限期内（已过点但还没算逾期）
  int get withinGraceCount => _items.where((t) => t.isWithinGrace).length;

  Future<void> load() async {
    try {
      _items = await _dao.all();
      _loadError = null;
    } catch (error) {
      _loadError = '$error';
      AppDatabase.instance.note('待办读取失败：$error');
    }
    _ready = true;
    notifyListeners();
  }

  /// 重复任务到期后自动滚到下一个周期。
  ///
  /// 启动时跑一次：「每周一交作业」如果一直没打开 App，
  /// 回来时不该显示成逾期几十天，而应该直接是下一个周一。
  Future<void> rollForwardRepeating() async {
    final now = DateTime.now();
    var changed = false;
    for (final todo in _items) {
      if (todo.done || !todo.isRepeating) continue;
      if (!now.isAfter(todo.overdueAt)) continue;
      final next = todo.nextDueAfter(now);
      if (next == todo.dueAt) continue;
      await _dao.update(todo.copyWith(dueAt: next));
      changed = true;
    }
    if (changed) await load();
  }

  Future<void> save(TodoItem todo) async {
    var saved = todo;
    if (todo.id == null) {
      final id = await _dao.insert(todo);
      saved = todo.copyWith(id: id);
    } else {
      await _dao.update(todo);
    }
    await load();
    await NotificationService.instance.scheduleTodo(saved);
  }

  /// 勾选。
  ///
  /// 重复任务不是"完成"，而是把到期时间推到下一个周期 ——
  /// 否则「每周一交作业」点一次就从此消失了。
  Future<void> toggleDone(TodoItem todo) async {
    TodoItem updated;
    if (todo.isRepeating && !todo.done) {
      updated = todo.copyWith(
        dueAt: todo.nextDueAfter(DateTime.now()),
        clearCompletedAt: true,
      );
    } else {
      final nowDone = !todo.done;
      updated = todo.copyWith(
        done: nowDone,
        completedAt: nowDone ? DateTime.now() : null,
        clearCompletedAt: !nowDone,
      );
    }
    await _dao.update(updated);
    await load();
    await NotificationService.instance.scheduleTodo(updated);
  }

  Future<void> remove(int id) async {
    await _dao.delete(id);
    await NotificationService.instance.cancelTodo(id);
    await load();
  }

  /// 清空全部待办，返回删掉的条数。
  ///
  /// 和倒计时同理：逐条取消自己的提醒，不做全量取消。
  Future<int> clearAll() async {
    for (final todo in _items) {
      final id = todo.id;
      if (id != null) {
        await NotificationService.instance.cancelTodo(id);
      }
    }
    final deleted = await _dao.deleteAll();
    await load();
    return deleted;
  }
}
