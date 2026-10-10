/// 待办优先级
class TodoPriority {
  const TodoPriority._();

  static const low = 0;
  static const normal = 1;
  static const high = 2;
  static const urgent = 3;

  static const labels = <int, String>{
    low: '低',
    normal: '中',
    high: '高',
    urgent: '急',
  };

  /// 数值越大越优先，排序时降序
  static const all = <int>[urgent, high, normal, low];
}

/// 待办重复周期
class TodoRepeat {
  const TodoRepeat._();

  static const none = 0;
  static const daily = 1;
  static const weekly = 2;
  static const monthly = 3;

  static const labels = <int, String>{
    none: '不重复',
    daily: '每天',
    weekly: '每周',
    monthly: '每月',
  };
}

/// 一条待办事项
class TodoItem {
  const TodoItem({
    this.id,
    required this.title,
    this.note = '',
    required this.dueAt,
    this.remindEnabled = true,
    this.done = false,
    this.completedAt,
    this.priority = TodoPriority.normal,
    this.repeat = TodoRepeat.none,
    this.graceMinutes = 0,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String note;

  /// 到点提醒的时刻（精确到分钟）
  final DateTime dueAt;

  final bool remindEnabled;
  final bool done;
  final DateTime? completedAt;

  /// [TodoPriority]
  final int priority;

  /// [TodoRepeat]
  final int repeat;

  /// 逾期宽限：超过 dueAt 这么多分钟才算逾期。
  ///
  /// 不留宽限的话，设 10:00 的待办在 10:01 就标红"逾期"，很烦人。
  final int graceMinutes;

  final DateTime createdAt;

  bool get isRepeating => repeat != TodoRepeat.none;

  /// 真正算逾期的时刻 = 到期时间 + 宽限
  DateTime get overdueAt =>
      dueAt.add(Duration(minutes: graceMinutes < 0 ? 0 : graceMinutes));

  /// 已过「宽限期」才算逾期
  bool get isOverdue => !done && DateTime.now().isAfter(overdueAt);

  /// 24 小时内到期，且**还没过点**。
  ///
  /// 已过点但还在宽限期内的不算"即将到期"——它已经到期了，
  /// 只是还没判成逾期（界面上用"宽限中"单独提示）。
  bool get isDueSoon {
    if (done || isOverdue) return false;
    final diff = dueAt.difference(DateTime.now());
    return !diff.isNegative && diff.inHours < 24;
  }

  /// 还在宽限期内（已过 dueAt 但还没算逾期）
  bool get isWithinGrace =>
      !done && DateTime.now().isAfter(dueAt) && !isOverdue;

  String get priorityLabel => TodoPriority.labels[priority] ?? '中';
  String get repeatLabel => TodoRepeat.labels[repeat] ?? '不重复';

  /// 从**原到期时间**起按周期后推，直到晚于 [from]。
  ///
  /// 不能从 from 直接加周期：「每周一交作业」如果周四才完成，
  /// 那样会算成"下周四"，而正确结果是"下周一"。
  DateTime nextDueAfter(DateTime from) {
    if (!isRepeating) return dueAt;
    var candidate = dueAt;
    var guard = 0;
    while (!candidate.isAfter(from) && guard < 400) {
      candidate = _advance(candidate);
      guard++;
    }
    return candidate;
  }

  DateTime _advance(DateTime base) {
    switch (repeat) {
      case TodoRepeat.daily:
        return base.add(const Duration(days: 1));
      case TodoRepeat.weekly:
        return base.add(const Duration(days: 7));
      case TodoRepeat.monthly:
        final next = DateTime(base.year, base.month + 1);
        final last = DateTime(next.year, next.month + 1, 0).day;
        final day = base.day > last ? last : base.day;
        return DateTime(next.year, next.month, day, base.hour, base.minute);
      default:
        return base;
    }
  }

  TodoItem copyWith({
    int? id,
    String? title,
    String? note,
    DateTime? dueAt,
    bool? remindEnabled,
    bool? done,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? priority,
    int? repeat,
    int? graceMinutes,
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      done: done ?? this.done,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      priority: priority ?? this.priority,
      repeat: repeat ?? this.repeat,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'title': title,
    'note': note,
    'due_at': dueAt.millisecondsSinceEpoch,
    'remind_enabled': remindEnabled ? 1 : 0,
    'done': done ? 1 : 0,
    'completed_at': completedAt?.millisecondsSinceEpoch,
    'priority': priority,
    'repeat_rule': repeat,
    'grace_minutes': graceMinutes,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static TodoItem fromMap(Map<String, Object?> m) => TodoItem(
    id: m['id'] as int?,
    title: m['title'] as String,
    note: (m['note'] as String?) ?? '',
    dueAt: DateTime.fromMillisecondsSinceEpoch(m['due_at'] as int),
    remindEnabled: (m['remind_enabled'] as int? ?? 1) == 1,
    done: (m['done'] as int? ?? 0) == 1,
    completedAt: m['completed_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['completed_at'] as int),
    priority: m['priority'] as int? ?? TodoPriority.normal,
    repeat: m['repeat_rule'] as int? ?? TodoRepeat.none,
    graceMinutes: m['grace_minutes'] as int? ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );
}
