import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/milestone.dart';
import 'package:ribei/theme/milestone_themes.dart';

/// 纪念日的"已经过了多久"——这是"准确"这个要求的核心，必须钉死。
///
/// 重点测跨月、月末、闰年这些容易算错的地方。
void main() {
  MilestoneElapsed since(DateTime start, DateTime now) =>
      MilestoneElapsed.since(start, now);

  group('共多少天（无歧义）', () {
    test('起始当天 = 第 0 天 / 第 1 天', () {
      final e = since(DateTime(2026, 1, 1), DateTime(2026, 1, 1, 10, 30));
      expect(e.totalDays, 0);
      expect(e.isFuture, isFalse);

      // dayNumber 内部用的是真实时钟，所以这里用"今天"来构造：
      // 今天的纪念日 = 第 1 天
      final now = DateTime.now();
      final m = Milestone(
        title: 'x',
        startDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      );
      expect(m.dayNumber, 1);
    });

    test('整一年 = 365 天（平年）', () {
      final e = since(DateTime(2021, 3, 1), DateTime(2022, 3, 1));
      expect(e.totalDays, 365);
      expect(e.years, 1);
      expect(e.months, 0);
      expect(e.days, 0);
    });

    test('跨过一个闰年 = 366 天', () {
      final e = since(DateTime(2023, 5, 20), DateTime(2024, 5, 20));
      expect(e.totalDays, 366);
      expect(e.years, 1);
    });
  });

  group('年/月/日的拆解（周年纪念日语义）', () {
    test('月中到月中，跨一个月', () {
      final e = since(DateTime(2026, 1, 15), DateTime(2026, 2, 15));
      expect(e.years, 0);
      expect(e.months, 1);
      expect(e.days, 0);
    });

    test('月末要夹到月末：1月31 → 3月1 = 1 个月 1 天', () {
      final e = since(DateTime(2026, 1, 31), DateTime(2026, 3, 1));
      expect(e.months, 1);
      expect(e.days, 1, reason: '2月31被夹成2月28，到3月1还差1天');
      expect(e.days, greaterThanOrEqualTo(0));
    });

    test('闰年 2月29 的周年在平年落在 2月28', () {
      final e = since(DateTime(2024, 2, 29), DateTime(2025, 2, 28));
      expect(e.years, 1, reason: '周年纪念日被夹到2月28，所以正好整1年');
      expect(e.days, 0);
    });

    test('闰年 2月29 再过一天才是"1年零1天"', () {
      final e = since(DateTime(2024, 2, 29), DateTime(2025, 3, 1));
      expect(e.years, 1);
      expect(e.days, 1);
    });

    test('拆解出来的天数永远不会是负数', () {
      // 扫一遍全年每一天，确保从月初/月末出发都不会出现负天数
      for (var startDay = 28; startDay <= 31; startDay++) {
        for (var m = 1; m <= 12; m++) {
          // 用不存在的日会自动进位，所以夹到当月最后一天
          final last = DateTime(2026, m + 1, 0).day;
          final d = startDay > last ? last : startDay;
          final start = DateTime(2026, m, d);
          for (var k = 1; k <= 400; k++) {
            final now = start.add(Duration(days: k));
            final e = since(start, now);
            expect(e.days, greaterThanOrEqualTo(0),
                reason: '从 $start 起第 $k 天不该有负天数');
            expect(e.days, lessThan(31));
          }
        }
      }
    });
  });

  group('未来日期', () {
    test('还没到起始日，totalDays 为负且标记未开始', () {
      final e = since(DateTime(2026, 6, 1), DateTime(2026, 1, 1));
      expect(e.isFuture, isTrue);
      expect(e.totalDays, lessThan(0));
    });
  });

  group('序列化', () {
    test('toMap / fromMap 往返一致', () {
      final m = Milestone(
        id: 7,
        title: '在一起',
        startDate: DateTime(2023, 5, 20),
        note: '第一次见面',
        theme: MilestoneTheme.sunset,
        createdAt: DateTime(2026, 1, 1),
      );
      final back = Milestone.fromMap(m.toMap());
      expect(back.id, 7);
      expect(back.title, '在一起');
      expect(back.startDate, DateTime(2023, 5, 20));
      expect(back.note, '第一次见面');
      expect(back.theme, MilestoneTheme.sunset);
    });

    test('老数据缺主题字段时兜到黑金', () {
      final legacy = <String, Object?>{
        'id': 1,
        'title': 'x',
        'start_date': DateTime(2023, 1, 1).millisecondsSinceEpoch,
        'note': '',
        'created_at': DateTime(2023, 1, 1).millisecondsSinceEpoch,
      };
      expect(Milestone.fromMap(legacy).theme, MilestoneTheme.blackGold);
    });
  });

  group('主题表（下标就是存进库的值，不许错位）', () {
    test('编号跟样式表一一对应', () {
      expect(milestoneThemeStyles.length, MilestoneTheme.all.length);
      for (final t in MilestoneTheme.all) {
        expect(themeStyleOf(t).label, MilestoneTheme.labels[t]);
      }
    });

    test('越界编号兜到黑金，不崩', () {
      expect(themeStyleOf(-1), milestoneThemeStyles[MilestoneTheme.blackGold]);
      expect(themeStyleOf(999), milestoneThemeStyles[MilestoneTheme.blackGold]);
    });

    test('老编号不许变：0~4 还是原来那五套', () {
      // 这五套在 v1.6.0 及以前就发给用户了，编号已经写进数据库。
      // 顺序一乱，老用户的纪念日/倒计时会集体换背景（红线 9 的同族规矩）。
      expect(MilestoneTheme.blackGold, 0);
      expect(MilestoneTheme.jade, 1);
      expect(MilestoneTheme.deepBlue, 2);
      expect(MilestoneTheme.sunset, 3);
      expect(MilestoneTheme.paper, 4);
      expect(milestoneThemeStyles[0].label, '黑金');
      expect(milestoneThemeStyles[4].label, '极简白');
    });
  });

  group('倒计时的背景主题（DB v6 加的列）', () {
    test('toMap / fromMap 往返一致', () {
      final e = CountdownEvent(
        id: 3,
        title: '期末考试',
        targetDate: DateTime(2027, 1, 10),
        theme: MilestoneTheme.wood,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(CountdownEvent.fromMap(e.toMap()).theme, MilestoneTheme.wood);
    });

    test('老数据缺 theme 字段时兜到黑金', () {
      final legacy = <String, Object?>{
        'id': 1,
        'title': 'x',
        'target_date': DateTime(2027, 1, 1).millisecondsSinceEpoch,
        'created_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      };
      expect(CountdownEvent.fromMap(legacy).theme, MilestoneTheme.blackGold);
    });
  });
}
