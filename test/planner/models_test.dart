import 'package:flutter_test/flutter_test.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/fixtures.dart';

void main() {
  test('all session statuses and interval JSON round trip', () {
    for (final status in SessionStatus.values) {
      final s = PlannerSession(
        id: 's',
        taskId: 'T01',
        startsAt: demoNow,
        endsAt: demoNow.add(const Duration(hours: 1)),
        status: status,
        remainingAfter: status == SessionStatus.completed ? 90 : null,
        closedAt:
            status == SessionStatus.completed || status == SessionStatus.missed
            ? demoNow
            : null,
      );
      expect(PlannerSession.fromJson(s.toJson()).toJson(), s.toJson());
    }
    final interval = Interval(demoNow, demoNow.add(const Duration(minutes: 1)));
    expect(Interval.fromJson(interval.toJson()).toJson(), interval.toJson());
    final week = TimeWindow(
      id: 'w',
      weekday: 7,
      startMinute: 0,
      endMinute: 1440,
    );
    expect(TimeWindow.fromJson(week.toJson()).toJson(), week.toJson());
    for (final kind in ActivityKind.values) {
      final a = Activity(
        id: 'a',
        kind: kind,
        label: '',
        weekday: kind == ActivityKind.routine ? 1 : null,
        date: kind == ActivityKind.routine ? null : '2026-11-09',
        startMinute: 0,
        endMinute: 1440,
      );
      expect(Activity.fromJson(a.toJson()).toJson(), a.toJson());
    }
  });
  test('invalid instants do not silently normalize calendar dates', () {
    final json = demoSnapshot().tasks.first.toJson();
    expect(
      () => Task.fromJson({...json, 'deadline_at': '2026-02-30T18:00:00Z'}),
      throwsFormatException,
    );
    expect(
      () => Task.fromJson({...json, 'deadline_at': '2026-11-09T25:00:00Z'}),
      throwsFormatException,
    );
    expect(
      () => PlannerSnapshot.fromJson({
        ...demoSnapshot().toJson(),
        'tasks': [3],
      }),
      throwsFormatException,
    );
  });
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
