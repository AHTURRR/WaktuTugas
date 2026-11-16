import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/schedule/preview_screen.dart';
import 'package:waktu_tugas/features/schedule/try_add_time_screen.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class _OfflinePlanner extends PlannerController {
  _OfflinePlanner({super.initial, super.clock});
  @override
  bool get isOfflineSnapshot => true;
}

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
    'Alur lengkap: Buka dari Alasan Kekurangan -> Simulasi Penuh -> Simpan Slot -> Konfirmasi Jadwal',
    (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Mobile Programming',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
        remainingMinutes: 180,
        createdAt: now,
      );

      // Hanya ada 60 menit waktu belajar awal -> kurang 120 menit
      final initialWindow = TimeWindow(
        id: 'win-1',
        date: '2026-11-09',
        startMinute: 960, // 16:00
        endMinute: 1020,  // 17:00
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskA],
          timeWindows: [initialWindow],
          activities: [],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);

      // Hitung pratinjau awal
      expect(await tester.runAsync(() => planner.generatePreview()), isTrue);
      expect(planner.preview!.unallocated.length, 1);
      expect(planner.preview!.unallocated.single.minutes, 120);

      // Setup GoRouter dengan rute /schedule/preview dan /schedule
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

      // Buka alasan kekurangan
      final reasonsBtn = find.text('Mengapa masih kurang?');
      expect(reasonsBtn, findsOneWidget);
      await tester.ensureVisible(reasonsBtn);
      await tester.tap(reasonsBtn);
      await tester.pumpAndSettle();

      // Di Layar Alasan Kekurangan, tombol "Coba tambah waktu" harus ada
      expect(find.text('Mengapa masih kurang?'), findsOneWidget);
      final tryAddBtn = find.text('Coba tambah waktu');
      expect(tryAddBtn, findsOneWidget);

      // Ketuk "Coba tambah waktu"
      await tester.ensureVisible(tryAddBtn);
      await tester.tap(tryAddBtn);
      await tester.pumpAndSettle();

      // Berada di TryAddTimeScreen
      expect(find.text('Coba tambah waktu'), findsWidgets);
      expect(find.textContaining('Tugas Mobile Programming'), findsWidgets);

      // Verifikasi metrik simulasi: Sebelum 120 mnt -> Sesudah 0 mnt (Kekurangan 0 mnt)
      expect(find.text('Kurang 120 mnt'), findsOneWidget);
      expect(find.text('Kekurangan 0 mnt'), findsOneWidget);
      expect(find.textContaining('Kekurangan kapasitas terpenuhi sepenuhnya!'), findsOneWidget);

      // Ketuk "Simpan slot"
      final saveBtn = find.text('Simpan slot');
      expect(saveBtn, findsOneWidget);
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Setelah simpan, slot baru tersimpan di controller dan pratinjau terupdate otomatis
      expect(planner.snapshot.timeWindows.length, 2);
      expect(planner.preview!.unallocated, isEmpty, reason: 'Kekurangan sudah teratasi di pratinjau baru');

      // Kembali ke PreviewScreen
      expect(find.text('Konfirmasi jadwal'), findsOneWidget);

      // Lakukan konfirmasi jadwal
      final confirmBtn = find.text('Konfirmasi jadwal');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Jadwal berhasil dikonfirmasi dan sesi tersimpan
      expect(planner.snapshot.sessions.length, 2);
      expect(find.text('Layar Jadwal'), findsOneWidget);
    },
  );

  testWidgets(
    'Simulasi kekurangan sebagian: Menampilkan sisa menit dan penjelasan',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Grafika Komputer',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 11, 12, 0).toUtc(),
        remainingMinutes: 180,
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
          home: TryAddTimeScreen(
            planner: planner,
            task: taskA,
            unallocatedMinutes: 180,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ubah jam selesai menjadi 20:00 (hanya 60 menit)
      final endField = find.widgetWithText(TextFormField, 'Jam selesai');
      expect(endField, findsOneWidget);
      await tester.enterText(endField, '20:00');
      await tester.pumpAndSettle();

      // Periksa hasil simulasi kekurangan sebagian
      expect(find.text('Kurang 180 mnt'), findsOneWidget);
      expect(find.text('Kurang 120 mnt'), findsOneWidget);
      expect(
        find.textContaining('tetapi tugas masih kekurangan 120 menit'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Simulasi tabrakan waktu: Menampilkan peringatan tabrakan dengan penutupan',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Jaringan Komputer',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
        remainingMinutes: 120,
        createdAt: now,
      );

      // Kegiatan blocked 20:00 - 21:00
      final blocked = Activity(
        id: 'act-1',
        date: '2026-11-09',
        startMinute: 1200,
        endMinute: 1260,
        kind: ActivityKind.blocked,
        label: 'Kuliah Tamu',
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskA],
          timeWindows: [],
          activities: [blocked],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);
      await tester.runAsync(() => planner.generatePreview());

      await tester.pumpWidget(
        buildTestApp(
          home: TryAddTimeScreen(
            planner: planner,
            task: taskA,
            unallocatedMinutes: 120,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default slot 19:00 - 21:00 (120 mnt) bertabrakan dengan Kuliah Tamu (60 mnt)
      expect(
        find.textContaining('bertabrakan dengan kegiatan atau penutupan lain sebesar 60 menit'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Simulasi dampak pada tugas lain: Menampilkan perubahan alokasi tugas lain',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas A (Tenggat Cepat)',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
        remainingMinutes: 120,
        createdAt: now,
      );
      final taskB = Task(
        id: 'task-b',
        title: 'Tugas B (Tenggat Lambat)',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 12, 22, 0).toUtc(),
        remainingMinutes: 60,
        createdAt: now,
      );

      // Slot awal 60 menit diambil Task A
      final win1 = TimeWindow(
        id: 'win-1',
        date: '2026-11-09',
        startMinute: 1140,
        endMinute: 1200,
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskA, taskB],
          timeWindows: [win1],
          activities: [],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);
      await tester.runAsync(() => planner.generatePreview());

      await tester.pumpWidget(
        buildTestApp(
          home: TryAddTimeScreen(
            planner: planner,
            task: taskA,
            unallocatedMinutes: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Atur slot tambahan 120 menit (1200 - 1320)
      // Task A ambil 60 mnt, Task B ambil 60 mnt
      final startField = find.widgetWithText(TextFormField, 'Jam mulai');
      final endField = find.widgetWithText(TextFormField, 'Jam selesai');
      await tester.enterText(startField, '20:00');
      await tester.enterText(endField, '22:00');
      await tester.pumpAndSettle();

      // Dampak pada Tugas B ditampilkan
      expect(find.text('Dampak pada tugas lain'), findsOneWidget);
      expect(find.text('Tugas B (Tenggat Lambat)'), findsOneWidget);
      expect(find.text('+60 mnt'), findsOneWidget);
    },
  );

  testWidgets(
    'Pembatalan: Ketuk Batal menutup layar tanpa mengubah snapshot',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Batal',
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
          activities: [],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);
      await tester.runAsync(() => planner.generatePreview());

      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => TryAddTimeScreen(
                      planner: planner,
                      task: taskA,
                      unallocatedMinutes: 60,
                    ),
                  ),
                ),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Coba tambah waktu'), findsWidgets);

      // Ketuk Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Kembali ke layar awal dan snapshot timeWindows tetap kosong
      expect(find.text('Buka'), findsOneWidget);
      expect(planner.snapshot.timeWindows, isEmpty);
      expect(planner.snapshot.revision, 1);
    },
  );

  testWidgets(
    'Kondisi luring: Menyimpan slot diblokir dengan pesan yang jelas',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Offline',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
        remainingMinutes: 60,
        createdAt: now,
      );

      final planner = _OfflinePlanner(
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
          home: TryAddTimeScreen(
            planner: planner,
            task: taskA,
            unallocatedMinutes: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ketuk Simpan slot
      await tester.tap(find.text('Simpan slot'));
      await tester.pumpAndSettle();

      // Peringatan mode luring muncul dan slot tidak tersimpan
      expect(
        find.text('Mode luring hanya baca. Tidak dapat menyimpan slot baru.'),
        findsOneWidget,
      );
      expect(planner.snapshot.timeWindows, isEmpty);
    },
  );

  testWidgets(
    'Revisi basi: Menolak simpan jika data telah berubah di tempat lain',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Stale',
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
          activities: [],
          sessions: [],
        ),
      );
      addTearDown(planner.dispose);
      await tester.runAsync(() => planner.generatePreview());

      await tester.pumpWidget(
        buildTestApp(
          home: TryAddTimeScreen(
            planner: planner,
            task: taskA,
            unallocatedMinutes: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulasikan mutasi di tempat lain (revisi naik)
      await tester.runAsync(
        () => planner.saveTask(
          title: 'Tugas Baru Dari Perangkat Lain',
          course: null,
          deadline: DateTime.utc(2026, 11, 20),
          remaining: 30,
        ),
      );
      expect(planner.snapshot.revision, 2);

      // Ketuk Simpan slot pada form yang masih menggunakan revisi 1
      await tester.tap(find.text('Simpan slot'));
      await tester.pumpAndSettle();

      // Menolak dengan pesan revisi terbaru
      expect(
        find.textContaining('Data jadwal telah diperbarui di tempat lain'),
        findsOneWidget,
      );
      expect(planner.snapshot.timeWindows, isEmpty);
    },
  );

  testWidgets(
    'Simpan berhasil tetapi kalkulasi pratinjau gagal: Menampilkan status dan tombol Buka Jadwal',
    (tester) async {
      final now = getNow();
      final taskA = Task(
        id: 'task-a',
        title: 'Tugas Preview Gagal',
        deadlineAt: tz.TZDateTime(jakarta, 2026, 11, 10, 22, 0).toUtc(),
        remainingMinutes: 60,
        createdAt: now,
      );

      // Buat controller dengan sesi planned yang sudah lewat waktu mulai (sehingga generatePreview gagal)
      final pastSession = PlannerSession(
        id: 'sess-past',
        taskId: taskA.id,
        startsAt: now.subtract(const Duration(minutes: 30)),
        endsAt: now.add(const Duration(minutes: 30)),
        status: SessionStatus.planned,
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskA],
          timeWindows: [],
          activities: [],
          sessions: [pastSession],
        ),
      );
      addTearDown(planner.dispose);

      final router = GoRouter(
        initialLocation: '/try',
        routes: [
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const Scaffold(body: Text('Layar Jadwal Recovery')),
          ),
          GoRoute(
            path: '/try',
            builder: (context, state) => TryAddTimeScreen(
              planner: planner,
              task: taskA,
              unallocatedMinutes: 60,
            ),
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(home: const SizedBox(), router: router));
      await tester.pumpAndSettle();

      // Ketuk Simpan slot
      await tester.tap(find.text('Simpan slot'));
      await tester.pumpAndSettle();

      // Slot BERHASIL tersimpan
      expect(planner.snapshot.timeWindows.length, 1);

      // Tetapi Notice status muncul karena generatePreview gagal akibat sesi started
      expect(find.text('Slot belajar tersimpan'), findsOneWidget);
      expect(
        find.textContaining('pembuatan pratinjau jadwal otomatis belum berhasil'),
        findsOneWidget,
      );

      // Tombol 'Buka Jadwal' muncul
      final recoveryBtn = find.text('Buka Jadwal');
      expect(recoveryBtn, findsOneWidget);
      await tester.tap(recoveryBtn);
      await tester.pumpAndSettle();

      expect(find.text('Layar Jadwal Recovery'), findsOneWidget);
    },
  );
}
