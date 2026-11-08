import 'package:flutter_test/flutter_test.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/fixtures.dart';

void main() {
  test('models_round_trip preserves snapshot, nulls and UTC', () {
    final snapshot = demoSnapshot();
    expect(
      PlannerSnapshot.fromJson(snapshot.toJson()).toJson(),
      snapshot.toJson(),
    );
    final json = snapshot.tasks.first.toJson();
    json['deadline_at'] = '2026-11-11T18:00:00+07:00';
    final task = Task.fromJson(json);
    expect(task.deadlineAt, DateTime.utc(2026, 11, 11, 11));
    expect(task.deadlineAt.isUtc, isTrue);
    expect(task.course, isNull);
    expect(() => snapshot.tasks.clear(), throwsUnsupportedError);
  });
  test('preview reason JSON uses API spelling', () {
    for (final reason in UnallocatedReason.values) {
      final item = Unallocated(taskId: 'T03', minutes: 120, reason: reason);
      expect(Unallocated.fromJson(item.toJson()).reason, reason);
    }
    expect(
      UnallocatedReason.insufficientCapacity.json,
      'insufficient_capacity',
    );
  });
  test('invalid JSON and ambiguous dates are rejected', () {
    final json = demoSnapshot().tasks.first.toJson();
    expect(
      () => Task.fromJson({...json, 'remaining_minutes': -1}),
      throwsFormatException,
    );
    expect(() => Task.fromJson({...json, 'title': ' '}), throwsFormatException);
    expect(
      () => Task.fromJson({...json, 'deadline_at': '2026-11-11T18:00:00'}),
      throwsFormatException,
    );
    expect(
      () => TimeWindow.fromJson({
        'id': 'w',
        'weekday': 1,
        'date': '2026-11-09',
        'start_minute': 0,
        'end_minute': 60,
      }),
      throwsFormatException,
    );
    expect(
      () => TimeWindow.fromJson({
        'id': 'w',
        'date': '2026-02-30',
        'start_minute': 0,
        'end_minute': 60,
      }),
      throwsFormatException,
    );
    expect(
      () => Unallocated.fromJson({
        'task_id': 't',
        'minutes': 1,
        'reason': 'unknown',
      }),
      throwsFormatException,
    );
  });
}
