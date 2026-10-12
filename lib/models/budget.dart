/// 月度预算：**一个总额 + 几条"金额红线"**。
///
/// 用户要求（v1.6.15）："搞一个月度预算……你可以分几条红线，
/// 让用户自己设计，可以设计几个金额红线"。
///
/// 存的是**用户偏好**（SharedPreferences），不是数据库表 ——
/// 这样完全不用动 schema，也就没有迁移风险（见红线 18）。
class BudgetPlan {
  const BudgetPlan({this.total = 0, this.tiers = const <double>[]});

  static const BudgetPlan none = BudgetPlan();

  /// 本月预算总额。0 = 没设。
  final double total;

  /// 红线金额，**升序**。花到哪一条就提醒一次。
  final List<double> tiers;

  bool get hasPlan => total > 0 || tiers.isNotEmpty;

  BudgetPlan copyWith({double? total, List<double>? tiers}) => BudgetPlan(
    total: total ?? this.total,
    tiers: _sorted(tiers ?? this.tiers),
  );

  /// 存成一行 —— `总额|红线1,红线2`（没有的一部分留空）
  String encode() =>
      '${_num(total)}|${tiers.map(_num).join(',')}';

  static BudgetPlan decode(String raw) {
    final parts = raw.split('|');
    final total = parts.isNotEmpty ? (double.tryParse(parts[0]) ?? 0) : 0.0;
    final tiers = <double>[];
    if (parts.length > 1 && parts[1].isNotEmpty) {
      for (final piece in parts[1].split(',')) {
        final v = double.tryParse(piece);
        if (v != null && v > 0) tiers.add(v);
      }
    }
    return BudgetPlan(total: total, tiers: _sorted(tiers));
  }

  /// `3000.0` 这种尾巴不好看，整数就去掉小数点
  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static List<double> _sorted(Iterable<double> values) {
    final list = values.where((v) => v > 0).toList()..sort();
    return List<double>.unmodifiable(list);
  }
}

/// 本月花到哪一档了。**纯计算**，所以能单测。
class BudgetStatus {
  const BudgetStatus({
    required this.spent,
    required this.plan,
    required this.crossed,
  });

  final double spent;
  final BudgetPlan plan;

  /// 已经跨过了几条红线（0 = 一条都没跨）
  final int crossed;

  bool get hasPlan => plan.hasPlan;

  bool get overBudget => plan.total > 0 && spent > plan.total;

  /// 预算进度。没设总额时是 0。
  double get ratio => plan.total <= 0 ? 0 : spent / plan.total;

  /// 还剩多少（可能为负 = 超了）
  double get remaining => plan.total - spent;

  /// 下一条还没跨过的红线；都跨完了就是 null
  double? get nextTier {
    for (final t in plan.tiers) {
      if (spent <= t) return t;
    }
    return null;
  }

  /// 进度条要画到多长：总额、最后一条红线、实际花销里最大的那个
  /// （超支或红线比总额大时，条不能被切掉）
  double get barMax {
    var max = plan.total;
    for (final t in plan.tiers) {
      if (t > max) max = t;
    }
    return spent > max ? spent : max;
  }
}

/// 算一次状态（没有副作用，方便单测）
BudgetStatus evaluateBudget({required double spent, required BudgetPlan plan}) {
  var crossed = 0;
  for (final t in plan.tiers) {
    if (spent > t) crossed++;
  }
  return BudgetStatus(spent: spent, plan: plan, crossed: crossed);
}
