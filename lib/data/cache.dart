import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../planner/models.dart';

class CachedSnapshot {
  final PlannerSnapshot snapshot;
  final DateTime fetchedAt;

  const CachedSnapshot({required this.snapshot, required this.fetchedAt});
}

/// Cache luring lokal SQLite per user_id
/// Sesuai PRD Bagian 9.2 (read-only cache, tidak menyimpan token/kredensial)
class LocalCache {
  final Database _db;

  const LocalCache(this._db);

  static Future<LocalCache> initialize({String? path}) async {
    final dbPath = path ?? 'waktu_tugas_cache.db';
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE snapshots (
            user_id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            fetched_at TEXT NOT NULL
          )
        ''');
      },
    );
    return LocalCache(db);
  }

  Future<CachedSnapshot?> readCachedSnapshot(String userId) async {
    final rows = await _db.query(
      'snapshots',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    final payloadStr = row['payload'] as String;
    final fetchedAtStr = row['fetched_at'] as String;

    try {
      final json = jsonDecode(payloadStr) as Map<String, dynamic>;
      final snapshot = PlannerSnapshot.fromJson(json);
      final fetchedAt = DateTime.parse(fetchedAtStr).toUtc();
      return CachedSnapshot(snapshot: snapshot, fetchedAt: fetchedAt);
    } catch (_) {
      // Jika cache korup, bersihkan baris pengguna ini
      await clearCache(userId);
      return null;
    }
  }

  Future<void> writeCachedSnapshot(
    String userId,
    PlannerSnapshot snapshot,
    DateTime fetchedAt,
  ) async {
    final payloadStr = jsonEncode(snapshot.toJson());
    final fetchedAtStr = fetchedAt.toUtc().toIso8601String();

    await _db.insert('snapshots', {
      'user_id': userId,
      'payload': payloadStr,
      'fetched_at': fetchedAtStr,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearCache(String userId) async {
    await _db.delete('snapshots', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> clearAll() async {
    await _db.delete('snapshots');
  }
}
