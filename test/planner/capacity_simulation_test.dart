import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waktu_tugas/planner/capacity_simulation.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  DateTime getBaseNow() => tz.TZDateTime(jakarta, 2026, 11, 9, 8, 0).toUtc();

  test('penambahan slot menyelesaikan kekurangan kapasitas secara penuh', () {
    final baseNow = getBaseNow();
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas Algoritma',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
      remainingMinutes: 180,
      createdAt: baseNow,
    );

    // Waktu belajar awal hanya 60 menit pada 9 Nov 19:00 - 20:00 (kurang 120 menit)
    final initialWindow = TimeWindow(
      id: 'win-1',
      date: '2026-11-09',
      startMinute: 1140, // 19:00
      endMinute: 1200,   // 20:00 (60 menit)
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA],
      timeWindows: [initialWindow],
      activities: [],
      sessions: [],
    );

    final baseline = buildPreview(snapshot, baseNow);
    expect(baseline.unallocated.length, 1);
    expect(baseline.unallocated.single.minutes, 120);
    expect(baseline.unallocated.single.reason, UnallocatedReason.insufficientCapacity);

    // Tambah slot 120 menit pada 10 Nov 19:00 - 21:00
    final candidateWindow = TimeWindow(
      id: 'candidate-win',
      date: '2026-11-10',
      startMinute: 1140, // 19:00
      endMinute: 1260,   // 21:00 (120 menit)
    );

    const simulator = CapacitySimulator();
    final result = simulator.simulate(
      snapshot: snapshot,
      now: baseNow,
      targetTask: taskA,
      candidateWindow: candidateWindow,
      baselinePreview: baseline,
    );

    expect(result.beforeUnallocatedMinutes, 120);
    expect(result.afterUnallocatedMinutes, 0);
    expect(result.isFullyResolved, isTrue);
    expect(result.isPartiallyResolved, isFalse);
    expect(result.shortfallReduction, 120);
    expect(result.isCollidingWithBusy, isFalse);
    expect(result.otherTasksImpact, isEmpty);
  });

  test('penambahan slot menyelesaikan kekurangan sebagian bila durasi belum menutup total sisa', () {
    final baseNow = getBaseNow();
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas Desain UI',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 12, 0).toUtc(),
      remainingMinutes: 180,
      createdAt: baseNow,
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA],
      timeWindows: [],
      activities: [],
      sessions: [],
    );

    final baseline = buildPreview(snapshot, baseNow);
    expect(baseline.unallocated.single.minutes, 180);

    // Tambah slot hanya 60 menit
    final candidateWindow = TimeWindow(
      id: 'candidate-win-partial',
      date: '2026-11-10',
      startMinute: 1140, // 19:00
      endMinute: 1200,   // 20:00 (60 menit)
    );

    const simulator = CapacitySimulator();
    final result = simulator.simulate(
      snapshot: snapshot,
      now: baseNow,
      targetTask: taskA,
      candidateWindow: candidateWindow,
      baselinePreview: baseline,
    );

    expect(result.beforeUnallocatedMinutes, 180);
    expect(result.afterUnallocatedMinutes, 120);
    expect(result.isFullyResolved, isFalse);
    expect(result.isPartiallyResolved, isTrue);
    expect(result.shortfallReduction, 60);
    expect(result.isCollidingWithBusy, isFalse);
  });

  test('deteksi tabrakan dengan penutupan/kegiatan lain yang memotong kapasitas efektif slot', () {
    final baseNow = getBaseNow();
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas Basis Data',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
      remainingMinutes: 120,
      createdAt: baseNow,
    );

    // Ada penutupan / kegiatan bertanggal pada 10 Nov 20:00 - 21:00 (60 menit)
    final blockedActivity = Activity(
      id: 'act-blocked-1',
      date: '2026-11-10',
      startMinute: 1200, // 20:00
      endMinute: 1260,   // 21:00
      kind: ActivityKind.blocked,
      label: 'Rapat Organisasi',
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA],
      timeWindows: [],
      activities: [blockedActivity],
      sessions: [],
    );

    final baseline = buildPreview(snapshot, baseNow);

    // Pengguna mencoba slot 120 menit: 19:00 - 21:00
    // Jam 20:00 - 21:00 bertabrakan dengan Rapat Organisasi, sehingga hanya 19:00 - 20:00 (60 mnt) efektif
    final candidateWindow = TimeWindow(
      id: 'candidate-win-collision',
      date: '2026-11-10',
      startMinute: 1140, // 19:00
      endMinute: 1260,   // 21:00 (120 menit nominal)
    );

    const simulator = CapacitySimulator();
    final result = simulator.simulate(
      snapshot: snapshot,
      now: baseNow,
      targetTask: taskA,
      candidateWindow: candidateWindow,
      baselinePreview: baseline,
    );

    expect(result.candidateDurationMinutes, 120);
    expect(result.effectiveCapacityAddedMinutes, 60);
    expect(result.collidingMinutes, 60);
    expect(result.isCollidingWithBusy, isTrue);
    expect(result.shortfallReduction, 60);
    expect(result.afterUnallocatedMinutes, 60);
  });

  test('deteksi dampak pergeseran alokasi pada tugas lain', () {
    final baseNow = getBaseNow();
    // Task A: deadline 11 Nov 12:00, remaining 120 min (tenggat lebih awal)
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas Prioritas Tinggi',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 12, 0).toUtc(),
      remainingMinutes: 120,
      createdAt: baseNow,
    );

    // Task B: deadline 12 Nov 12:00, remaining 60 min (tenggat lebih lambat)
    final taskB = Task(
      id: 'task-b',
      title: 'Tugas Lain',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 12, 12, 0).toUtc(),
      remainingMinutes: 60,
      createdAt: baseNow,
    );

    // Window awal: 10 Nov 19:00 - 20:00 (60 menit)
    // Task A mengambil slot 60 menit ini (karena tenggat lebih awal), kurang 60 menit
    // Task B tidak kebagian (kurang 60 menit)
    final initialWindow = TimeWindow(
      id: 'win-initial',
      date: '2026-11-10',
      startMinute: 1140,
      endMinute: 1200,
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA, taskB],
      timeWindows: [initialWindow],
      activities: [],
      sessions: [],
    );

    final baseline = buildPreview(snapshot, baseNow);

    // Coba tambah slot 120 menit pada 10 Nov 20:00 - 22:00
    // Task A akan mengambil 60 menit pertama dari slot baru (sehingga terpenuhi 120 menit)
    // Sisa 60 menit dari slot baru akan diambil oleh Task B!
    // Sehingga Task B ikut terdampak (alokasinya bertambah dari 0 menjadi 60 menit)!
    final candidateWindow = TimeWindow(
      id: 'candidate-win-other-impact',
      date: '2026-11-10',
      startMinute: 1200, // 20:00
      endMinute: 1320,   // 22:00 (120 menit)
    );

    const simulator = CapacitySimulator();
    final result = simulator.simulate(
      snapshot: snapshot,
      now: baseNow,
      targetTask: taskA,
      candidateWindow: candidateWindow,
      baselinePreview: baseline,
    );

    expect(result.beforeUnallocatedMinutes, 60);
    expect(result.afterUnallocatedMinutes, 0);
    expect(result.isFullyResolved, isTrue);

    // Dampak ke Task B terdeteksi:
    expect(result.otherTasksImpact.length, 1);
    final impactB = result.otherTasksImpact.single;
    expect(impactB.task.id, 'task-b');
    expect(impactB.beforeMinutes, 0);
    expect(impactB.afterMinutes, 60);
    expect(impactB.minuteDelta, 60);
    expect(impactB.hasChange, isTrue);
  });
}
