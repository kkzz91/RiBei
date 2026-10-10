import '../models/transaction_record.dart';
import 'app_database.dart';

class TransactionDao {
  const TransactionDao();

  Future<List<TransactionRecord>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(TransactionRecord.fromMap).toList();
  }

  Future<int> insert(TransactionRecord record) async {
    final db = await AppDatabase.instance.database;
    final map = record.toMap()..remove('id');
    return db.insert('transactions', map);
  }

  Future<void> update(TransactionRecord record) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'transactions',
      record.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[record.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// 清空全部账目，返回删掉的条数
  Future<int> deleteAll() async {
    final db = await AppDatabase.instance.database;
    return db.delete('transactions');
  }

  /// 清空某一天的账目（按记账日期的当天零点到次日零点），返回删掉的条数
  Future<int> deleteOn(DateTime day) async {
    final db = await AppDatabase.instance.database;
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return db.delete(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: <Object?>[
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
  }
}
