import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/data/session_timer_service.dart';
import 'package:waktu_tugas/features/schedule/session_screen.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('id_ID');
  });

  PlannerSnapshot sampleSnapshot() {
    return PlannerSnapshot(
      revision: 1,
      tasks: [
        Task(
          id: 't1',
          title: 'Tugas Sistem Operasi',
          remainingMinutes: 90,
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
          id: 's1',
          taskId: 't1',
          startsAt: DateTime.utc(2026, 6, 1, 12, 0),
          endsAt: DateTime.utc(2026, 6, 1, 13, 0),
          status: SessionStatus.planned,
        ),
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

  testWidgets(
    'Alur timer sesi: Mulai -> Latar belakang -> Jeda -> Lanjutkan -> Selesai membuka Catat progres dengan durasi fokus',
    (tester) async {
      var currentNow = DateTime.utc(2026, 6, 1, 12, 10);
      final service = SessionTimerService(
        storage: MemorySessionTimerStorage(),
        clock: () => currentNow,
      );
      final planner = PlannerController(
        clock: () => currentNow,
        initial: sampleSnapshot(),
        timerService: service,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: SessionScreen(planner: planner, sessionId: 's1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('00:00'), findsOneWidget);

      // 1. Mulai
      await tester.ensureVisible(find.text('Mulai'));
      await tester.tap(find.text('Mulai'));
      await tester.pumpAndSettle();
      expect(find.text('Berjalan'), findsOneWidget);

      // 2. Simulasi masuk latar belakang 5 menit lalu kembali (resumed)
      currentNow = currentNow.add(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('05:00'), findsOneWidget);

      // 3. Jeda -> waktu maju 2 menit tetap 05:00
      await tester.ensureVisible(find.text('Jeda'));
      await tester.tap(find.text('Jeda'));
      await tester.pumpAndSettle();
      expect(find.text('Dijeda'), findsOneWidget);

      currentNow = currentNow.add(const Duration(minutes: 2));
      await tester.pump();
      expect(find.text('05:00'), findsOneWidget);

      // 4. Lanjutkan -> waktu maju 1 menit menjadi 06:00
      await tester.ensureVisible(find.text('Lanjutkan'));
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      currentNow = currentNow.add(const Duration(minutes: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('06:00'), findsOneWidget);

      // 5. Selesai -> buka alur Catat progres dan tampilkan durasi fokus sebagai informasi
      await tester.ensureVisible(find.text('Selesai'));
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();

      expect(find.text('Catat progres'), findsOneWidget);
      expect(find.text('Durasi fokus · 6 menit'), findsOneWidget);
      // Pengguna tetap bisa meninjau dan mengubah sisa pengerjaan sebelum menyimpan
      expect(find.byKey(const Key('remaining-after')), findsOneWidget);
    },
  );

  testWidgets(
    'Membuka sesi kedua saat timer aktif di sesi pertama menampilkan peringatan batas satu timer',
    (tester) async {
      final currentNow = DateTime.utc(2026, 6, 1, 13, 5);
      final service = SessionTimerService(
        storage: MemorySessionTimerStorage(),
        clock: () => currentNow,
      );
      final planner = PlannerController(
        clock: () => currentNow,
        initial: sampleSnapshot(),
        timerService: service,
      );

      await tester.runAsync(() async {
        await planner.startSessionTimer('s1');
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: SessionScreen(planner: planner, sessionId: 's2'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Timer aktif di sesi lain'), findsOneWidget);
      expect(find.text('Mulai'), findsNothing);
    },
  );
}
