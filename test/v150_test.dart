import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/quick_entry.dart';
import 'package:ribei/models/transaction_record.dart';
import 'package:ribei/providers/settings_provider.dart';
import 'package:ribei/utils/categories.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('常用项（一条完整的记账）', () {
    test('存成 JSON 再读回来，字段一致', () {
      const entry = QuickEntry(
        type: TxType.income,
        category: '生活费',
        amount: 1500.5,
        note: '八月',
        payMethod: PayMethod.alipay,
      );
      final back = QuickEntry.decode(entry.encode());
      expect(back, isNotNull);
      expect(back!.type, TxType.income);
      expect(back.category, '生活费');
      expect(back.amount, 1500.5);
      expect(back.note, '八月');
      expect(back.payMethod, PayMethod.alipay);
    });

    test('坏数据只让这一条失效，不会抛异常', () {
      expect(QuickEntry.decode('这不是 JSON'), isNull);
      expect(QuickEntry.decode('{}'), isNull);
      expect(QuickEntry.decode('[1,2,3]'), isNull, reason: '不是对象');
      expect(
        QuickEntry.decode('{"type":"x","category":"餐饮","amount":10}'),
        isNull,
        reason: 'type 不是整数',
      );
      expect(
        QuickEntry.decode('{"type":0,"category":"餐饮","amount":-1}'),
        isNull,
        reason: '金额必须为正',
      );
    });

    test('没记过支付方式时，落账用默认档', () {
      const entry = QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15,
      );
      expect(entry.payMethod, PayMethod.unknown);
      expect(entry.resolvedPayMethod, PayMethod.defaultMethod);
      expect(
        entry.withPayMethod(PayMethod.cash).resolvedPayMethod,
        PayMethod.cash,
      );
    });

    test('判重：分类 / 金额 / 备注 / 方向 全一样才算同一条', () {
      const base = QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15,
      );
      const explicitEmptyNote = QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15,
        note: '',
      );
      const otherNote = QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15,
        note: '午饭',
      );
      const otherType = QuickEntry(
        type: TxType.income,
        category: '餐饮',
        amount: 15,
      );
      expect(base.key, explicitEmptyNote.key);
      expect(base.key, isNot(otherNote.key));
      expect(base.key, isNot(otherType.key));
    });

    test('金额文本：整数不带小数点', () {
      const whole = QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15,
      );
      const decimal = QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15.5,
      );
      expect(whole.amountText, '15');
      expect(decimal.amountText, '15.5');
    });
  });

  group('支付方式', () {
    test('五个选项都有名字，顺序即存储值', () {
      expect(PayMethod.all.length, 5);
      for (final m in PayMethod.all) {
        expect(PayMethod.isRecorded(m), isTrue);
        expect(PayMethod.labelOf(m), isNotEmpty);
      }
      // 改动顺序会让老数据错位，这里锁死
      expect(PayMethod.all, <int>[0, 1, 2, 3, 4]);
      expect(PayMethod.defaultMethod, PayMethod.wechat);
    });

    test('「未记录」不是可选项，会落到默认档', () {
      expect(PayMethod.isRecorded(PayMethod.unknown), isFalse);
      expect(PayMethod.all.contains(PayMethod.unknown), isFalse);
      expect(PayMethod.orDefault(PayMethod.unknown), PayMethod.defaultMethod);
      expect(PayMethod.orDefault(PayMethod.cash), PayMethod.cash);
    });
  });

  group('账目的支付方式字段', () {
    test('往返后字段一致', () {
      final record = TransactionRecord(
        amount: 15,
        type: TxType.expense,
        category: '餐饮',
        date: DateTime(2026, 3, 2),
        payMethod: PayMethod.cash,
        createdAt: DateTime(2026, 3, 2, 12),
      );
      expect(
        TransactionRecord.fromMap(record.toMap()).payMethod,
        PayMethod.cash,
      );
    });

    test('v3 老行缺这个字段时算「未记录」', () {
      final legacy = <String, Object?>{
        'id': 1,
        'amount': 15.0,
        'type': 0,
        'category': '餐饮',
        'note': '',
        'date': DateTime(2026, 3, 2).millisecondsSinceEpoch,
        'created_at': DateTime(2026, 3, 2).millisecondsSinceEpoch,
      };
      expect(TransactionRecord.fromMap(legacy).payMethod, PayMethod.unknown);
    });
  });

  group('倒计时排序', () {
    CountdownEvent make(String title, int daysFromNow, int createdDaysAgo) =>
        CountdownEvent(
          title: title,
          targetDate: DateTime.now().add(Duration(days: daysFromNow)),
          createdAt: DateTime.now().subtract(Duration(days: createdDaysAgo)),
        );

    List<String> sortedBy(int sort, List<CountdownEvent> list) {
      final copy = [...list];
      copy.sort((a, b) => CountdownSort.compare(sort, a, b));
      return copy.map((e) => e.title).toList();
    }

    test('按剩余天数：最近的排最前', () {
      final list = [make('远', 30, 0), make('近', 2, 0), make('中', 10, 0)];
      expect(sortedBy(CountdownSort.byDays, list), ['近', '中', '远']);
    });

    test('按添加时间：最新加的排最前', () {
      final list = [make('老', 5, 30), make('新', 5, 1), make('中', 5, 10)];
      expect(sortedBy(CountdownSort.byCreated, list), ['新', '中', '老']);
    });

    test('按名称：同名的再按剩余天数', () {
      final list = [make('B', 9, 0), make('A', 20, 0), make('A', 3, 0)];
      expect(sortedBy(CountdownSort.byTitle, list), ['A', 'A', 'B']);
      // 两个 A 之间，剩余天数少的在前
      final copy = [...list];
      copy.sort((a, b) => CountdownSort.compare(CountdownSort.byTitle, a, b));
      expect(copy.first.daysLeft, 3);
      expect(copy[1].daysLeft, 20);
    });

    test('三种排序都在可选列表里，且都有名字', () {
      expect(CountdownSort.all.length, 3);
      for (final s in CountdownSort.all) {
        expect(CountdownSort.labels[s], isNotNull);
        expect(CountdownSort.labels[s], isNotEmpty);
      }
    });

    test('排序值改动会让老偏好失效，所以锁死', () {
      expect(CountdownSort.byDays, 0, reason: '默认排序');
      expect(CountdownSort.all, <int>[0, 1, 2]);
    });
  });

  group('偏好存储', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('常用项增删与「用过的提前」', () async {
      final settings = SettingsProvider();
      await settings.load();
      expect(settings.quickEntries, isEmpty);

      const lunch = QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15,
      );
      const bus = QuickEntry(
        type: TxType.expense,
        category: '交通',
        amount: 2,
      );

      await settings.addQuickEntry(lunch);
      await settings.addQuickEntry(bus);
      expect(settings.quickEntries.length, 2);
      expect(settings.quickEntries.first.category, '交通', reason: '刚加的排最前');

      await settings.touchQuickEntry(lunch);
      expect(settings.quickEntries.first.category, '餐饮', reason: '用过就提前');

      await settings.addQuickEntry(lunch);
      expect(settings.quickEntries.length, 2, reason: '同一条不重复添加');
      expect(settings.quickEntries.first.category, '餐饮');

      await settings.removeQuickEntry(bus);
      expect(settings.quickEntries.length, 1);
      expect(settings.quickEntries.single.category, '餐饮');
    });

    test('常用项重启后还在', () async {
      final first = SettingsProvider();
      await first.load();
      await first.addQuickEntry(
        const QuickEntry(
          type: TxType.expense,
          category: '餐饮',
          amount: 15,
          note: '午饭',
          payMethod: PayMethod.wechat,
        ),
      );

      // 重新 load 一次 = 模拟重启
      final second = SettingsProvider();
      await second.load();
      expect(second.quickEntries.length, 1);
      final restored = second.quickEntries.single;
      expect(restored.category, '餐饮');
      expect(restored.amount, 15);
      expect(restored.note, '午饭');
      expect(restored.payMethod, PayMethod.wechat);
    });

    test('教程只弹一次：标记写下去、能读回来', () async {
      final first = SettingsProvider();
      await first.load();
      expect(first.onboardingSeen, isFalse, reason: '新装默认没看过');

      await first.markOnboardingSeen();
      expect(first.onboardingSeen, isTrue);

      final second = SettingsProvider();
      await second.load();
      expect(second.onboardingSeen, isTrue);
    });

    test('倒计时排序偏好能存能读', () async {
      final first = SettingsProvider();
      await first.load();
      expect(first.countdownSort, CountdownSort.byDays, reason: '默认按剩余天数');

      await first.setCountdownSort(CountdownSort.byTitle);

      final second = SettingsProvider();
      await second.load();
      expect(second.countdownSort, CountdownSort.byTitle);
    });
  });
}
