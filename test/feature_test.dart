import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/todo_item.dart';
import 'package:ribei/utils/lunar_date.dart';

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

void main() {
  group('农历换算', () {
    test('公历 → 农历 → 公历 往返一致', () {
      for (final solar in <DateTime>[
        DateTime(2026, 2, 17),
        DateTime(2026, 6, 1),
        DateTime(2027, 1, 20),
        DateTime(2025, 12, 31),
      ]) {
        final lunarYear = LunarDate.lunarYearOf(solar);
        final (month, day) = LunarDate.fromSolar(solar);
        expect(
          LunarDate.toSolar(lunarYear, month, day),
          _dayOnly(solar),
          reason: '$solar 往返后应回到同一天',
        );
      }
    });

    test('农历生日的下一次一定不在过去', () {
      final today = _dayOnly(DateTime.now());
      final next = LunarDate.nextOccurrence(lunarMonth: 8, lunarDay: 15);
      expect(next.isBefore(today), isFalse);
      // 最多一年出头一定会轮到
      expect(next.difference(today).inDays, lessThan(400));
    });

    test('闰月不会导致崩溃', () {
      final next = LunarDate.nextOccurrence(lunarMonth: -6, lunarDay: 1);
      expect(next.isBefore(_dayOnly(DateTime.now())), isFalse);
    });

    test('月份列表包含闰月时用负数表示', () {
      final months = LunarDate.monthsOf(2026);
      expect(months, isNotEmpty);
      // 至少含正月至腊月
      for (var m = 1; m <= 12; m++) {
        expect(months, contains(m));
      }
    });
  });

  group('待办：逾期宽限', () {
    TodoItem at(DateTime due, int grace) => TodoItem(
      title: 'x',
      dueAt: due,
      graceMinutes: grace,
      createdAt: due,
    );

    test('宽限期内不算逾期，但标记为宽限中', () {
      final todo = at(
        DateTime.now().subtract(const Duration(minutes: 10)),
        30,
      );
      expect(todo.isOverdue, isFalse);
      expect(todo.isWithinGrace, isTrue);
      expect(todo.isDueSoon, isFalse);
    });

    test('超过宽限才算逾期', () {
      final todo = at(
        DateTime.now().subtract(const Duration(minutes: 40)),
        30,
      );
      expect(todo.isOverdue, isTrue);
      expect(todo.isWithinGrace, isFalse);
    });

    test('不设宽限时一过点就算逾期', () {
      final todo = at(
        DateTime.now().subtract(const Duration(minutes: 1)),
        0,
      );
      expect(todo.isOverdue, isTrue);
    });
  });

  group('待办：重复', () {
    test('每周重复从原到期日推算，不是从完成那天', () {
      final base = DateTime(2026, 3, 2, 9, 0);
      final todo = TodoItem(
        title: '交作业',
        dueAt: base,
        repeat: TodoRepeat.weekly,
        createdAt: base,
      );
      // 三天后才完成
      final doneAt = base.add(const Duration(days: 3));
      final next = todo.nextDueAfter(doneAt);

      expect(next.isAfter(doneAt), isTrue);
      expect(next.weekday, base.weekday, reason: '星期几必须保持不变');
      expect(next.difference(base).inDays % 7, 0);
    });

    test('跨过多个周期也能一步推到位', () {
      final base = DateTime(2026, 1, 5, 8, 0);
      final todo = TodoItem(
        title: 'x',
        dueAt: base,
        repeat: TodoRepeat.daily,
        createdAt: base,
      );
      final muchLater = base.add(const Duration(days: 40));
      final next = todo.nextDueAfter(muchLater);
      expect(next.isAfter(muchLater), isTrue);
      expect(next.difference(muchLater).inDays, lessThan(2));
    });

    test('不重复的任务返回原时间', () {
      final base = DateTime(2026, 3, 2, 9, 0);
      final todo = TodoItem(
        title: 'x',
        dueAt: base,
        repeat: TodoRepeat.none,
        createdAt: base,
      );
      expect(todo.nextDueAfter(DateTime(2030, 1, 1)), base);
    });
  });

  group('倒计时：重复与进度', () {
    test('每月重复的事件永远不在过去', () {
      final past = DateTime.now().subtract(const Duration(days: 45));
      final event = CountdownEvent(
        title: '交房租',
        targetDate: past,
        repeat: CountdownRepeat.monthly,
        createdAt: past,
      );
      expect(event.daysLeft, greaterThanOrEqualTo(0));
      expect(event.isPast, isFalse);
    });

    test('每年重复的农历生日总是滚到下一次', () {
      final event = CountdownEvent(
        title: '生日',
        targetDate: DateTime(2000, 1, 1),
        calendar: CountdownCalendar.lunar,
        lunarMonth: 8,
        lunarDay: 15,
        repeat: CountdownRepeat.yearly,
        createdAt: DateTime(2000, 1, 1),
      );
      expect(event.daysLeft, greaterThanOrEqualTo(0));
      expect(event.daysLeft, lessThan(400));
    });

    test('不重复的过期事件仍然是负天数', () {
      final event = CountdownEvent(
        title: 'x',
        targetDate: DateTime.now().subtract(const Duration(days: 3)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(event.daysLeft, -3);
      expect(event.isPast, isTrue);
    });

    test('进度始终落在 0..1', () {
      final event = CountdownEvent(
        title: 'x',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(event.progress, inInclusiveRange(0.0, 1.0));
    });

    test('提前天数会被兜在合理范围内', () {
      final base = CountdownEvent(
        title: 'x',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
      );
      expect(base.safeLeadDays, 3, reason: '默认就是 3 天');
      expect(base.copyWith(leadDays: 0).safeLeadDays, 1, reason: '至少 1 天');
      expect(base.copyWith(leadDays: 999).safeLeadDays, 60, reason: '上限 60 天');
      expect(base.copyWith(leadDays: 7).safeLeadDays, 7);
    });
  });

  group('新增字段的存取', () {
    test('倒计时的农历/重复/提前天数字段能往返', () {
      final event = CountdownEvent(
        id: 5,
        title: '生日',
        targetDate: DateTime(2026, 3, 3),
        calendar: CountdownCalendar.lunar,
        lunarMonth: 8,
        lunarDay: 15,
        repeat: CountdownRepeat.yearly,
        leadDays: 7,
        createdAt: DateTime(2026, 1, 1),
      );
      final back = CountdownEvent.fromMap(event.toMap());
      expect(back.calendar, CountdownCalendar.lunar);
      expect(back.lunarMonth, 8);
      expect(back.lunarDay, 15);
      expect(back.repeat, CountdownRepeat.yearly);
      expect(back.leadDays, 7);
    });

    test('待办的优先级/重复/宽限字段能往返', () {
      final todo = TodoItem(
        id: 9,
        title: '交作业',
        dueAt: DateTime(2026, 3, 2, 9, 0),
        priority: TodoPriority.urgent,
        repeat: TodoRepeat.weekly,
        graceMinutes: 60,
        createdAt: DateTime(2026, 3, 1),
      );
      final back = TodoItem.fromMap(todo.toMap());
      expect(back.priority, TodoPriority.urgent);
      expect(back.repeat, TodoRepeat.weekly);
      expect(back.graceMinutes, 60);
    });

    test('老数据缺字段时能取到默认值', () {
      final legacy = <String, Object?>{
        'id': 1,
        'title': '旧待办',
        'note': '',
        'due_at': DateTime(2026, 3, 2).millisecondsSinceEpoch,
        'remind_enabled': 1,
        'done': 0,
        'created_at': DateTime(2026, 3, 1).millisecondsSinceEpoch,
      };
      final back = TodoItem.fromMap(legacy);
      expect(back.priority, TodoPriority.normal);
      expect(back.repeat, TodoRepeat.none);
      expect(back.graceMinutes, 0);
    });
  });
}
