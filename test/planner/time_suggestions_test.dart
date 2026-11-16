import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';
import 'package:waktu_tugas/planner/time_suggestions.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  DateTime getBaseNow() => tz.TZDateTime(jakarta, 2026, 11, 9, 8, 0).toUtc();

  test('kandidat menutup kekurangan penuh dan memangkas durasi berlebih', () {
    final now = getBaseNow();
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas A',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 22, 0).toUtc(),
      remainingMinutes: 60,
      createdAt: now,
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA],
      timeWindows: [],
      activities: [],
      sessions: [],
    );

    const suggester = TimeSuggester();
    final res = suggester.suggest(
      snapshot: snapshot,
      now: now,
      targetTask: taskA,
      preferredStartMinute: 1140, // 19:00
      preferredEndMinute: 1320, // 22:00 (180 mnt tersedia, tapi hanya perlu 60 mnt)
    );

    expect(res.suggestions.length, 3);
    final first = res.suggestions.first;
    expect(first.simulation.isFullyResolved, isTrue);
    expect(first.simulation.afterUnallocatedMinutes, 0);
    expect(first.addedMinutes, 60);
    expect(first.candidateWindow.date, '2026-11-09');
    expect(first.candidateWindow.startMinute, 1140);
    expect(first.candidateWindow.endMinute, 1200);
  });

  test('menghormati kegiatan tetap dan waktu terblokir', () {
    final now = getBaseNow();
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas A',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
      remainingMinutes: 120,
      createdAt: now,
    );

    // 9 Nov: 19:00-22:00 diblokir penuh oleh kegiatan tetap
    // 10 Nov: 19:00-20:00 diblokir, jadi hanya 20:00-22:00 (120 mnt) yang bebas
    final blockDay1 = Activity(
      id: 'act-1',
      label: 'Rapat Organisasi',
      kind: ActivityKind.blocked,
      date: '2026-11-09',
      startMinute: 1140, // 19:00
      endMinute: 1320, // 22:00
    );
    final blockDay2 = Activity(
      id: 'act-2',
      label: 'Kelas Malam',
      kind: ActivityKind.event,
      date: '2026-11-10',
      startMinute: 1140, // 19:00
      endMinute: 1200, // 20:00
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA],
      timeWindows: [],
      activities: [blockDay1, blockDay2],
      sessions: [],
    );

    const suggester = TimeSuggester();
    final res = suggester.suggest(
      snapshot: snapshot,
      now: now,
      targetTask: taskA,
      preferredStartMinute: 1140,
      preferredEndMinute: 1320,
    );

    expect(res.suggestions.length, 1);
    final only = res.suggestions.single;
    expect(only.candidateWindow.date, '2026-11-10');
    expect(only.candidateWindow.startMinute, 1200); // 20:00
    expect(only.candidateWindow.endMinute, 1320); // 22:00
    expect(only.simulation.isFullyResolved, isTrue);
  });

  test('mengurutkan berdasarkan pengurangan kekurangan, dampak tugas lain, lalu durasi', () {
    final now = getBaseNow();
    // Tugas Urgent (deadline 10 Nov) dan Tugas Target (deadline 12 Nov).
    // Pada 9 Nov ada waktu belajar 19:00-20:00 (60 mnt), dipakai Tugas Urgent (butuh 120 mnt -> kurang 60 mnt).
    // Jika kita tambah slot pada 9 Nov (sebelum deadline Tugas Urgent), Tugas Urgent juga masih aman,
    // sedangkan jika Tugas Urgent justru butuh waktu dan tugas lain tergeser, dampak terdeteksi.
    // Uji spesifik:
    // - Tugas B punya deadline 10 Nov (butuh 60 mnt, sudah terjadwal penuh di window 10 Nov 19:00-20:00)
    // - Tugas Target punya deadline 12 Nov (butuh 120 mnt, belum dapat waktu sama sekali)
    final taskB = Task(
      id: 'task-b',
      title: 'Tugas B',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
      remainingMinutes: 60,
      createdAt: now,
    );
    final taskTarget = Task(
      id: 'task-target',
      title: 'Tugas Target',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 22, 0).toUtc(),
      remainingMinutes: 120,
      createdAt: now,
    );

    // 9 Nov: bebas 19:00-20:00 (60 mnt -> hanya kurangi 60 mnt)
    // 10 Nov: sudah ada window 19:00-20:00 (60 mnt, dipakai taskB), bebas 20:00-22:00 (120 mnt -> kurangi penuh 120 mnt)
    // 11 Nov: bebas 19:00-21:00 (120 mnt -> kurangi penuh 120 mnt)
    final act9 = Activity(
      id: 'act-9',
      label: 'Tutup 9 Nov malam',
      kind: ActivityKind.blocked,
      date: '2026-11-09',
      startMinute: 1200, // 20:00
      endMinute: 1320, // 22:00
    );
    final existingWin10 = TimeWindow(
      id: 'win-10',
      date: '2026-11-10',
      startMinute: 1140, // 19:00
      endMinute: 1200, // 20:00
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskB, taskTarget],
      timeWindows: [existingWin10],
      activities: [act9],
      sessions: [],
    );

    const suggester = TimeSuggester();
    final res = suggester.suggest(
      snapshot: snapshot,
      now: now,
      targetTask: taskTarget,
      preferredStartMinute: 1140,
      preferredEndMinute: 1320,
    );

    expect(res.suggestions.length, 3);
    // Urutan 1 & 2 harus yang mengurangi 120 mnt penuh (10 Nov & 11 Nov), baru yang mengurangi 60 mnt (9 Nov)
    expect(res.suggestions[0].simulation.shortfallReduction, 120);
    expect(res.suggestions[1].simulation.shortfallReduction, 120);
    expect(res.suggestions[2].simulation.shortfallReduction, 60);
    expect(res.suggestions[2].candidateWindow.date, '2026-11-09');
  });

  test('mengutamakan kandidat yang tidak merugikan tugas lain ketika pengurangan sama', () {
    final now = getBaseNow();
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas A (Target)',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 12, 22, 0).toUtc(),
      remainingMinutes: 60,
      createdAt: now,
    );
    final taskB = Task(
      id: 'task-b',
      title: 'Tugas B (Terjadwal di 10 Nov)',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 22, 0).toUtc(),
      remainingMinutes: 60,
      createdAt: now,
    );
    // 9 Nov dan 10 Nov masing-masing hanya 60 mnt (19:00-20:00).
    // 9 Nov kosong -> menambah 9 Nov menyebabkan taskB pindah dari 10 Nov ke 9 Nov (mengubah jadwal taskB).
    // 11 Nov kosong -> menambah 11 Nov tidak menyentuh alokasi taskB di 10 Nov.
    final win10 = TimeWindow(
      id: 'win-10',
      date: '2026-11-10',
      startMinute: 1140,
      endMinute: 1200,
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA, taskB],
      timeWindows: [win10],
      activities: [
        Activity(
          id: 'blk-9',
          label: 'Blok 9',
          kind: ActivityKind.blocked,
          date: '2026-11-09',
          startMinute: 1200,
          endMinute: 1320,
        ),
        Activity(
          id: 'blk-10',
          label: 'Blok 10',
          kind: ActivityKind.blocked,
          date: '2026-11-10',
          startMinute: 1200,
          endMinute: 1320,
        ),
        Activity(
          id: 'blk-11',
          label: 'Blok 11',
          kind: ActivityKind.blocked,
          date: '2026-11-11',
          startMinute: 1200,
          endMinute: 1320,
        ),
      ],
      sessions: [],
    );

    const suggester = TimeSuggester();
    final res = suggester.suggest(
      snapshot: snapshot,
      now: now,
      targetTask: taskA,
      preferredStartMinute: 1140,
      preferredEndMinute: 1320,
    );

    expect(res.suggestions.length, greaterThanOrEqualTo(2));
    // 11 Nov tidak mengubah jadwal taskB (impactedTaskCount = 0), harus berada di urutan 1 sebelum 9 Nov!
    expect(res.suggestions.first.candidateWindow.date, '2026-11-11');
    expect(res.suggestions.first.impactedTaskCount, 0);
  });

  test('hasil kosong memberikan alasan jelas ketika seluruh rentang terblokir', () {
    final now = getBaseNow();
    final taskA = Task(
      id: 'task-a',
      title: 'Tugas A',
      deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
      remainingMinutes: 60,
      createdAt: now,
    );

    final snapshot = PlannerSnapshot(
      revision: 1,
      tasks: [taskA],
      timeWindows: [],
      activities: [
        Activity(
          id: 'blk-all',
          label: 'Kegiatan Rutin',
          kind: ActivityKind.routine,
          weekday: 1, // Senin 9 Nov
          startMinute: 1140,
          endMinute: 1320,
        ),
        Activity(
          id: 'blk-tue',
          label: 'Kegiatan Selasa',
          kind: ActivityKind.routine,
          weekday: 2, // Selasa 10 Nov
          startMinute: 1140,
          endMinute: 1320,
        ),
      ],
      sessions: [],
    );

    const suggester = TimeSuggester();
    final res = suggester.suggest(
      snapshot: snapshot,
      now: now,
      targetTask: taskA,
      preferredStartMinute: 1140,
      preferredEndMinute: 1320,
    );

    expect(res.isEmpty, isTrue);
    expect(res.emptyReason, EmptySuggestionReason.blockedOrAlreadyAllocated);
    expect(res.emptyExplanation, isNotNull);
  });
}
