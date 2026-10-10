/// 分类汇总，用于饼图与排行
class CategoryStat {
  const CategoryStat(this.category, this.amount);

  final String category;
  final double amount;
}

/// 单月收支，用于趋势图
class MonthStat {
  const MonthStat({
    required this.month,
    required this.expense,
    required this.income,
  });

  final DateTime month;
  final double expense;
  final double income;

  double get balance => income - expense;
}

/// 分享账单用的一次性汇总。
///
/// 把"要画进那张图里的东西"先算好，这样账单卡片组件是纯展示、不碰数据库，
/// 也方便以后换别的渲染方式（比如导出 PDF）。
class BillSummary {
  const BillSummary({
    required this.from,
    required this.to,
    required this.expense,
    required this.income,
    required this.count,
    required this.topCategories,
  });

  /// 起止日期，含首尾两天
  final DateTime from;
  final DateTime to;

  final double expense;
  final double income;

  /// 区间内的账目总笔数
  final int count;

  /// 花得最多的几个分类（已按金额降序）
  final List<CategoryStat> topCategories;

  double get balance => income - expense;

  bool get isEmpty => count == 0;
}
