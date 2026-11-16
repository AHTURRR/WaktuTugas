import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/schedule/preview_screen.dart';
import 'package:waktu_tugas/features/schedule/suggest_time_screen.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    await initializeDateFormatting('id_ID');
  });

  DateTime getNow() => tz.TZDateTime(jakarta, 2026, 11, 9, 8, 0).toUtc();

  Widget buildTestApp({
    required Widget home,
    GoRouter? router,
  }) {
    if (router != null) {
      return MaterialApp.router(
        theme: buildTheme(brightness: Brightness.light),
        routerConfig: router,
      );
    }
    return MaterialApp(
      theme: buildTheme(brightness: Brightness.light),
      home: home,
    );
  }

  testWidgets(
    'Alur lengkap: ReasonsScreen -> Cari saran waktu -> Tinjau saran -> Simpan slot -> Konfirmasi jadwal',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Basis Data',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 22, 0).toUtc(),
        remainingMinutes: 120,
        createdAt: now,
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskA],
          timeWindows: [],
          activities: [],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);
      expect(await tester.runAsync(() => planner.generatePreview()), isTrue);

      final router = GoRouter(
        initialLocation: '/schedule/preview',
        routes: [
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const Scaffold(body: Text('Layar Jadwal')),
          ),
          GoRoute(
            path: '/schedule/preview',
            builder: (context, state) => PreviewScreen(planner: planner),
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(home: const SizedBox(), router: router));
      await tester.pumpAndSettle();

      // Buka Alasan Kekurangan
      final reasonsBtn = find.text('Mengapa masih kurang?');
      await tester.ensureVisible(reasonsBtn);
      await tester.tap(reasonsBtn);
      await tester.pumpAndSettle();

      // Ketuk "Cari saran waktu"
      final suggestBtn = find.text('Cari saran waktu');
      expect(suggestBtn, findsOneWidget);
      await tester.ensureVisible(suggestBtn);
      await tester.tap(suggestBtn);
      await tester.pumpAndSettle();

      // Verifikasi maksimal 3 saran muncul beserta hasil sebelum & sesudah
      expect(find.text('Saran slot terbaik (3)'), findsOneWidget);
      expect(find.textContaining('Saran #1'), findsOneWidget);
      expect(
        find.textContaining('Sebelum: kurang 120 mnt → Sesudah: kekurangan 0 mnt'),
        findsWidgets,
      );

      // Pilih saran #1 untuk ditinjau
      final reviewBtn = find.text('Tinjau saran').first;
      await tester.ensureVisible(reviewBtn);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      // Masuk ke TryAddTimeScreen dengan slot saran terisi
      expect(find.text('Coba tambah waktu'), findsOneWidget);
      expect(find.text('Kekurangan 0 mnt'), findsOneWidget);

      // Simpan slot
      final saveBtn = find.text('Simpan slot');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(planner.snapshot.timeWindows.length, 1);
      expect(planner.preview!.unallocated, isEmpty);

      // Konfirmasi jadwal pada PreviewScreen
      final confirmBtn = find.text('Konfirmasi jadwal');
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(planner.snapshot.sessions, isNotEmpty);
      expect(find.text('Layar Jadwal'), findsOneWidget);
    },
  );

  testWidgets(
    'Hasil kosong menampilkan alasan dan akses ke input manual',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Terblokir',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
        remainingMinutes: 60,
        createdAt: now,
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskA],
          timeWindows: [],
          activities: [
            Activity(
              id: 'blk-1',
              label: 'Jadwal Kuliah Malam',
              kind: ActivityKind.blocked,
              date: '2026-11-09',
              startMinute: 1140,
              endMinute: 1320,
            ),
            Activity(
              id: 'blk-2',
              label: 'Jadwal Lab',
              kind: ActivityKind.blocked,
              date: '2026-11-10',
              startMinute: 1140,
              endMinute: 1320,
            ),
          ],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);
      await tester.runAsync(() => planner.generatePreview());

      await tester.pumpWidget(
        buildTestApp(
          home: SuggestTimeScreen(
            planner: planner,
            task: taskA,
            unallocatedMinutes: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada saran slot yang membantu'), findsOneWidget);
      expect(
        find.textContaining('terblokir kegiatan tetap dan penutupan'),
        findsOneWidget,
      );

      final manualBtn = find.text('Buka input manual');
      expect(manualBtn, findsOneWidget);
      await tester.ensureVisible(manualBtn);
      await tester.tap(manualBtn);
      await tester.pumpAndSettle();

      expect(find.text('Coba tambah waktu'), findsOneWidget);
    },
  );

  testWidgets(
    'Perubahan revisi selama peninjauan menghitung ulang saran secara otomatis',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Revisi',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 22, 0).toUtc(),
        remainingMinutes: 120,
        createdAt: now,
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskA],
          timeWindows: [],
          activities: [],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);
      await tester.runAsync(() => planner.generatePreview());

      await tester.pumpWidget(
        buildTestApp(
          home: SuggestTimeScreen(
            planner: planner,
            task: taskA,
            unallocatedMinutes: 120,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saran slot terbaik (3)'), findsOneWidget);

      // Data berubah di tempat lain (revisi naik, menambah blokir 9 Nov)
      await tester.runAsync(
        () => planner.saveActivity(
          Activity(
            id: 'blk-sudden',
            label: 'Penutupan mendadak',
            kind: ActivityKind.blocked,
            date: '2026-11-09',
            startMinute: 1140,
            endMinute: 1320,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data jadwal diperbarui'), findsOneWidget);
      // 9 Nov kini terblokir sehingga hanya tersisa 10 Nov & 11 Nov (2 saran)
      expect(find.text('Saran slot terbaik (2)'), findsOneWidget);
    },
  );
}
