import 'dart:convert';

import '../utils/categories.dart';

/// 一条「常用」：一整套记账内容（类型 + 分类 + 金额 + 备注 + 支付方式）。
///
/// 和早先的"常用金额"不是一回事 —— 那个只存一个数字，点上去还得自己选分类。
/// 这个存的是一次**完整的记账**，点一下就能直接落账。
class QuickEntry {
  const QuickEntry({
    required this.type,
    required this.category,
    required this.amount,
    this.note = '',
    this.payMethod = PayMethod.unknown,
  });

  /// [TxType.expense] 或 [TxType.income]
  final int type;

  final String category;
  final double amount;
  final String note;

  /// [PayMethod]；[PayMethod.unknown] 表示当时没选，落账时用默认值
  final int payMethod;

  bool get isExpense => type == TxType.expense;

  /// 判重用：分类 + 金额 + 备注 + 方向都一样才算同一条
  String get key => '$type|$category|$amount|$note';

  /// 金额文本：整数不带小数点，和键盘输入的口径一致
  String get amountText => amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : '$amount';

  /// 落账时实际用的支付方式（没记录过就用默认值）
  int get resolvedPayMethod => PayMethod.orDefault(payMethod);

  /// 改一下支付方式，其余不变
  QuickEntry withPayMethod(int value) => QuickEntry(
    type: type,
    category: category,
    amount: amount,
    note: note,
    payMethod: value,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'category': category,
    'amount': amount,
    'note': note,
    'pay': payMethod,
  };

  static QuickEntry? fromJson(Map<String, Object?> m) {
    final type = m['type'];
    final category = m['category'];
    final amount = m['amount'];
    if (type is! int || category is! String || amount is! num) return null;
    if (amount <= 0) return null;
    return QuickEntry(
      type: type,
      category: category,
      amount: amount.toDouble(),
      note: (m['note'] as String?) ?? '',
      payMethod: m['pay'] as int? ?? PayMethod.unknown,
    );
  }

  String encode() => jsonEncode(toJson());

  /// 解析失败返回 null。
  ///
  /// 这里是读取本地存储的边界：一条坏数据只该让这一条常用项消失，
  /// 不能让设置整块读不出来。
  static QuickEntry? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }
}
