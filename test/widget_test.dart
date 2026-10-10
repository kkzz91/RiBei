import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/transaction_record.dart';

/// 目标日期取「今天 + n 天」，避免受当前时刻影响。
DateTime _dayFromNow(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

CountdownEvent _eventIn(int days) => CountdownEvent(
  title: '测试事件',
  targetDate: _dayFromNow(days),
  createdAt: DateTime.now(),
);

void main() {
  group('倒计时天数计算', () {
    test('未来日期返回正数天', () {
      final event = _eventIn(10);
      expect(event.daysLeft, 10);
      expect(event.isPast, isFalse);
      expect(event.isUrgentWindow, isFalse);
    });

    test('当天返回 0，且不受时分秒影响', () {
      final event = _eventIn(0);
      expect(event.daysLeft, 0);
      expect(event.isUrgentWindow, isTrue);
    });

    test('临近前 3 天进入提醒窗口', () {
      for (final days in <int>[1, 2, 3]) {
        expect(
          _eventIn(days).isUrgentWindow,
          isTrue,
          reason: '还有 $days 天应处于临近窗口',
        );
      }
    });

    test('第 4 天起不在提醒窗口', () {
      expect(_eventIn(4).isUrgentWindow, isFalse);
      expect(_eventIn(30).isUrgentWindow, isFalse);
    });

    test('过期后返回负数并标记为已结束', () {
      final event = _eventIn(-2);
      expect(event.daysLeft, -2);
      expect(event.isPast, isTrue);
      expect(event.isUrgentWindow, isFalse);
    });
  });

  group('记账记录的存取', () {
    test('toMap / fromMap 往返后字段一致', () {
      final record = TransactionRecord(
        id: 7,
        amount: 123.45,
        type: 0,
        category: '餐饮',
        note: '午饭',
        date: DateTime(2026, 1, 10),
        createdAt: DateTime(2026, 1, 10, 12, 30),
      );

      final restored = TransactionRecord.fromMap(record.toMap());

      expect(restored.id, 7);
      expect(restored.amount, 123.45);
      expect(restored.type, 0);
      expect(restored.category, '餐饮');
      expect(restored.note, '午饭');
      expect(restored.date, DateTime(2026, 1, 10));
      expect(restored.createdAt, DateTime(2026, 1, 10, 12, 30));
    });

    test('支出记为负、收入记为正', () {
      final expense = TransactionRecord(
        amount: 10,
        type: 0,
        category: '餐饮',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      final income = TransactionRecord(
        amount: 10,
        type: 1,
        category: '工资',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      expect(expense.isExpense, isTrue);
      expect(expense.signedAmount, -10);
      expect(income.isExpense, isFalse);
      expect(income.signedAmount, 10);
    });
  });
}
