import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/day_row.dart';
import 'package:ribei/models/milestone.dart';

/// 「日子」把倒计时和纪念日合并成一条列表 —— 这里钉的是**合并后的顺序**，
/// 因为那是这块最容易出错的地方（参考图的顺序就是：置顶在前 → 还没到的由近及远 → 已经过去的在后）。
void main() {
  CountdownEvent countdown({
    required int id,
    required String title,
    required int daysFromNow,
    bool pinned = false,
  }) => CountdownEvent(
    id: id,
    title: title,
    targetDate: DateTime.now().add(Duration(days: daysFromNow)),
    pinned: pinned,
    createdAt: DateTime.now(),
  );

  Milestone milestone({
    required int id,
    required String title,
    required int daysAgo,
    bool pinned = false,
  }) => Milestone(
    id: id,
    title: title,
    startDate: DateTime.now().subtract(Duration(days: daysAgo)),
    pinned: pinned,
    createdAt: DateTime.now(),
  );

  group('合并排序', () {
    test('置顶最前 → 还没到的由近及远 → 已经过去的排在最后', () {
      final rows = DayRow.merge(
        <CountdownEvent>[
          countdown(id: 1, title: '四级考试', daysFromNow: 36),
          countdown(id: 2, title: '发工资', daysFromNow: 4),
          countdown(id: 3, title: 'New Year', daysFromNow: 56),
          countdown(id: 4, title: 'iPhone 发布', daysFromNow: -6340),
        ],
        <Milestone>[
          milestone(id: 5, title: '22岁生日', daysAgo: 42),
          milestone(id: 6, title: '在一起', daysAgo: 126, pinned: true),
        ],
      );

      expect(
        rows.map((r) => r.title).toList(),
        <String>['在一起', '发工资', '四级考试', 'New Year', '22岁生日', 'iPhone 发布'],
      );
      expect(rows.first.pinned, isTrue);
      expect(rows.first.isMilestone, isTrue);
    });

    test('空输入不会炸', () {
      expect(DayRow.merge(const <CountdownEvent>[], const <Milestone>[]), isEmpty);
    });
  });

  group('两边的方向与天数都要算对', () {
    test('倒计时：未来是"还有"，过去是"已经"', () {
      final future = DayRow.fromCountdown(
        countdown(id: 1, title: 'x', daysFromNow: 5),
      );
      expect(future.past, isFalse);
      expect(future.days, 5);

      final past = DayRow.fromCountdown(
        countdown(id: 2, title: 'y', daysFromNow: -3),
      );
      expect(past.past, isTrue);
      expect(past.days, 3);
    });

    test('纪念日：已经过的是正计时，起始日在未来则算"还有"', () {
      final past = DayRow.fromMilestone(
        milestone(id: 3, title: 'z', daysAgo: 10),
      );
      expect(past.past, isTrue);
      expect(past.days, 10);

      final future = DayRow.fromMilestone(
        milestone(id: 4, title: 'w', daysAgo: -7),
      );
      expect(future.past, isFalse);
      expect(future.days, 7);
    });
  });
}
