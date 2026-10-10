import '../models/todo_item.dart';
import 'app_database.dart';

class TodoDao {
  const TodoDao();

  /// 未完成在前、按到期时间由近及远；已完成的按完成时间倒序靠后。
  Future<List<TodoItem>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('todos', orderBy: 'done ASC, due_at ASC');
    return rows.map(TodoItem.fromMap).toList();
  }

  Future<int> insert(TodoItem todo) async {
    final db = await AppDatabase.instance.database;
    final map = todo.toMap()..remove('id');
    return db.insert('todos', map);
  }

  Future<void> update(TodoItem todo) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[todo.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('todos', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// 清空全部待办，返回删掉的条数
  Future<int> deleteAll() async {
    final db = await AppDatabase.instance.database;
    return db.delete('todos');
  }
}
