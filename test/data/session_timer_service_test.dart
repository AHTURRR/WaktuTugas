import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/data/session_timer_service.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  PlannerSnapshot makeSnapshot({
    String s1Id = 's1',
    SessionStatus s1Status = SessionStatus.planned,
    bool includeS2 = true,
  }) {
    return PlannerSnapshot(
      revision: 1,
      tasks: [
        Task(
          id: 't1',
          title: 'Tugas Jaringan',
          remainingMinutes: 120,
          deadlineAt: DateTime.utc(2026, 6, 3, 16, 59),
          createdAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      timeWindows: [
        TimeWindow(
          id: 'w1',
          date: '2026-06-01',
          startMinute: 1140,
          endMinute: 1320,
        ),
      ],
      activities: [],
      sessions: [
        PlannerSession(
          id: s1Id,
          taskId: 't1',
          startsAt: DateTime.utc(2026, 6, 1, 12, 0),
          endsAt: DateTime.utc(2026, 6, 1, 13, 0),
          status: s1Status,
        ),
        if (includeS2)
          PlannerSession(
            id: 's2',
            taskId: 't1',
            startsAt: DateTime.utc(2026, 6, 1, 13, 0),
            endsAt: DateTime.utc(2026, 6, 1, 14, 0),
            status: SessionStatus.planned,
          ),
      ],
    );
  }

  test(
    'mulai, jeda, lanjutkan, akurasi latar belakang berbasis cap waktu, dan pemulihan saat dibuka ulang',
    () async {
      var currentNow = DateTime.utc(2026, 6, 1, 12, 5);
      final storage = MemorySessionTimerStorage();
      final service = SessionTimerService(
        storage: storage,
        clock: () => currentNow,
      );
      final snapshot = makeSnapshot();
      await service.loadForUser('akun-a', snapshot);

      // Mulai
      expect(await service.start(snapshot.sessions[0], userKey: 'akun-a'), isTrue);

      // Simulasi aplikasi di latar belakang selama 4 menit 30 detik
      currentNow = currentNow.add(const Duration(minutes: 4, seconds: 30));
      expect(service.elapsedFor('s1'), const Duration(minutes: 4, seconds: 30));

      // Jeda selama 2 menit -> durasi tidak bertambah
      expect(await service.pause('s1'), isTrue);
      currentNow = currentNow.add(const Duration(minutes: 2));
      expect(service.elapsedFor('s1'), const Duration(minutes: 4, seconds: 30));

      // Lanjutkan & maju 1 menit
      expect(await service.resume('s1'), isTrue);
      currentNow = currentNow.add(const Duration(minutes: 1));
      expect(service.elapsedFor('s1'), const Duration(minutes: 5, seconds: 30));

      // Simulasi aplikasi ditutup lalu dibuka ulang (instance baru baca dari storage)
      currentNow = currentNow.add(const Duration(minutes: 3));
      final reopenedService = SessionTimerService(
        storage: storage,
        clock: () => currentNow,
      );
      await reopenedService.loadForUser('akun-a', snapshot);
      expect(reopenedService.isActiveFor('s1'), isTrue);
      expect(
        reopenedService.elapsedFor('s1'),
        const Duration(minutes: 8, seconds: 30),
      );
    },
  );

  test(
    'ketukan ganda, batas satu timer per akun, pergantian akun, dan perubahan jadwal',
    () async {
      var currentNow = DateTime.utc(2026, 6, 1, 12, 5);
      final storage = MemorySessionTimerStorage();
      final service = SessionTimerService(
        storage: storage,
        clock: () => currentNow,
      );
      final planner = PlannerController(
        clock: () => currentNow,
        initial: makeSnapshot(),
        timerService: service,
      );
      await Future<void>.delayed(Duration.zero);

      // Ketukan ganda Mulai -> hanya satu timer aktif & idempoten
      final results = await Future.wait([
        planner.startSessionTimer('s1'),
        planner.startSessionTimer('s1'),
      ]);
      expect(results.first, isTrue);
      expect(planner.isTimerActiveForSession('s1'), isTrue);

      // Satu timer aktif per akun: sesi s2 ditolak saat s1 masih aktif
      expect(planner.hasOtherActiveTimer('s2'), isTrue);
      expect(await planner.startSessionTimer('s2'), isFalse);
      expect(planner.sessionTimerError, contains('timer aktif pada sesi lain'));

      // Pergantian akun membersihkan timer akun sebelumnya dari memori
      planner.clear();
      expect(planner.activeSessionTimer, isNull);
      planner.bindUser('akun-b');
      await Future<void>.delayed(Duration.zero);
      expect(planner.activeSessionTimer, isNull);
      expect(planner.hasOtherActiveTimer('s2'), isFalse);

      // Perubahan jadwal (sesi s1 dibatalkan dan diganti s3) membersihkan timer s1
      final serviceA = SessionTimerService(
        storage: storage,
        clock: () => currentNow,
      );
      await serviceA.loadForUser('demo', makeSnapshot());
      expect(serviceA.isActiveFor('s1'), isTrue);

      final rescheduled = makeSnapshot(
        s1Id: 's1',
        s1Status: SessionStatus.cancelled,
      );
      await serviceA.reconcileWithSnapshot(rescheduled);
      expect(serviceA.activeTimer, isNull);
      expect(serviceA.isActiveFor('s1'), isFalse);
    },
  );
}
