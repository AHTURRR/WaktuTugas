import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Requires an already-running LOCAL stack and two existing, empty test accounts.
// No signup, admin key, credentials in fixtures, or remote URL is supported.
void main() {
  test(
    'owner isolation, rollback, concurrent confirmation and progress',
    () async {
      String requiredEnv(String name) {
        final value = Platform.environment[name];
        if (value == null || value.isEmpty) {
          fail(
            'Missing $name. Configure the disposable local backend explicitly.',
          );
        }
        return value;
      }

      final url = requiredEnv('SUPABASE_URL');
      final uri = Uri.parse(url);
      expect(
        ['127.0.0.1', 'localhost', '::1'].contains(uri.host) &&
            ['http', 'https'].contains(uri.scheme),
        isTrue,
        reason: 'Backend tests only mutate a disposable loopback stack.',
      );
      final key = requiredEnv('SUPABASE_PUBLISHABLE_KEY');
      final emailA = requiredEnv('WAKTUTUGAS_TEST_A_EMAIL');
      final passwordA = requiredEnv('WAKTUTUGAS_TEST_A_PASSWORD');
      final emailB = requiredEnv('WAKTUTUGAS_TEST_B_EMAIL');
      final passwordB = requiredEnv('WAKTUTUGAS_TEST_B_PASSWORD');
      SupabaseClient client() => SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final a = client();
      final a2 = client();
      final b = client();
      addTearDown(() async {
        await Future.wait([a.dispose(), a2.dispose(), b.dispose()]);
      });
      try {
        await Future.wait([
          a.auth.signInWithPassword(email: emailA, password: passwordA),
          a2.auth.signInWithPassword(email: emailA, password: passwordA),
          b.auth.signInWithPassword(email: emailB, password: passwordB),
        ]).timeout(const Duration(seconds: 15));
      } catch (_) {
        fail(
          'Local backend login failed; verify the running stack and test accounts.',
        );
      }
      expect(a.auth.currentUser!.id, a2.auth.currentUser!.id);
      expect(a.auth.currentUser!.id, isNot(b.auth.currentUser!.id));

      Future<Map<String, dynamic>> snapshot(SupabaseClient c) async =>
          Map<String, dynamic>.from(await c.rpc('get_planner_snapshot'));
      for (final c in [a, b]) {
        final state = await snapshot(c);
        for (final field in [
          'tasks',
          'time_windows',
          'activities',
          'sessions',
        ]) {
          expect(
            state[field],
            isEmpty,
            reason: 'Use empty disposable test accounts.',
          );
        }
      }
      Future<int> revision() async => (await snapshot(a))['revision'] as int;
      // Turn only expected database failures into values; connection errors still fail.
      Future<Object> outcome(Future<dynamic> call) async {
        try {
          return (await call) as int;
        } on PostgrestException catch (error) {
          return error.code ?? 'UNKNOWN';
        }
      }

      final deadline = DateTime.now().toUtc().add(const Duration(days: 20));
      await a.rpc(
        'save_task',
        params: {
          'p_task_id': null,
          'p_title': 'backend transaction fixture',
          'p_course': null,
          'p_deadline_at': deadline.toIso8601String(),
          'p_remaining_minutes': 180,
          'p_expected_revision': await revision(),
        },
      );
      final taskId = ((await snapshot(a))['tasks'] as List).single['id'];
      // Cleanup also runs after failed assertions; delete only the fixture task/window IDs.
      final windowIds = <String>[];
      addTearDown(() async {
        await a.rpc(
          'delete_task',
          params: {
            'p_task_id': taskId,
            'p_confirm_delete': true,
            'p_expected_revision': await revision(),
          },
        );
        for (final id in windowIds) {
          await a.rpc(
            'delete_time_window',
            params: {'p_id': id, 'p_expected_revision': await revision()},
          );
        }
      });
      for (var weekday = 1; weekday <= 7; weekday++) {
        await a.rpc(
          'save_time_window',
          params: {
            'p_id': null,
            'p_weekday': weekday,
            'p_date': null,
            'p_start_minute': 0,
            'p_end_minute': 1440,
            'p_expected_revision': await revision(),
          },
        );
        windowIds
          ..clear()
          ..addAll(
            ((await snapshot(a))['time_windows'] as List).map(
              (w) => w['id'] as String,
            ),
          );
      }
      final bBefore = await snapshot(b);
      expect(await b.from('tasks').select().eq('id', taskId), isEmpty);
      expect(
        await outcome(
          b.rpc(
            'delete_task',
            params: {
              'p_task_id': taskId,
              'p_confirm_delete': true,
              'p_expected_revision': bBefore['revision'],
            },
          ),
        ),
        'P0004',
      );
      expect(await snapshot(b), bBefore);

      Map<String, dynamic> confirmation(int rev, DateTime start) {
        final now = DateTime.now().toUtc();
        final wib = now.add(const Duration(hours: 7));
        return {
          'input_revision': rev,
          'window_start': DateTime.utc(
            now.year,
            now.month,
            now.day,
            now.hour,
            now.minute,
          ).toIso8601String(),
          'window_end': DateTime.utc(
            wib.year,
            wib.month,
            wib.day + 14,
          ).subtract(const Duration(hours: 7)).toIso8601String(),
          'sessions': [
            {
              'task_id': taskId,
              'starts_at': start.toIso8601String(),
              'ends_at': start
                  .add(const Duration(minutes: 30))
                  .toIso8601String(),
            },
          ],
        };
      }

      var now = DateTime.now().toUtc();
      final tomorrow = DateTime.utc(now.year, now.month, now.day + 1, 1);
      final rev = await revision();
      final params = confirmation(rev, tomorrow);
      final results = await Future.wait([
        outcome(a.rpc('confirm_schedule', params: params)),
        outcome(a2.rpc('confirm_schedule', params: params)),
      ]);
      expect(results.whereType<int>().toList(), [rev + 1]);
      expect(results.whereType<String>().toList(), ['P0002']);
      final saved = await snapshot(a);
      expect(await outcome(a.rpc('confirm_schedule', params: params)), 'P0002');
      expect(
        await snapshot(a),
        saved,
        reason: 'stale confirm preserves old schedule',
      );
      final invalid = confirmation(rev + 1, tomorrow);
      (invalid['sessions'] as List).add({
        'task_id': 'ffffffff-ffff-ffff-ffff-ffffffffffff',
        'starts_at': tomorrow.add(const Duration(hours: 1)).toIso8601String(),
        'ends_at': tomorrow.add(const Duration(hours: 2)).toIso8601String(),
      });
      expect(
        await outcome(a.rpc('confirm_schedule', params: invalid)),
        'P0004',
      );
      expect(
        await snapshot(a),
        saved,
        reason: 'mid-transaction failure fully rolls back',
      );

      now = DateTime.now().toUtc();
      final start = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute + (now.second < 45 ? 1 : 2),
      );
      await a.rpc(
        'confirm_schedule',
        params: confirmation(await revision(), start),
      );
      final planned = ((await snapshot(a))['sessions'] as List).singleWhere(
        (s) => s['status'] == 'planned',
      );
      // Real server time is needed to exercise progress; never backdate a candidate.
      while (DateTime.now().toUtc().isBefore(
        start.add(const Duration(seconds: 1)),
      )) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      final progressRevision = await revision();
      final progress = {
        'p_session_id': planned['id'],
        'p_status': 'completed',
        'p_remaining_after': 90,
        'p_expected_revision': progressRevision,
      };
      final closes = await Future.wait([
        outcome(a.rpc('record_progress', params: progress)),
        outcome(a2.rpc('record_progress', params: progress)),
      ]);
      expect(closes.whereType<int>().toList(), [progressRevision + 1]);
      expect(closes.whereType<String>().toList(), ['P0002']);
      final closed = await snapshot(a);
      expect((closed['tasks'] as List).single['remaining_minutes'], 90);
      progress['p_expected_revision'] = progressRevision + 1;
      expect(
        await outcome(a.rpc('record_progress', params: progress)),
        'P0005',
      );
      expect(await snapshot(a), closed);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
