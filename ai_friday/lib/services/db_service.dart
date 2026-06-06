import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/message.dart';
import '../utils/logger.dart';

/// Локальное хранилище истории диалога (sqflite).
class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'friday.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE messages(id TEXT PRIMARY KEY, role TEXT, text TEXT, ts INTEGER)',
        );
      },
    );
    return _db!;
  }

  Future<void> insert(Message m) async {
    try {
      final db = await _open();
      await db.insert(
        'messages',
        {
          'id': m.id,
          'role': m.role.name,
          'text': m.text,
          'ts': m.timestamp.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      AppLogger.error('DB insert failed', e);
    }
  }

  Future<List<Message>> getRecent({int limit = 300}) async {
    try {
      final db = await _open();
      final rows = await db.query('messages', orderBy: 'ts ASC', limit: limit);
      return rows
          .map((r) => Message(
                id: r['id'] as String,
                text: r['text'] as String,
                role: MessageRole.values.byName(r['role'] as String),
                timestamp: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
              ))
          .toList();
    } catch (e) {
      AppLogger.error('DB getRecent failed', e);
      return [];
    }
  }

  Future<void> clear() async {
    try {
      final db = await _open();
      await db.delete('messages');
    } catch (e) {
      AppLogger.error('DB clear failed', e);
    }
  }
}
