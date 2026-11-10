import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/data/cache.dart';
import 'package:waktu_tugas/data/planner_api.dart';
import 'package:waktu_tugas/planner/fixtures.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

/// Fake SQLite Database implementing the exact query/insert/delete contract used by LocalCache.
class FakeSqliteDatabase implements Database {
  final Map<String, Map<String, Object?>> _snapshots = {};

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    assert(table == 'snapshots');
    if (where == 'user_id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
      final userId = whereArgs.first as String;
      final row = _snapshots[userId];
      return row == null ? [] : [Map<String, Object?>.from(row)];
    }
    return _snapshots.values.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    assert(table == 'snapshots');
    final userId = values['user_id'] as String;
    _snapshots[userId] = Map<String, Object?>.from(values);
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    assert(table == 'snapshots');
    if (where == 'user_id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
      final userId = whereArgs.first as String;
      return _snapshots.remove(userId) != null ? 1 : 0;
    }
    final count = _snapshots.length;
    _snapshots.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControllableApi extends PlannerApi {
  Future<PlannerSnapshot> Function() onFetch;
  ControllableApi(super.client, this.onFetch);

  @override
  Future<PlannerSnapshot> fetchSnapshot() => onFetch();
}

void main() {
  setUpAll(tz.initializeTimeZones);

  test(
    'cache_wrong_user, corrupted_cache cleanup, and per-account isolation',
    () async {
      final db = FakeSqliteDatabase();
      final cache = LocalCache(db);
      final snapA = demoSnapshot();
      final fetchedAt = DateTime.utc(2026, 11, 9, 11, 30);

      await cache.writeCachedSnapshot('user-a', snapA, fetchedAt);

      // 1. User A reads own cached snapshot with UTC fetchedAt
      final readA = await cache.readCachedSnapshot('user-a');
      expect(readA, isNotNull);
      expect(readA!.fetchedAt, fetchedAt);
      expect(readA.snapshot.toJson(), snapA.toJson());

      // 2. cache_wrong_user: User B never receives User A's cached snapshot
      expect(await cache.readCachedSnapshot('user-b'), isNull);

      // 3. Corrupted cache row for User A is cleaned automatically without affecting User B
      await cache.writeCachedSnapshot('user-b', snapA, fetchedAt);
      await db.insert('snapshots', {
        'user_id': 'user-a',
        'payload': '{corrupted-json',
        'fetched_at': fetchedAt.toIso8601String(),
      });
      expect(await cache.readCachedSnapshot('user-a'), isNull);
      expect(
        await db.query(
          'snapshots',
          where: 'user_id = ?',
          whereArgs: ['user-a'],
        ),
        isEmpty,
      );
      expect(await cache.readCachedSnapshot('user-b'), isNotNull);
    },
  );

  test(
    'offline read-only fallback, late response after account switch discarded, and connectivity recovery',
    () async {
      final db = FakeSqliteDatabase();
      final cache = LocalCache(db);
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);

      final completerA = Completer<PlannerSnapshot>();
      var online = false;
      final api = ControllableApi(client, () async {
        if (!completerA.isCompleted) {
          return completerA.future;
        }
        if (!online) {
          throw const PlannerApiException(
            code: 'UNKNOWN_ERROR',
            message: 'Offline',
          );
        }
        return demoSnapshot();
      });

      final connectivity = StreamController<List<ConnectivityResult>>();
      addTearDown(connectivity.close);

      final p = PlannerController(
        api: api,
        cache: cache,
        userId: 'user-a',
        connectivityStream: connectivity.stream,
      );
      addTearDown(p.dispose);

      // 1. Start slow request for User A, then switch to User B before it finishes
      final pendingA = p.fetchSnapshot(userId: 'user-a');
      p.bindUser('user-b');
      completerA.complete(demoSnapshot());
      expect(await pendingA, isFalse);
      expect(
        p.snapshot.tasks,
        isEmpty,
        reason: 'Late response from User A must not enter User B state',
      );
      expect(
        await cache.readCachedSnapshot('user-a'),
        isNull,
        reason: 'Late response from User A must not be written after switch',
      );

      // 2. Seed cache for User B and verify offline fallback + write blocking
      final cachedTime = DateTime.utc(2026, 11, 9, 10);
      await cache.writeCachedSnapshot('user-b', demoSnapshot(), cachedTime);
      expect(await p.fetchSnapshot(userId: 'user-b'), isTrue);
      expect(p.isOfflineSnapshot, isTrue);
      expect(p.fetchedAt, cachedTime);
      expect(p.snapshot.tasks.length, 3);

      // Mutations and preview generation are blocked while offline
      expect(
        await p.saveTask(
          title: 'Offline Task',
          course: null,
          deadline: demoNow.add(const Duration(days: 1)),
          remaining: 60,
        ),
        isFalse,
      );
      expect(p.errorCode, 'OFFLINE');
      expect(await p.generatePreview(), isFalse);
      expect(p.errorCode, 'OFFLINE');

      // 3. When connectivity returns, controller refreshes from server and exits offline mode
      online = true;
      connectivity.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(p.isOfflineSnapshot, isFalse);
    },
  );
}
