import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/transaction_dao.dart';
import '../models/stats.dart';
import '../models/transaction_record.dart';
import '../utils/categories.dart';

class LedgerProvider extends ChangeNotifier {
  LedgerProvider({TransactionDao? dao}) : _dao = dao ?? const TransactionDao();

  final TransactionDao _dao;

  List<TransactionRecord> _records = const <TransactionRecord>[];
  bool _ready = false;
  String? _loadError;

  List<TransactionRecord> get records => _records;
  bool get ready => _ready;

  /// 上次读取失败的原因；正常时是 null。
  ///
  /// **读失败绝不能假装成"没有记录"** —— 那会让用户以为数据丢了，
  /// 进而卸载重装，数据就真没了。界面必须显式提示（见 DataHealthBanner）。
  String? get loadError => _loadError;

  Future<void> load() async {
    try {
      _records = await _dao.all();
      _loadError = null;
    } catch (error) {
      _loadError = '$error';
      AppDatabase.instance.note('账目读取失败：$error');
      // 注意：这里**不清空** _records —— 瞬时故障不该把已有数据从界面上抹掉
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> save(TransactionRecord record) async {
    if (record.id == null) {
      await _dao.insert(record);
    } else {
      await _dao.update(record);
    }
    await load();
  }

  Future<void> remove(int id) async {
    await _dao.delete(id);
    await load();
  }

  /// 清空全部账目，返回删掉的条数
  Future<int> clearAll() async {
    final deleted = await _dao.deleteAll();
    await load();
    return deleted;
  }

  /// 清空某一天的账目，返回删掉的条数
  Future<int> clearOn(DateTime day) async {
    final deleted = await _dao.deleteOn(day);
    await load();
    return deleted;
  }

  // ---------- 查询与统计 ----------

  List<TransactionRecord> ofMonth(DateTime month) => _records
      .where((r) => r.date.year == month.year && r.date.month == month.month)
      .toList(growable: false);

  List<TransactionRecord> ofDay(DateTime day) => _records
      .where(
        (r) =>
            r.date.year == day.year &&
            r.date.month == day.month &&
            r.date.day == day.day,
      )
      .toList(growable: false);

  /// 某个日期区间（含首尾两天）的账目，按日期倒序
  List<TransactionRecord> ofRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    return _records
        .where((r) => !r.date.isBefore(start) && r.date.isBefore(end))
        .toList(growable: false);
  }

  double expenseOf(DateTime month) => _sum(ofMonth(month), TxType.expense);

  double incomeOf(DateTime month) => _sum(ofMonth(month), TxType.income);

  /// 任意一组账目里某个方向的总和
  double sumOf(Iterable<TransactionRecord> list, int type) =>
      _sum(list, type);

  double _sum(Iterable<TransactionRecord> list, int type) => list
      .where((r) => r.type == type)
      .fold<double>(0.0, (acc, r) => acc + r.amount);

  /// 某月某类型的分类汇总，金额由大到小。
  List<CategoryStat> categoryStats(DateTime month, int type) =>
      categoryStatsOf(ofMonth(month), type);

  /// 任意一组账目的分类汇总，金额由大到小。
  List<CategoryStat> categoryStatsOf(
    Iterable<TransactionRecord> list,
    int type,
  ) {
    final buckets = <String, double>{};
    for (final r in list) {
      if (r.type != type) continue;
      buckets[r.category] = (buckets[r.category] ?? 0.0) + r.amount;
    }
    return buckets.entries
        .map((e) => CategoryStat(e.key, e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// 打包一份账单汇总，给「分享账单」用。
  ///
  /// [topCount] 是要在图片上列出的分类个数，取花得最多的那几个。
  BillSummary summarize(DateTime from, DateTime to, {int topCount = 5}) {
    final list = ofRange(from, to);
    return BillSummary(
      from: from,
      to: to,
      expense: _sum(list, TxType.expense),
      income: _sum(list, TxType.income),
      count: list.length,
      topCategories: categoryStatsOf(list, TxType.expense)
          .take(topCount)
          .toList(growable: false),
    );
  }

  /// 最近 [count] 个月（含当月）的收支，用于趋势图。
  List<MonthStat> trend(int count) {
    final now = DateTime.now();
    return List<MonthStat>.generate(count, (i) {
      final month = DateTime(now.year, now.month - (count - 1 - i));
      return MonthStat(
        month: month,
        expense: expenseOf(month),
        income: incomeOf(month),
      );
    });
  }

  /// 有记录以来最早的一个月；无记录时返回当月。
  DateTime get earliestMonth {
    if (_records.isEmpty) return DateTime.now();
    var earliest = _records.first.date;
    for (final r in _records) {
      if (r.date.isBefore(earliest)) earliest = r.date;
    }
    return earliest;
  }

  /// 累计结余
  double get totalBalance =>
      _records.fold<double>(0.0, (acc, r) => acc + r.signedAmount);

  /// 关键字搜索：匹配备注、分类，也支持金额片段（如输入 12.5）
  List<TransactionRecord> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <TransactionRecord>[];
    return _records.where((r) {
      if (r.note.toLowerCase().contains(q)) return true;
      if (r.category.toLowerCase().contains(q)) return true;
      if (r.amount.toStringAsFixed(2).contains(q)) return true;
      return false;
    }).toList();
  }
}
