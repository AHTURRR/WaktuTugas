import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/schedule/reasons_screen.dart';
import 'package:waktu_tugas/features/schedule/try_add_time_screen.dart';
import 'package:waktu_tugas/features/schedule/try_prioritize_task_screen.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

Future<PlannerController> _makeController(PlannerSnapshot snapshot) async {
  final now = DateTime.utc(2026, 6, 1, 2, 0); // 09:00 WIB
  final controller = PlannerController(
    clock: () => now,
    initial: snapshot,
  );
  await controller.generatePreview();
  return controller;
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
    'Aksi Coba prioritaskan tugas ini tersedia dari ReasonsScreen & TryAddTimeScreen, membandingkan dua tugas bersaing, dan pembatalan tidak mengubah data tersimpan',
    (tester) async {
      final taskA = Task(
        id: 't-a',
        title: 'Tugas A (Lebih Mendesak)',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 2, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );
      final taskB = Task(
        id: 't-b',
        title: 'Tugas B (Ingin Diprioritaskan)',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 3, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );

      final initialSnapshot = PlannerSnapshot(
        revision: 3,
        tasks: [taskA, taskB],
        timeWindows: [
          TimeWindow(
            id: 'w-1',
            date: '2026-06-01',
            startMinute: 1140, // 19:00
            endMinute: 1260, // 21:00
          ),
        ],
        activities: [],
        sessions: [],
      );

      late PlannerController planner;
      await tester.runAsync(() async {
        planner = await _makeController(initialSnapshot);
      });

      final initialPreviewSessions = planner.preview!.sessions.length;
      final initialTaskIds = planner.snapshot.tasks.map((t) => t.id).toList();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: ReasonsScreen(planner: planner),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tombol tersedia pada ReasonsScreen untuk tugas kekurangan kapasitas
      final prioritizeBtn = find.text('Coba prioritaskan tugas ini');
      expect(prioritizeBtn, findsOneWidget);

      await tester.ensureVisible(prioritizeBtn);
      await tester.tap(prioritizeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TryPrioritizeTaskScreen), findsOneWidget);
      expect(find.text('+120 menit diperoleh'), findsOneWidget);
      expect(find.text('Hilang 120 menit'), findsOneWidget);
      expect(find.text('Tugas A (Lebih Mendesak)'), findsOneWidget);

      // 2. Pembatalan menjaga preferensi tugas dan jadwal tersimpan tetap sama
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.byType(TryPrioritizeTaskScreen), findsNothing);
      expect(planner.snapshot.revision, 3);
      expect(planner.snapshot.tasks.map((t) => t.id).toList(), initialTaskIds);
      expect(planner.preview!.sessions.length, initialPreviewSessions);

      // 3. Tombol juga tersedia dari layar simulasi TryAddTimeScreen
      final tryAddBtn = find.text('Coba tambah waktu');
      await tester.ensureVisible(tryAddBtn);
      await tester.tap(tryAddBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TryAddTimeScreen), findsOneWidget);
      final prioritizeFromSimBtn = find.text('Coba prioritaskan tugas ini');
      expect(prioritizeFromSimBtn, findsOneWidget);
      await tester.ensureVisible(prioritizeFromSimBtn);
      await tester.tap(prioritizeFromSimBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TryPrioritizeTaskScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Skenario yang tidak memperbaiki hasil menampilkan status +0 menit dan penjelasan',
    (tester) async {
      final taskEarly = Task(
        id: 't-early',
        title: 'Tugas Tenggat Terlewat Slot',
        remainingMinutes: 90,
        deadlineAt: DateTime.utc(2026, 6, 1, 10, 0), // 17:00 WIB
        createdAt: DateTime.utc(2026, 5, 30),
      );
      final snapshot = PlannerSnapshot(
        revision: 1,
        tasks: [taskEarly],
        timeWindows: [
          TimeWindow(
            id: 'w-night',
            date: '2026-06-01',
            startMinute: 1140, // 19:00 WIB
            endMinute: 1260,
          ),
        ],
        activities: [],
        sessions: [],
      );

      late PlannerController planner;
      await tester.runAsync(() async {
        planner = await _makeController(snapshot);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: TryPrioritizeTaskScreen(planner: planner, task: taskEarly),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada perbaikan'), findsOneWidget);
      expect(find.text('+0 menit'), findsOneWidget);
      expect(find.text('Tidak ada perbaikan alokasi'), findsOneWidget);
    },
  );

  testWidgets(
    'Perubahan data saat simulasi terbuka memicu pemberitahuan dan menghitung ulang perbandingan',
    (tester) async {
      final taskA = Task(
        id: 't-a',
        title: 'Tugas A',
        remainingMinutes: 120,
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
        revision: 2,
        tasks: [taskA, taskB],
        timeWindows: [
          TimeWindow(
            id: 'w-1',
            date: '2026-06-01',
            startMinute: 1140,
            endMinute: 1260,
          ),
        ],
        activities: [],
        sessions: [],
      );

      late PlannerController planner;
      await tester.runAsync(() async {
        planner = await _makeController(snapshot);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: TryPrioritizeTaskScreen(planner: planner, task: taskB),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+120 menit diperoleh'), findsOneWidget);
      expect(find.text('Data berubah selama simulasi'), findsNothing);

      // Tambah kapasitas belajar baru sementara layar simulasi terbuka
      await tester.runAsync(() async {
        await planner.saveWindow(
          TimeWindow(
            id: 'w-2',
            date: '2026-06-02',
            startMinute: 1140,
            endMinute: 1260,
          ),
        );
      });
      await tester.pumpAndSettle();

      // Revisi berubah: tampilkan pemberitahuan & hitung ulang (kini keduanya muat, +0 perbaikan)
      expect(find.text('Data berubah selama simulasi'), findsOneWidget);
      expect(find.text('Tidak ada perbaikan'), findsOneWidget);
      expect(find.text('120 menit'), findsWidgets);
    },
  );
}
