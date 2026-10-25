import '../../core/constants/storage_constants.dart';
import '../database.dart';
import '../models/task.dart';

class TaskRepository {
  Future<int> add(Task task) async {
    final db = await AppDatabase.instance.database;
    return db.insert(StorageConstants.tasksTable, task.toMap()..remove('id'));
  }

  Future<List<Task>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      StorageConstants.tasksTable,
      orderBy: 'created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<void> complete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      StorageConstants.tasksTable,
      {
        'status': 'done',
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
