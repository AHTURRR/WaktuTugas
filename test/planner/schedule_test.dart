import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:waktu_tugas/planner/fixtures.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';

PlannerSnapshot sample({
  List<Task>? tasks,
  List<TimeWindow>? windows,
  List<Activity>? activities,
  List<PlannerSession>? sessions,
}) {
  final d = demoSnapshot();
  return PlannerSnapshot(
    revision: 0,
    tasks: tasks ?? d.tasks,
    timeWindows: windows ?? d.timeWindows,
    activities: activities ?? d.activities,
    sessions: sessions ?? [],
  );
}

Task task(
  String id,
  DateTime deadline, {
  int minutes = 60,
  DateTime? created,
}) => Task(
  id: id,
  title: id,
  deadlineAt: deadline,
  remainingMinutes: minutes,
  createdAt: created ?? demoNow,
);
void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('demo_shortfall has exact deterministic sessions and T03=120', () {
    final p = buildPreview(demoSnapshot(), demoNow);
    expect(p.sessions.map((s) => s.taskId), [
      'T01',
      'T01',
      'T01',
      'T02',
      'T03',
    ]);
    expect(p.sessions.map((s) => s.endsAt.difference(s.startsAt).inMinutes), [
      60,
      60,
      120,
      120,
      60,
    ]);
    expect(p.unallocated.single.toJson(), {
      'task_id': 'T03',
      'minutes': 120,
      'reason': 'insufficient_capacity',
    });
    expect(p.windowEnd, DateTime.utc(2026, 11, 22, 17));
    expect(SchedulePreview.fromJson(p.toJson()).toJson(), p.toJson());
    expect(buildPreview(demoSnapshot(), demoNow).toJson(), p.toJson());
  });
  test('added_capacity removes shortfall', () {
    final s = sample(
      windows: [
        ...demoSnapshot().timeWindows,
        TimeWindow(
          id: 'extra',
          date: '2026-11-12',
          startMinute: 1200,
          endMinute: 1320,
        ),
      ],
    );
    expect(buildPreview(s, demoNow).unallocated, isEmpty);
  });
  test(
    'deadline_mid_slot and adjacent sessions respect half-open intervals',
    () {
      final end = DateTime.utc(2026, 11, 9, 13, 30);
      final s = sample(
        tasks: [
          task('a', end, minutes: 90),
          task('b', end.add(const Duration(hours: 2))),
        ],
        windows: [
          TimeWindow(
            id: 'w',
            date: '2026-11-09',
            startMinute: 1200,
            endMinute: 1320,
          ),
        ],
        activities: [],
      );
      final p = buildPreview(s, demoNow);
      expect(p.sessions.first.endsAt, end);
      expect(p.sessions.last.startsAt, end);
      expect(p.sessions.last.endsAt, DateTime.utc(2026, 11, 9, 14, 30));
      expect(p.unallocated.single.taskId, 'a');
      expect(p.unallocated.single.minutes, 60);
    },
  );
  test('ceil_now rounds microseconds up; WIB midnight bounds 14 dates', () {
    final now = DateTime.utc(2026, 11, 9, 12, 0, 0, 1);
    final p = buildPreview(demoSnapshot(), now);
    expect(p.windowStart, DateTime.utc(2026, 11, 9, 12, 1));
    expect(p.sessions.first.startsAt, p.windowStart);
    expect(p.windowEnd, DateTime.utc(2026, 11, 22, 17));
    final late = buildPreview(
      demoSnapshot(),
      DateTime.utc(2026, 11, 9, 16, 59, 59),
    );
    expect(late.windowStart, DateTime.utc(2026, 11, 9, 17));
    expect(late.windowEnd, DateTime.utc(2026, 11, 22, 17));
  });
  test('stable_order uses deadline, created, id and ignores zero', () {
    final end = DateTime.utc(2026, 11, 10);
    final s = sample(
      tasks: [
        task('z', end),
        task('b', end),
        task('a', end),
        task('old', end, created: demoNow.subtract(const Duration(days: 1))),
        task('zero', end, minutes: 0),
      ],
      activities: [],
      windows: [
        TimeWindow(
          id: 'w',
          date: '2026-11-09',
          startMinute: 1140,
          endMinute: 1380,
        ),
      ],
    );
    expect(buildPreview(s, demoNow).sessions.map((v) => v.taskId), [
      'old',
      'a',
      'b',
      'z',
    ]);
  });
  test('past_deadline, outside_horizon, exact window edge and no capacity', () {
    final s = sample(
      tasks: [
        task('past', demoNow),
        task('edge', DateTime.utc(2026, 11, 22, 17)),
        task('future', DateTime.utc(2026, 12)),
      ],
      windows: [],
    );
    expect(buildPreview(s, demoNow).unallocated.map((v) => v.reason), [
      UnallocatedReason.pastDeadline,
      UnallocatedReason.insufficientCapacity,
      UnallocatedReason.outsideHorizon,
    ]);
    final allocated = sample(tasks: [task('future', DateTime.utc(2026, 12))]);
    expect(buildPreview(allocated, demoNow).unallocated, isEmpty);
  });
  test(
    'completed_overlap is removed; future planned ignored; started planned blocks',
    () {
      PlannerSession session(SessionStatus status, DateTime start) =>
          PlannerSession(
            id: 's',
            taskId: 'T01',
            startsAt: start,
            endsAt: DateTime.utc(2026, 11, 9, 12, 30),
            status: status,
            remainingAfter: status == SessionStatus.completed ? 240 : null,
            closedAt: status == SessionStatus.completed ? demoNow : null,
          );
      final done = sample(
        sessions: [session(SessionStatus.completed, demoNow)],
      );
      expect(
        buildPreview(done, demoNow).sessions.first.startsAt,
        DateTime.utc(2026, 11, 9, 12, 30),
      );
      expect(
        buildPreview(
          sample(
            sessions: [
              session(SessionStatus.planned, DateTime.utc(2026, 11, 9, 12)),
            ],
          ),
          demoNow,
        ).sessions.first.startsAt,
        DateTime.utc(2026, 11, 9, 12),
      );
      expect(
        () => buildPreview(
          sample(sessions: [session(SessionStatus.planned, demoNow)]),
          demoNow,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'device_non_wib and weekly expansion preserve Jakarta dates and end 1440',
    () {
      final input = sample(
        windows: [
          TimeWindow(
            id: 'weekly',
            weekday: 1,
            startMinute: 1380,
            endMinute: 1440,
          ),
        ],
        activities: [],
      );
      final now = tz.TZDateTime.from(
        demoNow,
        tz.getLocation('America/New_York'),
      );
      final windows = expandWindows(input, now);
      expect(windows.length, 2);
      expect(windows.first.start, DateTime.utc(2026, 11, 9, 16));
      expect(windows.first.end, DateTime.utc(2026, 11, 9, 17));
      expect(
        buildPreview(input, now).toJson(),
        buildPreview(input, demoNow).toJson(),
      );
    },
  );
  test('manual additions cannot override blocked date', () {
    final s = sample(
      windows: [
        TimeWindow(
          id: 'a',
          date: '2026-11-09',
          startMinute: 1140,
          endMinute: 1380,
        ),
        TimeWindow(
          id: 'b',
          date: '2026-11-09',
          startMinute: 1200,
          endMinute: 1260,
        ),
      ],
      activities: [
        Activity(
          id: 'x',
          date: '2026-11-09',
          startMinute: 1200,
          endMinute: 1260,
          kind: ActivityKind.blocked,
          label: 'Tutup',
        ),
      ],
    );
    expect(expandWindows(s, demoNow).fold(0, (int n, v) => n + v.minutes), 180);
  });
  test('buildPreview completes within 1000ms for 50 tasks across 14 dates', () {
    final tasks = [
      for (var i = 0; i < 50; i++)
        Task(
          id: 'T-${i.toString().padLeft(2, '0')}',
          title: 'Tugas kapasitas $i',
          deadlineAt: demoNow.add(Duration(hours: 6 * (i + 1))),
          remainingMinutes: 90,
          createdAt: demoNow,
        ),
    ];
    final windows = [
      for (var d = 1; d <= 7; d++)
        TimeWindow(id: 'W-$d', weekday: d, startMinute: 480, endMinute: 1320),
    ];
    final activities = [
      for (var d = 1; d <= 5; d++)
        Activity(
          id: 'A-$d',
          kind: ActivityKind.routine,
          label: 'Kuliah $d',
          weekday: d,
          startMinute: 600,
          endMinute: 780,
        ),
    ];
    final input = PlannerSnapshot(
      revision: 1,
      tasks: tasks,
      timeWindows: windows,
      activities: activities,
      sessions: [],
    );
    final watch = Stopwatch()..start();
    final preview = buildPreview(input, demoNow);
    watch.stop();
    expect(preview.sessions, isNotEmpty);
    expect(watch.elapsedMilliseconds, lessThanOrEqualTo(1000));
  });
}
