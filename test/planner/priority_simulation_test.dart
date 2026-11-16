import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/priority_simulation.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  final now = DateTime.utc(2026, 6, 1, 2, 0); // 09:00 WIB

  test(
    'dua tugas bersaing atas satu slot: tugas pilihan memperoleh menit dan tugas lain kehilangan menit',
    () {
      final taskA = Task(
        id: 't-a',
        title: 'Tugas A (Deadline Lebih Dekat)',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 2, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );
      final taskB = Task(
        id: 't-b',
        title: 'Tugas B (Diprioritaskan)',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 3, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );

      final snapshot = PlannerSnapshot(
        revision: 4,
        tasks: [taskA, taskB],
        timeWindows: [
          TimeWindow(
            id: 'w-1',
            date: '2026-06-01',
            startMinute: 1140, // 19:00
            endMinute: 1260, // 21:00 (120 menit)
          ),
        ],
        activities: [],
        sessions: [],
      );

      const simulator = PrioritySimulator();
      final result = simulator.simulate(
        snapshot: snapshot,
        now: now,
        targetTask: taskB,
      );

      expect(result.beforeAllocatedMinutes, 0);
      expect(result.afterAllocatedMinutes, 120);
      expect(result.gainedMinutes, 120);
      expect(result.hasImprovement, isTrue);
      expect(result.isFullyResolved, isTrue);
      expect(result.beforeUnallocatedMinutes, 120);
      expect(result.afterUnallocatedMinutes, 0);

      expect(result.otherTasksImpact.length, 1);
      final impactA = result.otherTasksImpact.first;
      expect(impactA.task.id, 't-a');
      expect(impactA.beforeMinutes, 120);
      expect(impactA.afterMinutes, 0);
      expect(impactA.minuteDelta, -120);
      expect(result.totalOtherLostMinutes, 120);

      // Snapshot asli tidak berubah
      expect(snapshot.revision, 4);
      expect(snapshot.tasks.length, 2);
      expect(snapshot.tasks[0].deadlineAt, taskA.deadlineAt);
      expect(snapshot.tasks[1].deadlineAt, taskB.deadlineAt);
    },
  );

  test(
    'skenario yang tidak memperbaiki hasil ketika tidak ada slot sebelum tenggat tugas',
    () {
      final taskEarlyDeadline = Task(
        id: 't-early',
        title: 'Tugas Tenggat Hari Ini',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 1, 10, 0), // 17:00 WIB hari ini
        createdAt: DateTime.utc(2026, 5, 30),
      );
      final taskLater = Task(
        id: 't-later',
        title: 'Tugas Besok',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 3, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );

      // Satu-satunya slot belajar berada pukul 19:00-21:00 WIB (setelah tenggat 17:00 WIB)
      final snapshot = PlannerSnapshot(
        revision: 2,
        tasks: [taskEarlyDeadline, taskLater],
        timeWindows: [
          TimeWindow(
            id: 'w-night',
            date: '2026-06-01',
            startMinute: 1140,
            endMinute: 1260,
          ),
        ],
        activities: [],
        sessions: [],
      );

      const simulator = PrioritySimulator();
      final result = simulator.simulate(
        snapshot: snapshot,
        now: now,
        targetTask: taskEarlyDeadline,
      );

      expect(result.beforeAllocatedMinutes, 0);
      expect(result.afterAllocatedMinutes, 0);
      expect(result.gainedMinutes, 0);
      expect(result.hasImprovement, isFalse);
      expect(result.otherTasksImpact, isEmpty);
    },
  );

  test(
    'tetap menghormati jadwal kuliah (kegiatan tetap) dan blok waktu',
    () {
      final taskA = Task(
        id: 't-a',
        title: 'Tugas A',
        remainingMinutes: 60,
        deadlineAt: DateTime.utc(2026, 6, 2, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );
      final taskB = Task(
        id: 't-b',
        title: 'Tugas B',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 3, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );

      final snapshot = PlannerSnapshot(
        revision: 1,
        tasks: [taskA, taskB],
        timeWindows: [
          TimeWindow(
            id: 'w-1',
            date: '2026-06-01',
            startMinute: 1140, // 19:00
            endMinute: 1260, // 21:00
          ),
        ],
        activities: [
          Activity(
            id: 'a-class',
            date: '2026-06-01',
            startMinute: 1200, // 20:00
            endMinute: 1260, // 21:00
            kind: ActivityKind.event,
            label: 'Kuliah Malam',
          ),
        ],
        sessions: [],
      );

      const simulator = PrioritySimulator();
      final result = simulator.simulate(
        snapshot: snapshot,
        now: now,
        targetTask: taskB,
      );

      // Hanya 60 menit tersedia (19:00-20:00) karena 20:00-21:00 bentrok kuliah
      expect(result.beforeAllocatedMinutes, 0);
      expect(result.afterAllocatedMinutes, 60);
      expect(result.gainedMinutes, 60);
      expect(result.afterUnallocatedMinutes, 60);
      expect(result.otherTasksImpact.single.minuteDelta, -60);
    },
  );
}
