import '../models/countdown_event.dart';
import 'app_database.dart';

class CountdownDao {
  const CountdownDao();

  /// 未过期在前、越近越靠前；已过期的排到最后。
  Future<List<CountdownEvent>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'countdown_events',
      orderBy: 'target_date ASC, created_at DESC',
    );
    return rows.map(CountdownEvent.fromMap).toList();
  }

  Future<CountdownEvent?> byId(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'countdown_events',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CountdownEvent.fromMap(rows.first);
  }

  Future<int> insert(CountdownEvent event) async {
    final db = await AppDatabase.instance.database;
    final map = event.toMap()..remove('id');
    return db.insert('countdown_events', map);
  }

  Future<void> update(CountdownEvent event) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'countdown_events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[event.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'countdown_events',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 清空全部倒计时，返回删掉的条数
  Future<int> deleteAll() async {
    final db = await AppDatabase.instance.database;
    return db.delete('countdown_events');
  }
}
