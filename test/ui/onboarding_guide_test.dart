import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/data/onboarding_storage.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  final baseNow = DateTime.utc(2026, 11, 9, 11); // Senin, 18:00 WIB

  Future<PlannerController> pumpApp(
    WidgetTester t, {
    required PlannerSnapshot snapshot,
    OnboardingStorage? onboardingStorage,
    String? userId,
  }) async {
    t.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
    t.view.devicePixelRatio = 2.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });

    final auth = AuthController()..enterDemo();
    final planner = PlannerController(
      clock: () => baseNow,
      initial: snapshot,
      onboardingStorage: onboardingStorage,
      userId: userId,
    );
    addTearDown(planner.dispose);
    await t.runAsync(() => planner.loadOnboardingState());

    await t.pumpWidget(WaktuTugasApp(auth: auth, planner: planner));
    await t.pumpAndSettle();
    return planner;
  }

  PlannerSnapshot emptySnapshot() => PlannerSnapshot(
    revision: 0,
    tasks: [],
    timeWindows: [],
    activities: [],
    sessions: [],
  );

  Task sampleTask() => Task(
    id: 'T01',
    title: 'Tugas Basis Data',
    course: 'IF201',
    deadlineAt: DateTime.utc(2026, 11, 12, 12),
    remainingMinutes: 90,
    createdAt: baseNow,
  );

  TimeWindow sampleWindow() => TimeWindow(
    id: 'W01',
    date: '2026-11-10',
    startMinute: 1140, // 19:00
    endMinute: 1260,   // 21:00
  );

  testWidgets(
    'Akun kosong menampilkan panduan langkah 1 dan menavigasi ke form tugas',
    (t) async {
      await pumpApp(t, snapshot: emptySnapshot());

      expect(find.text('Langkah awal penggunaan'), findsOneWidget);
      expect(find.text('0 dari 3 langkah selesai'), findsOneWidget);
      expect(find.text('1. Buat satu tugas'), findsOneWidget);
      expect(find.text('Buat tugas'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);

      await t.ensureVisible(find.text('Buat tugas'));
      await t.tap(find.text('Buat tugas'));
      await t.pumpAndSettle();

      expect(find.text('Tambah tugas'), findsWidgets);
    },
  );

  testWidgets(
    'Pengguna sudah punya tugas langsung diarahkan ke langkah 2 (tambah waktu belajar)',
    (t) async {
      await pumpApp(
        t,
        snapshot: PlannerSnapshot(
          revision: 1,
          tasks: [sampleTask()],
          timeWindows: [],
          activities: [],
          sessions: [],
        ),
      );

      expect(find.text('Langkah awal penggunaan'), findsOneWidget);
      expect(find.text('1 dari 3 langkah selesai'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('2. Tambah waktu belajar'), findsOneWidget);
      expect(find.text('Tambah waktu belajar'), findsOneWidget);
      expect(find.text('Buat tugas'), findsNothing);

      await t.ensureVisible(find.text('Tambah waktu belajar'));
      await t.tap(find.text('Tambah waktu belajar'));
      await t.pumpAndSettle();

      expect(find.text('Simpan waktu'), findsOneWidget);
    },
  );

  testWidgets(
    'Pengguna sudah punya waktu belajar diarahkan kembali ke langkah 1 (buat tugas)',
    (t) async {
      await pumpApp(
        t,
        snapshot: PlannerSnapshot(
          revision: 1,
          tasks: [],
          timeWindows: [sampleWindow()],
          activities: [],
          sessions: [],
        ),
      );

      expect(find.text('Langkah awal penggunaan'), findsOneWidget);
      expect(find.text('1 dari 3 langkah selesai'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Buat tugas'), findsOneWidget);
      expect(find.text('Tambah waktu belajar'), findsNothing);
    },
  );

  testWidgets(
    'Alur selesai: langkah 3 membuka pratinjau pertama dan menyimpan status selesai saat dibuka ulang',
    (t) async {
      final storage = MemoryOnboardingStorage();
      final snapshot = PlannerSnapshot(
        revision: 2,
        tasks: [sampleTask()],
        timeWindows: [sampleWindow()],
        activities: [],
        sessions: [],
      );

      final planner = await pumpApp(
        t,
        snapshot: snapshot,
        onboardingStorage: storage,
        userId: 'user-a',
      );

      expect(find.text('Langkah awal penggunaan'), findsOneWidget);
      expect(find.text('2 dari 3 langkah selesai'), findsOneWidget);
      expect(find.text('Selesai'), findsNWidgets(2));
      expect(find.text('Buka pratinjau'), findsOneWidget);

      await t.ensureVisible(find.text('Buka pratinjau'));
      await t.tap(find.text('Buka pratinjau'));
      await t.pumpAndSettle();

      // Berhasil mencapai pratinjau pertama
      expect(find.text('Pratinjau jadwal'), findsOneWidget);
      expect(find.text('Konfirmasi jadwal'), findsOneWidget);
      expect(planner.isOnboardingFinished, isTrue);
      expect(await storage.isFinished('user-a'), isTrue);

      // Simulasi buka ulang aplikasi pada akun yang sama
      await pumpApp(
        t,
        snapshot: snapshot,
        onboardingStorage: storage,
        userId: 'user-a',
      );
      expect(find.text('Langkah awal penggunaan'), findsNothing);
    },
  );

  testWidgets(
    'Alur lewati: menyembunyikan panduan dan tidak muncul lagi setelah aplikasi dibuka ulang',
    (t) async {
      final storage = MemoryOnboardingStorage();

      await pumpApp(
        t,
        snapshot: emptySnapshot(),
        onboardingStorage: storage,
      );

      expect(find.text('Langkah awal penggunaan'), findsOneWidget);
      await t.ensureVisible(find.text('Lewati'));
      await t.tap(find.text('Lewati'));
      await t.pumpAndSettle();

      expect(find.text('Langkah awal penggunaan'), findsNothing);
      expect(await storage.isFinished('demo'), isTrue);

      // Buka ulang pada akun yang sama: panduan tetap tidak muncul
      await pumpApp(
        t,
        snapshot: emptySnapshot(),
        onboardingStorage: storage,
      );
      expect(find.text('Langkah awal penggunaan'), findsNothing);
    },
  );

  testWidgets(
    'Isolasi akun: status selesai/lewati tidak memengaruhi akun baru lain',
    (t) async {
      final storage = MemoryOnboardingStorage();
      await storage.markFinished('akun-a');

      final auth = AuthController();
      final planner = PlannerController(
        clock: () => baseNow,
        initial: emptySnapshot(),
        onboardingStorage: storage,
        userId: 'akun-b',
      );
      addTearDown(planner.dispose);
      await t.runAsync(() => planner.loadOnboardingState());

      expect(planner.isOnboardingFinished, isFalse);
      expect(planner.shouldShowOnboardingGuide, isTrue);
      auth.dispose();
    },
  );

  testWidgets(
    'Pengguna lama yang sudah memiliki sesi langsung memakai aplikasi tanpa panduan',
    (t) async {
      final snapshot = PlannerSnapshot(
        revision: 3,
        tasks: [sampleTask()],
        timeWindows: [sampleWindow()],
        activities: [],
        sessions: [
          PlannerSession(
            id: 'S01',
            taskId: 'T01',
            startsAt: DateTime.utc(2026, 11, 10, 12),
            endsAt: DateTime.utc(2026, 11, 10, 13, 30),
            status: SessionStatus.planned,
          ),
        ],
      );

      await pumpApp(t, snapshot: snapshot);

      expect(find.text('SESI BERIKUTNYA'), findsOneWidget);
      expect(find.text('Langkah awal penggunaan'), findsNothing);
    },
  );
}
