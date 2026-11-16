// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/data/auth_storage.dart';
import 'package:waktu_tugas/data/cache.dart';
import 'package:waktu_tugas/data/planner_api.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

// =============================================================================
// FAKE SECURE STORAGE UNTUK MENGUJI PERSISTENSI SESI AMAN
// =============================================================================
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw Exception('Secure storage read error');
    return values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw Exception('Secure storage containsKey error');
    return values.containsKey(key);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw Exception('Secure storage write error');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) throw Exception('Secure storage delete error');
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// FAKE SQLITE DATABASE UNTUK MENGUJI CACHE LURING TERISOLASI PER USER
// =============================================================================
class FakeSqliteDatabase implements Database {
  final Map<String, Map<String, Object?>> snapshots = {};

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
      final row = snapshots[userId];
      return row == null ? [] : [Map<String, Object?>.from(row)];
    }
    return snapshots.values.map(Map<String, Object?>.from).toList();
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
    snapshots[userId] = Map<String, Object?>.from(values);
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
      return snapshots.remove(userId) != null ? 1 : 0;
    }
    final count = snapshots.length;
    snapshots.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// MOCK SUPABASE SERVER (AUTH + RPC DENGAN DUA USER TERISOLASI PENUH)
// =============================================================================
class MockSupabaseBackendServer extends http.BaseClient {
  bool networkOnline = true;
  final Map<String, bool> confirmedUsers = {}; // email -> confirmed
  final Map<String, String> userPasswords = {}; // email -> password
  final Map<String, String> userIdsByEmail = {}; // email -> userId
  final Map<String, String> userNamesByEmail = {}; // email -> fullName
  final Map<String, String> userTokens = {}; // token -> userId
  final Map<String, PlannerSnapshot> userSnapshots = {}; // userId -> snapshot

  String? _tokenFromAuthHeader(String? auth) {
    if (auth == null) return null;
    if (auth.startsWith('Bearer ')) return auth.substring(7).trim();
    if (auth.startsWith('bearer ')) return auth.substring(7).trim();
    return null;
  }

  Map<String, dynamic> _makeSession(String userId, String email, String name) {
    final exp =
        DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'sub': userId,
          'email': email,
          'role': 'authenticated',
          'exp': exp,
        }),
      ),
    );
    final token = '$header.$payload.signature-$userId';
    userTokens[token] = userId;
    return {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': exp,
      'refresh_token': 'refresh-$userId',
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': email,
        'app_metadata': {'provider': 'email'},
        'user_metadata': {'full_name': name},
        'created_at': '2026-11-09T00:00:00Z',
      },
    };
  }

  http.BaseRequest? _currentRequest;

  http.StreamedResponse _stream(http.Response res) => http.StreamedResponse(
    Stream.value(res.bodyBytes),
    res.statusCode,
    headers: res.headers,
    request: _currentRequest,
  );

  http.StreamedResponse _json(Object? body, {int status = 200}) => _stream(
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    ),
  );

  http.StreamedResponse _err(String code, String msg, {int status = 400}) =>
      _json({
        'code': code,
        'message': msg,
        'details': null,
        'hint': null,
      }, status: status);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _currentRequest = request;
    if (!networkOnline) {
      throw http.ClientException('Network is unreachable (Simulasi Offline)');
    }

    final path = request.url.path;
    final bodyStr = request is http.Request ? request.body : '';
    Map<String, dynamic> body = {};
    if (bodyStr.isNotEmpty) {
      final decoded = jsonDecode(bodyStr);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      }
    }

    // -------------------------------------------------------------------------
    // ENDPOINT AUTH: SIGNUP
    // -------------------------------------------------------------------------
    if (path.endsWith('/signup')) {
      final email = body['email'] as String;
      final pass = body['password'] as String;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final fullName = data['full_name'] as String? ?? 'Mahasiswa Uji';
      final userId = 'user-${email.split('@').first}';

      userIdsByEmail[email] = userId;
      userPasswords[email] = pass;
      userNamesByEmail[email] = fullName;
      confirmedUsers[email] = false; // Memerlukan konfirmasi email
      userSnapshots[userId] = PlannerSnapshot(
        revision: 0,
        tasks: [],
        timeWindows: [],
        activities: [],
        sessions: [],
      );

      return _json({
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': email,
        'app_metadata': {'provider': 'email'},
        'user_metadata': {'full_name': fullName},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    // -------------------------------------------------------------------------
    // ENDPOINT AUTH: RESEND CONFIRMATION
    // -------------------------------------------------------------------------
    if (path.endsWith('/resend')) {
      final email = body['email'] as String;
      if (!userIdsByEmail.containsKey(email)) {
        return _err('user_not_found', 'Pengguna tidak ditemukan', status: 404);
      }
      return _json({'message_id': 'msg-12345'});
    }

    // -------------------------------------------------------------------------
    // ENDPOINT AUTH: TOKEN / LOGIN
    // -------------------------------------------------------------------------
    if (path.endsWith('/token')) {
      final email = body['email'] as String?;
      final pass = body['password'] as String?;
      if (email == null || pass == null) {
        return _err('invalid_request', 'Email dan password wajib diisi');
      }
      if (userPasswords[email] != pass) {
        return _err('invalid_grant', 'Kredensial tidak valid', status: 400);
      }
      if (confirmedUsers[email] != true) {
        return _err('email_not_confirmed', 'Email belum dikonfirmasi', status: 400);
      }
      final userId = userIdsByEmail[email]!;
      final fullName = userNamesByEmail[email]!;
      return _json(_makeSession(userId, email, fullName));
    }

    // -------------------------------------------------------------------------
    // ENDPOINT AUTH: LOGOUT
    // -------------------------------------------------------------------------
    if (path.endsWith('/logout')) {
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];
    final token = _tokenFromAuthHeader(authHeader);
      if (token != null) userTokens.remove(token);
      return _stream(http.Response('', 204));
    }

    // -------------------------------------------------------------------------
    // ENDPOINT RPC POSTGREST DENGAN ROW LEVEL SECURITY SESUAI USER TOKEN
    // -------------------------------------------------------------------------
    final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];
    final token = _tokenFromAuthHeader(authHeader);
    final userId = token != null ? userTokens[token] : null;

    if (path.contains('/rpc/')) {
      if (userId == null) {
        return _err('PGRST301', 'JWT expired or unauthorized', status: 401);
      }
      final rpcName = path.split('/rpc/').last;
      final snap = userSnapshots[userId] ??
          PlannerSnapshot(revision: 0, tasks: [], timeWindows: [], activities: [], sessions: []);

      if (rpcName == 'get_planner_snapshot') {
        return _json(snap.toJson());
      }

      if (rpcName == 'save_task') {
        final expectedRev = body['p_expected_revision'] as int;
        if (expectedRev != snap.revision) {
          return _err('P0002', 'STALE_REVISION: Data telah berubah');
        }
        final nextRev = snap.revision + 1;
        final taskId = body['p_task_id'] as String? ?? 'task-$userId-$nextRev';
        final title = body['p_title'] as String;
        final course = body['p_course'] as String?;
        final deadline = DateTime.parse(body['p_deadline_at'] as String);
        final remaining = body['p_remaining_minutes'] as int;

        final existing = snap.tasks.any((t) => t.id == taskId);
        final nextTasks = [
          for (final t in snap.tasks)
            if (t.id == taskId)
              Task(
                id: taskId,
                title: title,
                course: course,
                deadlineAt: deadline,
                remainingMinutes: remaining,
                createdAt: t.createdAt,
              )
            else
              t,
          if (!existing)
            Task(
              id: taskId,
              title: title,
              course: course,
              deadlineAt: deadline,
              remainingMinutes: remaining,
              createdAt: DateTime.now().toUtc(),
            ),
        ];

        userSnapshots[userId] = PlannerSnapshot(
          revision: nextRev,
          tasks: nextTasks,
          timeWindows: snap.timeWindows,
          activities: snap.activities,
          sessions: snap.sessions,
        );
        return _json(nextRev);
      }

      if (rpcName == 'save_time_window') {
        final expectedRev = (body['p_expected_revision'] ?? body['expected_revision']) as int;
        if (expectedRev != snap.revision) {
          return _err('P0002', 'STALE_REVISION');
        }
        final nextRev = snap.revision + 1;
        final winId = (body['p_id'] ?? body['p_window_id']) as String? ?? 'win-$nextRev';
        final weekday = (body['p_weekday'] ?? body['p_day_of_week']) as int?;
        final date = (body['p_date'] ?? body['p_calendar_date']) as String?;
        final start = body['p_start_minute'] as int;
        final end = body['p_end_minute'] as int;

        final nextWindows = [
          ...snap.timeWindows.where((w) => w.id != winId),
          TimeWindow(
            id: winId,
            weekday: weekday,
            date: date,
            startMinute: start,
            endMinute: end,
          ),
        ];

        userSnapshots[userId] = PlannerSnapshot(
          revision: nextRev,
          tasks: snap.tasks,
          timeWindows: nextWindows,
          activities: snap.activities,
          sessions: snap.sessions,
        );
        return _json(nextRev);
      }

      if (rpcName == 'confirm_schedule') {
        final expectedRev = (body['input_revision'] ?? body['p_expected_revision']) as int;
        if (expectedRev != snap.revision) {
          return _err('P0002', 'STALE_REVISION');
        }
        final nextRev = snap.revision + 1;
        final rawSessions = (body['sessions'] ?? body['p_sessions']) as List<dynamic>? ?? [];

        final nextSessions = [
          for (final s in snap.sessions)
            if (s.status == SessionStatus.planned)
              PlannerSession(
                id: s.id,
                taskId: s.taskId,
                startsAt: s.startsAt,
                endsAt: s.endsAt,
                status: SessionStatus.cancelled,
              )
            else
              s,
          for (final (i, item) in rawSessions.indexed)
            PlannerSession(
              id: 'sess-$nextRev-$i',
              taskId: item['task_id'] as String,
              startsAt: DateTime.parse(item['starts_at'] as String),
              endsAt: DateTime.parse(item['ends_at'] as String),
              status: SessionStatus.planned,
            ),
        ];

        userSnapshots[userId] = PlannerSnapshot(
          revision: nextRev,
          tasks: snap.tasks,
          timeWindows: snap.timeWindows,
          activities: snap.activities,
          sessions: nextSessions,
        );
        return _json(nextRev);
      }

      if (rpcName == 'record_progress') {
        final expectedRev = body['p_expected_revision'] as int;
        if (expectedRev != snap.revision) {
          return _err('P0002', 'STALE_REVISION');
        }
        final sid = body['p_session_id'] as String;
        final target = snap.sessions.where((s) => s.id == sid).firstOrNull;
        if (target == null) {
          return _err('P0004', 'NOT_FOUND: Sesi tidak ditemukan');
        }
        if (target.status != SessionStatus.planned) {
          return _err('P0005', 'SESSION_ALREADY_CLOSED: Sesi sudah ditutup');
        }
        final nextRev = snap.revision + 1;
        final status = SessionStatus.values.byName(body['p_status'] as String);
        final rem = body['p_remaining_after'] as int?;

        userSnapshots[userId] = PlannerSnapshot(
          revision: nextRev,
          tasks: [
            for (final t in snap.tasks)
              if (t.id == target.taskId && status == SessionStatus.completed)
                t.withRemaining(rem!)
              else
                t,
          ],
          timeWindows: snap.timeWindows,
          activities: snap.activities,
          sessions: [
            for (final s in snap.sessions)
              if (s.id == sid)
                PlannerSession(
                  id: s.id,
                  taskId: s.taskId,
                  startsAt: s.startsAt,
                  endsAt: s.endsAt,
                  status: status,
                  remainingAfter: rem,
                  closedAt: DateTime.now().toUtc(),
                )
              else
                s,
          ],
        );
        return _json(nextRev);
      }
    }

    return _err('P0000', 'Not found: $path', status: 404);
  }
}

// =============================================================================
// MAIN TEST SUITE VERIFIKASI SIKLUS AUTH, SINKRONISASI, ISOLASI, DAN LURING
// =============================================================================
void main() {
  setUpAll(tz.initializeTimeZones);

  test(
    'Siklus Lengkap: Pendaftaran, Konfirmasi, Login, Pemulihan Sesi, Sinkronisasi CRUD, Isolasi 2 Akun, Cache Luring, dan Pergantian Akun',
    () async {
      final server = MockSupabaseBackendServer();
      final client = SupabaseClient(
        'https://mock-supabase.waktutugas.app',
        'mock-publishable-key',
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: server,
      );
      addTearDown(client.dispose);

      final rawStorage = FakeSecureStorage();
      final secureStorage = SecureLocalStorage(rawStorage);
      final rawDb = FakeSqliteDatabase();
      final localCache = LocalCache(rawDb);
      final connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(connectivityController.close);

      final planner = PlannerController(
        api: PlannerApi(client),
        cache: localCache,
        connectivityStream: connectivityController.stream,
      );
      addTearDown(planner.dispose);

      final auth = AuthController(
        client: client,
        cache: localCache,
        storage: secureStorage,
        onSessionCleared: planner.clear,
      );
      addTearDown(auth.dispose);

      // =======================================================================
      // 1. PENDAFTARAN & KONFIRMASI EMAIL
      // =======================================================================
      // A. Mendaftar akun A
      final registeredA = await auth.register(
        'Mahasiswa Uji A',
        'mhs_a@campus.ac.id',
        'Password123!',
      );
      expect(registeredA, isTrue, reason: 'Gagal register: ${auth.error}');
      expect(auth.signedIn, isFalse, reason: 'Harus tetap signedOut sebelum konfirmasi email');
      expect(await auth.resendConfirmation('mhs_a@campus.ac.id'), isTrue);

      // B. Login sebelum konfirmasi email harus ditolak
      final loginBeforeConfirm = await auth.signIn('mhs_a@campus.ac.id', 'Password123!');
      expect(loginBeforeConfirm, isFalse);
      expect(auth.error, contains('belum dikonfirmasi'));

      // C. Verifikasi konfirmasi email
      server.confirmedUsers['mhs_a@campus.ac.id'] = true;

      // =======================================================================
      // 2. LOGIN & PEMULIHAN SESI (RESTORE SESSION DARI SECURE STORAGE)
      // =======================================================================
      final loggedInA = await auth.signIn('mhs_a@campus.ac.id', 'Password123!');
      expect(loggedInA, isTrue);
      expect(auth.signedIn, isTrue);
      expect(auth.userId, 'user-mhs_a');
      expect(auth.email, 'mhs_a@campus.ac.id');
      expect(auth.userName, 'Mahasiswa Uji A');
      expect(await secureStorage.hasAccessToken(), isTrue, reason: 'Token sesi tersimpan di storage');

      planner.bindUser(auth.userId);
      expect(
        await planner.fetchSnapshot(userId: auth.userId),
        isTrue,
        reason: 'Fetch snapshot failed: ${planner.errorCode} - ${planner.error}',
      );

      // =======================================================================
      // 3. SINKRONISASI TUGAS, WAKTU, JADWAL, DAN PROGRES PADA AKUN A
      // =======================================================================
      final deadlineA = DateTime.utc(2026, 11, 15, 12);
      expect(
        await planner.saveTask(
          title: 'Tugas Pemrograman Mobile Akun A',
          course: 'IF301',
          deadline: deadlineA,
          remaining: 180,
        ),
        isTrue,
      );
      expect(planner.snapshot.tasks.length, 1);
      final taskIdA = planner.snapshot.tasks.first.id;

      // Tambah waktu belajar
      expect(
        await planner.saveWindow(
          TimeWindow(
            id: 'win-a1',
            date: '2026-11-10',
            startMinute: 1140, // 19:00
            endMinute: 1320,   // 22:00 (180 menit)
          ),
        ),
        isTrue,
      );
      expect(planner.snapshot.timeWindows.length, 1);

      // Hitung dan konfirmasi jadwal
      expect(await planner.generatePreview(), isTrue);
      expect(planner.preview!.sessions.length, 1);
      expect(await planner.confirmSchedule(), isTrue);
      expect(planner.snapshot.sessions.length, 1);
      expect(planner.snapshot.sessions.first.status, SessionStatus.planned);

      // Catat progres sesi 1 (selesai dengan sisa 90 menit)
      final session1A = planner.snapshot.sessions.first;
      expect(
        await planner.recordProgress(session1A.id, SessionStatus.completed, 90),
        isTrue,
      );
      expect(planner.snapshot.tasks.first.remainingMinutes, 90);
      expect(planner.sessionById(session1A.id)!.status, SessionStatus.completed);
      expect(planner.sessionById(session1A.id)!.remainingAfter, 90);

      // Verifikasi data tersinkronisasi ke server mock
      final serverSnapA = server.userSnapshots['user-mhs_a']!;
      expect(serverSnapA.tasks.single.remainingMinutes, 90);
      expect(serverSnapA.sessions.first.status, SessionStatus.completed);

      // =======================================================================
      // 4. PEMULIHAN SESI SETELAH APLIKASI DITUTUP & DIBUKA KEMBALI
      // =======================================================================
      // Buat instance AuthController dan PlannerController baru (simulasi restart)
      final authRestarted = AuthController(
        client: client,
        cache: localCache,
        storage: secureStorage,
        onSessionCleared: planner.clear,
      );
      addTearDown(authRestarted.dispose);

      await authRestarted.restoreSession();
      expect(authRestarted.signedIn, isTrue);
      expect(authRestarted.userId, 'user-mhs_a');
      expect(authRestarted.email, 'mhs_a@campus.ac.id');

      final plannerRestarted = PlannerController(
        api: PlannerApi(client),
        cache: localCache,
        userId: authRestarted.userId,
      );
      addTearDown(plannerRestarted.dispose);

      expect(await plannerRestarted.fetchSnapshot(userId: authRestarted.userId), isTrue);
      expect(plannerRestarted.snapshot.tasks.length, 1);
      expect(plannerRestarted.snapshot.tasks.single.title, 'Tugas Pemrograman Mobile Akun A');
      expect(plannerRestarted.snapshot.tasks.single.remainingMinutes, 90);
      expect(plannerRestarted.snapshot.sessions.length, 1);
      expect(plannerRestarted.sessionById(session1A.id)!.status, SessionStatus.completed);
      expect(plannerRestarted.sessionById(session1A.id)!.remainingAfter, 90);

      // =======================================================================
      // 5. UJI KONEKSI TERPUTUS, CACHE LURING HANYA BACA, DAN KONEKSI PULIH
      // =======================================================================
      // A. Simpan data Akun A ke cache lokal
      final cacheTimestamp = DateTime.utc(2026, 11, 10, 10);
      await localCache.writeCachedSnapshot('user-mhs_a', plannerRestarted.snapshot, cacheTimestamp);

      // B. Putuskan koneksi (offline)
      server.networkOnline = false;

      // C. Controller membaca data dari cache saat offline
      final plannerOffline = PlannerController(
        api: PlannerApi(client),
        cache: localCache,
        userId: 'user-mhs_a',
        connectivityStream: connectivityController.stream,
      );
      addTearDown(plannerOffline.dispose);

      expect(await plannerOffline.fetchSnapshot(userId: 'user-mhs_a'), isTrue);
      expect(plannerOffline.isOfflineSnapshot, isTrue);
      expect(plannerOffline.fetchedAt, cacheTimestamp);
      expect(plannerOffline.snapshot.tasks.length, 1);
      expect(plannerOffline.snapshot.tasks.single.title, 'Tugas Pemrograman Mobile Akun A');

      // D. Mode luring hanya baca: seluruh mutasi dan pratinjau diblokir aman
      final offlineSaveTask = await plannerOffline.saveTask(
        title: 'Tugas Baru Saat Offline',
        course: null,
        deadline: DateTime.utc(2026, 11, 20),
        remaining: 60,
      );
      expect(offlineSaveTask, isFalse);
      expect(plannerOffline.errorCode, 'OFFLINE');
      expect(plannerOffline.error, contains('Mode luring'));

      final offlinePreview = await plannerOffline.generatePreview();
      expect(offlinePreview, isFalse);
      expect(plannerOffline.errorCode, 'OFFLINE');

      // E. Koneksi pulih (online recovery)
      server.networkOnline = true;
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await plannerOffline.fetchSnapshot(userId: 'user-mhs_a'), isTrue);
      expect(plannerOffline.isOfflineSnapshot, isFalse, reason: 'Keluar dari mode luring setelah jaringan pulih');

      // =======================================================================
      // 6. PERGANTIAN AKUN: PEMBERSIHAN MEMORI, TAMPILAN, DAN ISOLASI DATA
      // =======================================================================
      // A. Akun A Logout
      expect(await authRestarted.logout(), isTrue);
      expect(authRestarted.signedIn, isFalse);
      expect(authRestarted.userId, isNull);
      expect(await secureStorage.hasAccessToken(), isFalse);
      // Memori PlannerController langsung dibersihkan oleh onSessionCleared
      expect(planner.snapshot.tasks, isEmpty);
      expect(planner.snapshot.sessions, isEmpty);

      // B. Daftarkan dan konfirmasi Akun B
      expect(
        await auth.register(
          'Mahasiswa Uji B',
          'mhs_b@campus.ac.id',
          'Password456!',
        ),
        isTrue,
      );
      server.confirmedUsers['mhs_b@campus.ac.id'] = true;

      // C. Akun B Login
      expect(await auth.signIn('mhs_b@campus.ac.id', 'Password456!'), isTrue);
      expect(auth.signedIn, isTrue);
      expect(auth.userId, 'user-mhs_b');
      expect(auth.userName, 'Mahasiswa Uji B');

      planner.bindUser(auth.userId);
      expect(
        await planner.fetchSnapshot(userId: auth.userId),
        isTrue,
        reason: 'Fetch snapshot failed: ${planner.errorCode} - ${planner.error}',
      );

      // D. Verifikasi Isolasi: Akun B tidak melihat tugas atau sesi Akun A
      expect(
        planner.snapshot.tasks.where((t) => t.id == taskIdA),
        isEmpty,
        reason: 'Data tugas Akun A TIDAK BOLEH terlihat di Akun B',
      );
      expect(planner.snapshot.tasks, isEmpty);
      expect(planner.snapshot.sessions, isEmpty);

      // E. Akun B membuat tugas sendiri
      expect(
        await planner.saveTask(
          title: 'Tugas Riset AI Akun B',
          course: 'CS401',
          deadline: DateTime.utc(2026, 11, 18, 12),
          remaining: 120,
        ),
        isTrue,
      );
      expect(planner.snapshot.tasks.length, 1);
      expect(planner.snapshot.tasks.single.title, 'Tugas Riset AI Akun B');

      // F. Upaya Akun B mengakses/mengedit tugas Akun A ditolak oleh backend
      final apiB = PlannerApi(client);
      expect(
        () => apiB.saveTask(
          taskId: taskIdA, // ID milik Akun A
          title: 'Penyusupan Akun B',
          course: null,
          deadlineAt: DateTime.utc(2026, 11, 20),
          remainingMinutes: 10,
          expectedRevision: 0,
        ),
        throwsA(isA<PlannerApiException>()),
        reason: 'Backend menolak modifikasi data milik akun lain',
      );

      // Data Akun A di server tetap utuh tanpa tercemar
      expect(
        server.userSnapshots['user-mhs_a']!.tasks.single.title,
        'Tugas Pemrograman Mobile Akun A',
      );
      expect(server.userSnapshots['user-mhs_a']!.tasks.single.remainingMinutes, 90);

      // G. Pembersihan cache akun sebelumnya & isolasi cache akun baru
      final cacheA = await localCache.readCachedSnapshot('user-mhs_a');
      expect(
        cacheA,
        isNull,
        reason: 'Logout Akun A membersihkan cache lokal agar tidak terlihat oleh Akun B',
      );

      await localCache.writeCachedSnapshot('user-mhs_b', planner.snapshot, DateTime.now().toUtc());
      final cacheB = await localCache.readCachedSnapshot('user-mhs_b');
      expect(cacheB, isNotNull);
      expect(cacheB!.snapshot.tasks.single.title, 'Tugas Riset AI Akun B');
      expect(cacheB.snapshot.tasks.single.id, isNot(taskIdA));
    },
  );
}
