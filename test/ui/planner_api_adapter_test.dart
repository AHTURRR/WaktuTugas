import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/data/planner_api.dart';
import 'package:waktu_tugas/planner/fixtures.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class RecordingApi extends PlannerApi {
  RecordingApi(super.client);
  final ids = <String?>[];
  @override
  Future<PlannerSnapshot> fetchSnapshot() async => demoSnapshot();
  @override
  Future<int> saveTimeWindow({
    String? id,
    int? weekday,
    String? date,
    required int startMinute,
    required int endMinute,
    required int expectedRevision,
  }) async {
    ids.add(id);
    return expectedRevision + 1;
  }

  @override
  Future<int> saveActivity({
    String? id,
    required String kind,
    required String label,
    int? weekday,
    String? date,
    required int startMinute,
    required int endMinute,
    required int expectedRevision,
  }) async {
    ids.add(id);
    return expectedRevision + 1;
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
  test(
    'new time entries request server IDs; edits preserve existing IDs',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-public-key',
      );
      addTearDown(client.dispose);
      final api = RecordingApi(client);
      final p = PlannerController(api: api);
      expect(
        await p.saveWindow(
          TimeWindow(
            id: 'window-new',
            date: '2026-11-12',
            startMinute: 1140,
            endMinute: 1200,
          ),
        ),
        isTrue,
      );
      expect(await p.saveWindow(p.snapshot.timeWindows.first), isTrue);
      expect(
        await p.saveActivity(
          Activity(
            id: 'activity-new',
            kind: ActivityKind.blocked,
            label: 'Ujian',
            date: '2026-11-12',
            startMinute: 0,
            endMinute: 1440,
          ),
        ),
        isTrue,
      );
      expect(await p.saveActivity(p.snapshot.activities.first), isTrue);
      expect(api.ids, [null, 'W01', null, 'A01']);
    },
  );
}
