import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/todo_item.dart';

TodoItem _todoAt(DateTime due) =>
    TodoItem(title: '测试', dueAt: due, createdAt: DateTime.now());

void main() {
  group('待办的到期判定', () {
    test('未来时间不算逾期，24 小时内算紧急', () {
      final todo = _todoAt(DateTime.now().add(const Duration(hours: 2)));
      expect(todo.isOverdue, isFalse);
      expect(todo.isDueSoon, isTrue);
    });

    test('过去时间算逾期，不再算紧急', () {
      final todo = _todoAt(DateTime.now().subtract(const Duration(minutes: 1)));
      expect(todo.isOverdue, isTrue);
      expect(todo.isDueSoon, isFalse);
    });

    test('已完成的不算逾期也不高亮', () {
      final todo = _todoAt(
        DateTime.now().subtract(const Duration(days: 2)),
      ).copyWith(done: true);
      expect(todo.isOverdue, isFalse);
      expect(todo.isDueSoon, isFalse);
    });

    test('超过 24 小时不算紧急', () {
      final todo = _todoAt(DateTime.now().add(const Duration(hours: 30)));
      expect(todo.isDueSoon, isFalse);
      expect(todo.isOverdue, isFalse);
    });
  });

  group('待办序列化', () {
    test('toMap / fromMap 往返后字段一致', () {
      final todo = TodoItem(
        id: 3,
        title: '交作业',
        note: '带 U 盘',
        dueAt: DateTime(2026, 3, 5, 14, 30),
        remindEnabled: false,
        done: true,
        completedAt: DateTime(2026, 3, 5, 15, 0),
        createdAt: DateTime(2026, 3, 1, 9, 0),
      );

      final restored = TodoItem.fromMap(todo.toMap());

      expect(restored.id, 3);
      expect(restored.title, '交作业');
      expect(restored.note, '带 U 盘');
      expect(restored.dueAt, DateTime(2026, 3, 5, 14, 30));
      expect(restored.remindEnabled, isFalse);
      expect(restored.done, isTrue);
      expect(restored.completedAt, DateTime(2026, 3, 5, 15, 0));
      expect(restored.createdAt, DateTime(2026, 3, 1, 9, 0));
    });

    test('未完成时 completedAt 为 null', () {
      final todo = TodoItem(
        title: 'x',
        dueAt: DateTime(2026, 3, 5),
        createdAt: DateTime(2026, 3, 1),
      );
      final restored = TodoItem.fromMap(todo.toMap());
      expect(restored.completedAt, isNull);
      expect(restored.done, isFalse);
    });

    test('取消完成会清掉完成时间', () {
      final todo = TodoItem(
        title: 'x',
        dueAt: DateTime(2026, 3, 5),
        done: true,
        completedAt: DateTime(2026, 3, 5, 15),
        createdAt: DateTime(2026, 3, 1),
      );
      final reopened = todo.copyWith(done: false, clearCompletedAt: true);
      expect(reopened.done, isFalse);
      expect(reopened.completedAt, isNull);
    });
  });
}
