import '../utils/categories.dart';

/// 一笔账
class TransactionRecord {
  const TransactionRecord({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
    required this.date,
    this.payMethod = PayMethod.unknown,
    required this.createdAt,
  });

  final int? id;

  /// 金额，始终为正数；方向由 [type] 决定。
  final double amount;

  /// 0 = 支出，1 = 收入
  final int type;

  final String category;
  final String note;

  /// 记账日期（只用到年月日）
  final DateTime date;

  /// 支付方式，见 [PayMethod]；-1 表示这笔账没记过支付方式（老数据）
  final int payMethod;

  final DateTime createdAt;

  bool get isExpense => type == 0;

  /// 带符号的金额，用于明细展示
  double get signedAmount => isExpense ? -amount : amount;

  TransactionRecord copyWith({
    int? id,
    double? amount,
    int? type,
    String? category,
    String? note,
    DateTime? date,
    int? payMethod,
    DateTime? createdAt,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      payMethod: payMethod ?? this.payMethod,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'amount': amount,
    'type': type,
    'category': category,
    'note': note,
    'date': date.millisecondsSinceEpoch,
    'payment_method': payMethod,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static TransactionRecord fromMap(Map<String, Object?> m) => TransactionRecord(
    id: m['id'] as int?,
    amount: (m['amount'] as num).toDouble(),
    type: m['type'] as int,
    category: m['category'] as String,
    note: (m['note'] as String?) ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    payMethod: m['payment_method'] as int? ?? PayMethod.unknown,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );
}
