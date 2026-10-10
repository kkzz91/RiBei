import '../models/milestone.dart';
import 'app_database.dart';

class MilestoneDao {
  const MilestoneDao();

  /// 按起始日从早到晚排（最先开始的纪念日排前面，越老的纪念意义越大）
  Future<List<Milestone>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'milestones',
      orderBy: 'start_date ASC, created_at ASC',
    );
    return rows.map(Milestone.fromMap).toList();
  }

  Future<int> insert(Milestone milestone) async {
    final db = await AppDatabase.instance.database;
    final map = milestone.toMap()..remove('id');
    return db.insert('milestones', map);
  }

  Future<void> update(Milestone milestone) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'milestones',
      milestone.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[milestone.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'milestones',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
