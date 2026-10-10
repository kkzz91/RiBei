import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ribei/data/transaction_dao.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/transaction_record.dart';
import 'package:ribei/providers/ledger_provider.dart';
import 'package:ribei/utils/categories.dart';
import 'package:ribei/utils/formatters.dart';
import 'package:ribei/widgets/pie_3d.dart';

/// 假的 DAO：直接吐一份内存里的账目，用来测「按区间取数 + 汇总」这段逻辑，
/// 不用真的连 SQLite。
class _FakeDao extends TransactionDao {
  _FakeDao(this.records);

  final List<TransactionRecord> records;

  @override
  Future<List<TransactionRecord>> all() async => records;
}

TransactionRecord _tx(
  DateTime date,
  double amount,
  int type,
  String category,
) => TransactionRecord(
  amount: amount,
  type: type,
  category: category,
  date: date,
  createdAt: date,
);

void main() {
  setUpAll(() async {
    // formatFullDate 用的是 zh_CN 的 intl 数据，不初始化会直接抛异常
    await initializeDateFormatting('zh_CN');
  });

  group('立体饼图的命中判定', () {
    const center = Offset(100, 100);
    const outer = 80.0;
    const inner = 40.0;

    // 从 12 点钟开始、顺时针增长：-90° 是正上方，0° 是正右，90° 是正下
    Offset atDeg(double deg, [double r = 60]) => center +
        Offset(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180)) *
            r;

    int hit(List<double> sweeps, Offset p) => Pie3D.hitTestSlice(
      point: p,
      center: center,
      outerRadius: outer,
      innerRadius: inner,
      sweeps: sweeps,
    );

    test('四等分：四个正方向各落在对应的扇区', () {
      const sweeps = <double>[90, 90, 90, 90];
      expect(hit(sweeps, atDeg(-90)), 0, reason: '正上方属第一块');
      expect(hit(sweeps, atDeg(0)), 1, reason: '正右方属第二块');
      expect(hit(sweeps, atDeg(90)), 2, reason: '正下方属第三块');
      expect(hit(sweeps, atDeg(180)), 3, reason: '正左方属第四块');
    });

    test('角度落在扇区内部', () {
      const sweeps = <double>[90, 90, 90, 90];
      expect(hit(sweeps, atDeg(-89)), 0);
      expect(hit(sweeps, atDeg(-45)), 0, reason: '右上 45 度仍在第一块');
      expect(hit(sweeps, atDeg(45)), 1);
      expect(hit(sweeps, atDeg(135)), 2);
      expect(hit(sweeps, atDeg(-135)), 3);
    });

    test('大小不一的扇区按各自的角度范围判定', () {
      const sweeps = <double>[180, 90, 90];
      expect(hit(sweeps, atDeg(-90)), 0);
      expect(hit(sweeps, atDeg(0)), 0, reason: '第一块占半圈');
      expect(hit(sweeps, atDeg(89)), 0);
      expect(hit(sweeps, atDeg(92)), 1, reason: '刚过 180 度进第二块');
      expect(hit(sweeps, atDeg(180)), 2);
    });

    test('12 点钟那条边界：两侧分别归第一块和最后一块', () {
      const sweeps = <double>[180, 90, 90];
      // 刻意避开"正好 270 度"这个退化输入：那个点上 cos(270°) 的浮点误差
      // 会让 atan2 判成"略偏左"，于是归到最后一块 —— 这本身是正确行为
      // （那个位置确实在最后一格里），只是不适合拿来当断言。
      // 测边界两侧更稳，也更能说明环绕是怎么处理的。
      expect(hit(sweeps, atDeg(271)), 0, reason: '刚过 12 点 → 第一块');
      expect(hit(sweeps, atDeg(269)), 2, reason: '还没到 12 点 → 最后一块');
    });

    test('只有一个扇区时，环上任何位置都是它', () {
      const sweeps = <double>[360];
      expect(hit(sweeps, atDeg(-90)), 0);
      expect(hit(sweeps, atDeg(37)), 0);
      expect(hit(sweeps, atDeg(200)), 0);
    });

    test('洞里面和饼外面都不算命中', () {
      const sweeps = <double>[90, 90, 90, 90];
      expect(hit(sweeps, center), -1, reason: '正中心在洞里');
      expect(hit(sweeps, atDeg(-90, 20)), -1, reason: '洞半径之内');
      expect(hit(sweeps, atDeg(-90, 95)), -1, reason: '超出外半径');
      expect(hit(sweeps, atDeg(-90, 39.9)), -1);
      expect(hit(sweeps, atDeg(-90, 40.1)), 0, reason: '刚出洞就算命中');
    });

    test('没有扇区时什么都不命中', () {
      expect(hit(const <double>[], atDeg(-90)), -1);
    });
  });

  group('饼图的路径几何', () {
    const c = Offset(100, 100);

    test('整圈的环画得出来（收入只有一类时就是这种）', () {
      final full = Pie3D.ringSector(c, 80, 40, -math.pi / 2, math.pi * 2);
      final b = full.getBounds();

      // 这就是收入饼图看不见的根因：Path.arcTo 的 sweep 会被规整到 [0,360)，
      // 传 2π 等于传 0，路径是空的 → 整块饼什么都不画。
      expect(b.isEmpty, isFalse, reason: '整圈不能是空路径');
      expect(b.width, closeTo(160, 1), reason: '外径 80 → 宽 160');
      expect(b.height, closeTo(160, 1));
      expect(b.center.dx, closeTo(100, 1));
      expect(b.center.dy, closeTo(100, 1));
    });

    test('整圈的环中间是空的，中心文字能透出来', () {
      final full = Pie3D.ringSector(c, 80, 40, -math.pi / 2, math.pi * 2);
      expect(full.contains(c), isFalse, reason: '洞中心不该被填上');
      expect(
        full.contains(const Offset(100, 100 - 60)),
        isTrue,
        reason: '环上（半径 60）该被填上',
      );
    });

    test('半圈的环外接矩形只有半边', () {
      // 从 12 点顺时针半圈 → 落在右半边
      final half = Pie3D.ringSector(c, 80, 40, -math.pi / 2, math.pi);
      final b = half.getBounds();
      expect(b.width, closeTo(80, 1), reason: '只占圆心到右侧');
      expect(b.height, closeTo(160, 1));
      expect(b.left, closeTo(100, 1));
    });

    test('各种尺寸和厚度下，饼都不会画出自己的方框', () {
      // 这条不变量就是上次出问题的地方：没给"厚度 + 抬起"留边距，
      // 底部扇区一被选中就越过下边界，压到了卡片下面那行说明文字。
      for (final size in <double>[200, 238, 250, 320]) {
        for (final depth in <double>[10, 16, 22]) {
          final g = Pie3D.geometryFor(size: size, depth: depth);
          // 最坏情况：选中那块又长又挪，且动画过冲
          final reach = Pie3D.grow * Pie3D.overshoot +
              Pie3D.popDistance * Pie3D.overshoot;

          expect(g.outerRadius, greaterThan(0),
              reason: 'size=$size depth=$depth 半径得是正的');
          expect(
            g.center.dy + g.outerRadius + depth + reach,
            lessThanOrEqualTo(size),
            reason: 'size=$size depth=$depth 下边界超了',
          );
          expect(
            g.center.dy - g.outerRadius - reach,
            greaterThanOrEqualTo(0),
            reason: 'size=$size depth=$depth 上边界超了',
          );
          expect(
            g.center.dx + g.outerRadius + reach,
            lessThanOrEqualTo(size),
            reason: 'size=$size depth=$depth 右边界超了',
          );
        }
      }
    });
  });

  group('生日事件识别', () {
    CountdownEvent make(String title, String note, DateTime target) =>
        CountdownEvent(
          title: title,
          note: note,
          targetDate: target,
          createdAt: DateTime(2020, 1, 1),
        );

    test('名称里提到「生日」就算', () {
      expect(make('妈妈生日', '', DateTime(2030, 1, 1)).isBirthday, isTrue);
      expect(make('生日', '', DateTime(2030, 1, 1)).isBirthday, isTrue);
    });

    test('备注里提到也算', () {
      expect(
        make('重要的日子', '记得是奶奶生日', DateTime(2030, 1, 1)).isBirthday,
        isTrue,
      );
    });

    test('没提到就不是', () {
      expect(make('交房租', '', DateTime(2030, 1, 1)).isBirthday, isFalse);
      expect(make('期末考试', '带学生证', DateTime(2030, 1, 1)).isBirthday, isFalse);
    });

    test('只有"就是今天"才触发惊喜，前一天不算', () {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      expect(make('妈妈生日', '', todayOnly).isBirthdayToday, isTrue);
      expect(
        make('妈妈生日', '', todayOnly.add(const Duration(days: 1)))
            .isBirthdayToday,
        isFalse,
      );
      expect(
        make('妈妈生日', '', todayOnly.subtract(const Duration(days: 1)))
            .isBirthdayToday,
        isFalse,
      );
      // 不是生日事件，就算正好是今天也不触发
      expect(make('交房租', '', todayOnly).isBirthdayToday, isFalse);
    });
  });

  group('日期区间的写法', () {
    test('同一天只写一次日期', () {
      expect(
        formatDateRange(DateTime(2026, 9, 3), DateTime(2026, 9, 3)),
        '2026年9月3日',
      );
    });

    test('同月省略重复的年份和月份', () {
      expect(
        formatDateRange(DateTime(2026, 9, 3), DateTime(2026, 9, 28)),
        '2026年9月3日 – 28日',
      );
    });

    test('同年不同月', () {
      expect(
        formatDateRange(DateTime(2026, 9, 3), DateTime(2026, 10, 8)),
        '2026年9月3日 – 10月8日',
      );
    });

    test('跨年两边都写全', () {
      expect(
        formatDateRange(DateTime(2025, 12, 3), DateTime(2026, 1, 8)),
        '2025年12月3日 – 2026年1月8日',
      );
    });
  });

  group('账单区间的取数与汇总', () {
    // 跨三个月的账，用来验证区间是"含首尾两天"的
    final jan31 = DateTime(2026, 1, 31, 23, 30);
    final feb1 = DateTime(2026, 2, 1, 0, 10);
    final feb15 = DateTime(2026, 2, 15, 12);
    final feb28 = DateTime(2026, 2, 28, 23, 59);
    final mar1 = DateTime(2026, 3, 1, 0, 1);

    final records = <TransactionRecord>[
      _tx(jan31, 10, TxType.expense, '餐饮'),
      _tx(feb1, 20, TxType.expense, '餐饮'),
      _tx(feb15, 5, TxType.expense, '交通'),
      _tx(feb28, 3000, TxType.income, '生活费'),
      _tx(mar1, 99, TxType.expense, '购物'),
    ];

    Future<LedgerProvider> provider() async {
      final p = LedgerProvider(dao: _FakeDao(records));
      await p.load();
      return p;
    }

    test('ofRange 含首尾两天，且不碰区间外的记录', () async {
      final p = await provider();
      final feb = p.ofRange(DateTime(2026, 2, 1), DateTime(2026, 2, 28));
      expect(feb.length, 3, reason: '2月有 3 笔，1月31和3月1不算');
      expect(
        feb.every((r) => r.date.month == 2),
        isTrue,
      );
    });

    test('单天区间只取当天', () async {
      final p = await provider();
      final one = p.ofRange(DateTime(2026, 2, 1), DateTime(2026, 2, 1));
      expect(one.length, 1);
      expect(one.single.amount, 20);
    });

    test('summarize 算对了收支、笔数和分类排行', () async {
      final p = await provider();
      final s = p.summarize(DateTime(2026, 2, 1), DateTime(2026, 2, 28));

      expect(s.count, 3);
      expect(s.expense, 25, reason: '20 + 5');
      expect(s.income, 3000);
      expect(s.balance, 2975);
      expect(s.isEmpty, isFalse);

      // 只列支出，且按金额从大到小
      expect(s.topCategories.length, 2);
      expect(s.topCategories.first.category, '餐饮');
      expect(s.topCategories.first.amount, 20);
      expect(s.topCategories.last.category, '交通');
    });

    test('topCount 限制列出几个分类', () async {
      final p = await provider();
      final s = p.summarize(
        DateTime(2026, 1, 1),
        DateTime(2026, 3, 31),
        topCount: 1,
      );
      expect(s.topCategories.length, 1);
      expect(s.topCategories.single.category, '购物', reason: '99 最大');
      expect(s.count, 5);
    });

    test('空区间是空的，不会算出脏数据', () async {
      final p = await provider();
      final s = p.summarize(DateTime(2025, 6, 1), DateTime(2025, 6, 30));
      expect(s.isEmpty, isTrue);
      expect(s.count, 0);
      expect(s.expense, 0);
      expect(s.income, 0);
      expect(s.balance, 0);
      expect(s.topCategories, isEmpty);
    });
  });
}
