// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/data/planner_api.dart';
import 'package:waktu_tugas/planner/fixtures.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class MockRpcHttpClient extends http.BaseClient {
  Future<http.Response> Function(
    String rpcName,
    Map<String, dynamic> body,
    http.BaseRequest request,
  )
  onRpc;

  MockRpcHttpClient(this.onRpc);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final segments = request.url.pathSegments;
    final rpcIndex = segments.indexOf('rpc');
    final rpcName = rpcIndex >= 0 && rpcIndex + 1 < segments.length
        ? segments[rpcIndex + 1]
        : '';
    var bodyMap = <String, dynamic>{};
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map<String, dynamic>) {
        bodyMap = decoded;
      }
    }
    final response = await onRpc(rpcName, bodyMap, request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

http.Response _jsonResponse(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _postgrestError({
  required String code,
  required String message,
  int status = 400,
}) => _jsonResponse({
  'code': code,
  'message': message,
  'details': null,
  'hint': null,
}, status: status);

void main() {
  setUpAll(tz.initializeTimeZones);

  test(
    'PlannerApi maps SQL/PostgREST error codes, malformed responses, and RPC parameters without user_id',
    () async {
      final calls = <MapEntry<String, Map<String, dynamic>>>[];
      late Future<http.Response> Function(String, Map<String, dynamic>)
      responder;

      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockRpcHttpClient((name, body, _) {
          calls.add(MapEntry(name, body));
          return responder(name, body);
        }),
      );
      addTearDown(client.dispose);
      final api = PlannerApi(client);

      // 1. Valid snapshot and mutations
      responder = (name, body) async {
        if (name == 'get_planner_snapshot') {
          return _jsonResponse(demoSnapshot().toJson());
        }
        return _jsonResponse(1);
      };

      final snap = await api.fetchSnapshot();
      expect(snap.tasks.length, 3);
      expect(
        await api.saveTask(
          taskId: null,
          title: 'Tugas API',
          course: 'PBP',
          deadlineAt: demoNow.add(const Duration(days: 2)),
          remainingMinutes: 90,
          expectedRevision: 0,
        ),
        1,
      );
      expect(calls.last.key, 'save_task');
      expect(calls.last.value.containsKey('user_id'), isFalse);
      expect(calls.last.value['p_expected_revision'], 0);

      // 2. Error code mapping (UNAUTHENTICATED, FORBIDDEN, STALE_REVISION, VALIDATION_ERROR, NOT_FOUND, SESSION_ALREADY_CLOSED)
      final errorCases = [
        ('P0001', 'UNAUTHENTICATED', 'UNAUTHENTICATED'),
        ('42501', 'permission denied for table tasks', 'FORBIDDEN'),
        ('P0002', 'STALE_REVISION', 'STALE_REVISION'),
        (
          'P0003',
          'VALIDATION_ERROR: Judul tugas harus 1-120 karakter',
          'VALIDATION_ERROR',
        ),
        ('P0004', 'NOT_FOUND: Tugas tidak ditemukan', 'NOT_FOUND'),
        (
          'P0005',
          'SESSION_ALREADY_CLOSED: Sesi sudah ditutup sebelumnya',
          'SESSION_ALREADY_CLOSED',
        ),
      ];

      for (final (sqlCode, sqlMsg, expectedCode) in errorCases) {
        responder = (_, _) async =>
            _postgrestError(code: sqlCode, message: sqlMsg);
        await expectLater(
          () => api.fetchSnapshot(),
          throwsA(
            isA<PlannerApiException>().having(
              (e) => e.code,
              'code',
              expectedCode,
            ),
          ),
        );
      }

      // 3. Malformed response handling
      responder = (_, _) async => _jsonResponse(['not-a-map']);
      await expectLater(
        () => api.fetchSnapshot(),
        throwsA(
          isA<PlannerApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );

      responder = (_, _) async => _jsonResponse(-5);
      await expectLater(
        () => api.deleteTask(taskId: 'T01', expectedRevision: 0),
        throwsA(
          isA<PlannerApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
    },
  );

  test(
    'timeout_unknown reloads snapshot without automatic mutation retry; stale_revision requires new preview',
    () async {
      var saveAttempts = 0;
      var snapshotCalls = 0;
      var serverRevision = 0;

      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockRpcHttpClient((name, body, _) async {
          if (name == 'get_planner_snapshot') {
            snapshotCalls++;
            final base = demoSnapshot();
            return _jsonResponse(
              PlannerSnapshot(
                revision: serverRevision,
                tasks: base.tasks,
                timeWindows: base.timeWindows,
                activities: base.activities,
                sessions: base.sessions,
              ).toJson(),
            );
          }
          if (name == 'save_task') {
            saveAttempts++;
            // Simulate server committing the write just before client timeout
            serverRevision = 1;
            throw TimeoutException('Simulated 15s timeout');
          }
          if (name == 'confirm_schedule') {
            // Simulate concurrent change on another device raising P0002
            serverRevision = 2;
            return _postgrestError(code: 'P0002', message: 'STALE_REVISION');
          }
          return _jsonResponse(serverRevision);
        }),
      );
      addTearDown(client.dispose);

      final p = PlannerController(api: PlannerApi(client), userId: 'user-a');
      expect(await p.fetchSnapshot(), isTrue);
      expect(p.snapshot.revision, 0);
      snapshotCalls = 0;

      // 1. Timeout on saveTask: must NOT retry save_task, MUST reload snapshot once, and return false with TIMEOUT code
      final ok = await p.saveTask(
        title: 'Tugas Timeout',
        course: null,
        deadline: demoNow.add(const Duration(days: 1)),
        remaining: 60,
      );
      expect(ok, isFalse);
      expect(saveAttempts, 1, reason: 'No blind automatic retry on timeout');
      expect(
        snapshotCalls,
        1,
        reason: 'Reloads server snapshot after timeout to verify state',
      );
      expect(p.errorCode, 'TIMEOUT');
      expect(p.snapshot.revision, 1);

      // 2. Stale revision on confirmSchedule: reloads snapshot so preview becomes stale and must be regenerated
      expect(await p.generatePreview(), isTrue);
      expect(p.preview!.inputRevision, 1);
      expect(await p.confirmSchedule(), isFalse);
      expect(p.errorCode, 'STALE_REVISION');
      expect(p.snapshot.revision, 2);
      expect(
        p.preview!.inputRevision != p.snapshot.revision,
        isTrue,
        reason: 'Preview is now marked stale relative to reloaded revision',
      );
    },
  );

  test(
    'full cloud flow: login to progress update, duplicate progress rejection, and two-account isolation',
    () async {
      var activeToken = 'token-a';
      final stateByUser = <String, PlannerSnapshot>{
        'token-a': PlannerSnapshot(
          revision: 0,
          tasks: [],
          timeWindows: [],
          activities: [],
          sessions: [],
        ),
        'token-b': PlannerSnapshot(
          revision: 0,
          tasks: [],
          timeWindows: [],
          activities: [],
          sessions: [],
        ),
      };

      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockRpcHttpClient((name, body, _) async {
          final current = stateByUser[activeToken]!;
          int expectRev(String key) {
            final expected = body[key] as int?;
            if (expected != current.revision) {
              throw PostgrestException(
                message: 'STALE_REVISION',
                code: 'P0002',
              );
            }
            return current.revision + 1;
          }

          try {
            if (name == 'get_planner_snapshot') {
              return _jsonResponse(current.toJson());
            }
            if (name == 'save_task') {
              final nextRev = expectRev('p_expected_revision');
              final taskId = body['p_task_id'] as String?;
              if (taskId != null && !current.tasks.any((t) => t.id == taskId)) {
                return _postgrestError(
                  code: 'P0004',
                  message: 'NOT_FOUND: Tugas tidak ditemukan',
                );
              }
              final task = Task(
                id: taskId ?? 'task-a-1',
                title: body['p_title'] as String,
                course: body['p_course'] as String?,
                deadlineAt: DateTime.parse(body['p_deadline_at'] as String),
                remainingMinutes: body['p_remaining_minutes'] as int,
                createdAt: demoNow,
              );
              stateByUser[activeToken] = PlannerSnapshot(
                revision: nextRev,
                tasks: [
                  for (final t in current.tasks)
                    if (t.id == task.id) task else t,
                  if (taskId == null) task,
                ],
                timeWindows: current.timeWindows,
                activities: current.activities,
                sessions: current.sessions,
              );
              return _jsonResponse(nextRev);
            }
            if (name == 'save_time_window') {
              final nextRev = expectRev('p_expected_revision');
              final win = TimeWindow(
                id: (body['p_id'] as String?) ?? 'win-a-1',
                weekday: body['p_weekday'] as int?,
                date: body['p_date'] as String?,
                startMinute: body['p_start_minute'] as int,
                endMinute: body['p_end_minute'] as int,
              );
              stateByUser[activeToken] = PlannerSnapshot(
                revision: nextRev,
                tasks: current.tasks,
                timeWindows: [...current.timeWindows, win],
                activities: current.activities,
                sessions: current.sessions,
              );
              return _jsonResponse(nextRev);
            }
            if (name == 'confirm_schedule') {
              final nextRev = expectRev('input_revision');
              final rawSessions = (body['sessions'] as List)
                  .cast<Map<String, dynamic>>();
              final nextSessions = [
                for (final s in current.sessions)
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
              stateByUser[activeToken] = PlannerSnapshot(
                revision: nextRev,
                tasks: current.tasks,
                timeWindows: current.timeWindows,
                activities: current.activities,
                sessions: nextSessions,
              );
              return _jsonResponse(nextRev);
            }
            if (name == 'record_progress') {
              final nextRev = expectRev('p_expected_revision');
              final sid = body['p_session_id'] as String;
              final target = current.sessions
                  .where((s) => s.id == sid)
                  .firstOrNull;
              if (target == null) {
                return _postgrestError(
                  code: 'P0004',
                  message: 'NOT_FOUND: Sesi tidak ditemukan',
                );
              }
              if (target.status != SessionStatus.planned) {
                return _postgrestError(
                  code: 'P0005',
                  message: 'SESSION_ALREADY_CLOSED',
                );
              }
              final status = SessionStatus.values.byName(
                body['p_status'] as String,
              );
              final rem = body['p_remaining_after'] as int?;
              stateByUser[activeToken] = PlannerSnapshot(
                revision: nextRev,
                tasks: [
                  for (final t in current.tasks)
                    if (t.id == target.taskId &&
                        status == SessionStatus.completed)
                      t.withRemaining(rem!)
                    else
                      t,
                ],
                timeWindows: current.timeWindows,
                activities: current.activities,
                sessions: [
                  for (final s in current.sessions)
                    if (s.id == sid)
                      PlannerSession(
                        id: s.id,
                        taskId: s.taskId,
                        startsAt: s.startsAt,
                        endsAt: s.endsAt,
                        status: status,
                        remainingAfter: rem,
                        closedAt: demoNow.add(const Duration(hours: 2)),
                      )
                    else
                      s,
                ],
              );
              return _jsonResponse(nextRev);
            }
            return _jsonResponse(current.revision);
          } on PostgrestException catch (e) {
            return _postgrestError(code: e.code ?? 'P0000', message: e.message);
          }
        }),
      );
      addTearDown(client.dispose);

      var currentClock = demoNow;
      final p = PlannerController(
        clock: () => currentClock,
        api: PlannerApi(client),
        userId: 'user-a',
      );
      addTearDown(p.dispose);

      // Account A: fetch empty snapshot, add task & window, preview, confirm, record progress
      expect(await p.fetchSnapshot(userId: 'user-a'), isTrue);
      expect(
        await p.saveTask(
          title: 'Tugas Backend A',
          course: 'PBP',
          deadline: DateTime.utc(2026, 11, 11, 11),
          remaining: 120,
        ),
        isTrue,
      );
      expect(
        await p.saveWindow(
          TimeWindow(
            id: 'new-win',
            date: '2026-11-09',
            startMinute: 1140,
            endMinute: 1260,
          ),
        ),
        isTrue,
      );
      expect(await p.generatePreview(), isTrue);
      expect(p.preview!.sessions.length, 1);
      expect(await p.confirmSchedule(), isTrue);
      expect(p.snapshot.sessions.single.status, SessionStatus.planned);

      // Move clock past session start and close progress once
      final sessionId = p.snapshot.sessions.single.id;
      currentClock = p.snapshot.sessions.single.startsAt.add(
        const Duration(minutes: 10),
      );
      expect(
        await p.recordProgress(sessionId, SessionStatus.completed, 60),
        isTrue,
      );
      expect(p.snapshot.tasks.single.remainingMinutes, 60);

      // Duplicate progress submission rejected with SESSION_ALREADY_CLOSED; remaining stays 60
      expect(
        await p.recordProgress(sessionId, SessionStatus.completed, 0),
        isFalse,
      );
      expect(p.errorCode, 'SESSION_ALREADY_CLOSED');
      expect(p.snapshot.tasks.single.remainingMinutes, 60);

      // Switch to Account B: Account A state is cleared and Account B cannot modify Account A's task
      activeToken = 'token-b';
      expect(await p.fetchSnapshot(userId: 'user-b'), isTrue);
      expect(p.snapshot.tasks, isEmpty);
      expect(
        await p.saveTask(
          id: 'task-a-1',
          title: 'Spoof Edit',
          course: null,
          deadline: DateTime.utc(2026, 11, 11, 11),
          remaining: 10,
        ),
        isFalse,
      );
      expect(p.errorCode, 'NOT_FOUND');
      expect(stateByUser['token-a']!.tasks.single.title, 'Tugas Backend A');
    },
  );
}
