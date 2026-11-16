import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

Future<void> boot(WidgetTester t, PlannerController p) async {
  await t.pumpWidget(
    WaktuTugasApp(auth: AuthController()..enterDemo(), planner: p),
  );
  await t.pumpAndSettle();
}

Future<void> tab(WidgetTester t, String label) async {
  final navigation = find.byWidgetPredicate(
    (widget) => widget is NavigationBar || widget is NavigationRail,
  );
  await t.tap(
    find.descendant(of: navigation, matching: find.text(label)).first,
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets(
    'Alur lengkap verifikasi sesi: selesai sisa positif, selesai sisa nol, terlewat, tolak penutupan ganda, dan konsistensi penjadwalan ulang',
    (t) async {
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1.0;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });

      final p = PlannerController();
      await boot(t, p);
      debugPrint('[STEP 1] Boot selesai, navigasi ke Jadwal');

      // 1. Masuk ke tab Jadwal dan konfirmasi jadwal awal
      await tab(t, 'Jadwal');
      await t.tap(find.text('Hitung pratinjau'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Konfirmasi jadwal'));
      await t.tap(find.text('Konfirmasi jadwal'));
      await t.pumpAndSettle();
      expect(p.snapshot.sessions.length, 5);
      debugPrint('[STEP 2] Jadwal awal terkonfirmasi dengan 5 sesi');

      final session1 = p.snapshot.sessions[0]; // Sesi 1 (T01)
      // =========================================================================
      // 1. UJI SESI SELESAI DENGAN SISA POSITIF (remaining = 90)
      // =========================================================================
      await t.ensureVisible(find.text('Majukan jam demo ke sesi berikutnya'));
      await t.tap(find.text('Majukan jam demo ke sesi berikutnya'));
      await t.pumpAndSettle();
      debugPrint('[STEP 3] Jam demo dimajukan ke sesi 1');

      final sessionCard1 = find.byKey(Key('session-${session1.id}'));
      await t.ensureVisible(sessionCard1);
      await t.tap(sessionCard1);
      await t.pumpAndSettle();
      debugPrint('[STEP 4] Detail sesi 1 dibuka');

      expect(find.text('Selesai dikerjakan'), findsOneWidget);
      await t.tap(find.text('Selesai dikerjakan'));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('remaining-after')), '90');
      await t.tap(find.text('Simpan progres'));
      await t.pumpAndSettle();
      debugPrint('[STEP 5] Progres sesi 1 disimpan (90 menit)');

      expect(p.sessionById(session1.id)!.status, SessionStatus.completed);
      expect(p.sessionById(session1.id)!.remainingAfter, 90);
      expect(p.taskById(session1.taskId)!.remainingMinutes, 90);

      // Buka kembali sesi 1 untuk memastikan status hanya baca di UI
      await t.ensureVisible(sessionCard1);
      await t.tap(sessionCard1);
      await t.pumpAndSettle();
      expect(find.text('Hanya baca · sesi sudah ditutup'), findsOneWidget);
      expect(find.textContaining('90 menit'), findsWidgets);
      expect(find.text('Selesai dikerjakan'), findsNothing);
      expect(find.text('Tandai terlewat'), findsNothing);
      debugPrint('[STEP 6] Verifikasi sesi 1 read-only berhasil');

      // Kembali ke layar Jadwal
      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();

      // =========================================================================
      // 2. UJI UPAYA MENUTUP SESI YANG SAMA DUA KALI (AC12)
      // =========================================================================
      final revBeforeDoubleClose = p.snapshot.revision;
      final doubleCloseResult = await t.runAsync(
        () => p.recordProgress(session1.id, SessionStatus.completed, 0),
      );
      expect(doubleCloseResult, isFalse, reason: 'Penutupan kedua kali harus ditolak');
      expect(p.snapshot.revision, revBeforeDoubleClose, reason: 'Revisi tidak boleh bertambah');
      expect(p.taskById(session1.taskId)!.remainingMinutes, 90);
      debugPrint('[STEP 7] Upaya penutupan sesi 1 kedua kali berhasil ditolak');

      // =========================================================================
      // 3. UJI PENJADWALAN ULANG KONSISTEN DENGAN SISA 90 MENIT
      // =========================================================================
      await t.ensureVisible(find.text('Hitung pratinjau'));
      await t.tap(find.text('Hitung pratinjau'));
      await t.pumpAndSettle();
      expect(p.preview, isNotNull);

      // T01 harus dialokasikan tepat 90 menit sesuai sisa pengerjaan baru
      final t01Allocated = p.preview!.sessions
          .where((s) => s.taskId == session1.taskId)
          .fold<int>(0, (sum, s) => sum + s.endsAt.difference(s.startsAt).inMinutes);
      expect(
        t01Allocated,
        90,
        reason: 'Tugas T01 yang bersisa 90 menit harus dialokasikan tepat 90 menit di pratinjau',
      );

      await t.ensureVisible(find.text('Konfirmasi jadwal'));
      await t.tap(find.text('Konfirmasi jadwal'));
      await t.pumpAndSettle();
      debugPrint('[STEP 8] Jadwal baru terkonfirmasi dengan alokasi 90 menit untuk T01');

      // Riwayat sesi 1 tetap completed
      expect(p.sessionById(session1.id)!.status, SessionStatus.completed);
      // Sesi lama yang diganti menjadi cancelled
      expect(
        p.snapshot.sessions.where((s) => s.status == SessionStatus.cancelled),
        isNotEmpty,
      );

      // =========================================================================
      // 4. UJI SESI TERLEWAT (missed) TIDAK MENGURANGI SISA TUGAS (AC11)
      // =========================================================================
      await t.ensureVisible(find.text('Majukan jam demo ke sesi berikutnya'));
      await t.tap(find.text('Majukan jam demo ke sesi berikutnya'));
      await t.pumpAndSettle();

      final nextPlannedSession1 = p.snapshot.sessions.firstWhere(
        (s) => s.status == SessionStatus.planned && s.startsAt.isAfter(p.now.subtract(const Duration(seconds: 2))),
      );
      final nextCard1 = find.byKey(Key('session-${nextPlannedSession1.id}'));
      await t.ensureVisible(nextCard1);
      await t.tap(nextCard1);
      await t.pumpAndSettle();

      final remainingBeforeMissed = p.taskById(nextPlannedSession1.taskId)!.remainingMinutes;
      expect(find.text('Tandai terlewat'), findsOneWidget);
      await t.tap(find.text('Tandai terlewat'));
      await t.pumpAndSettle();
      debugPrint('[STEP 9] Sesi berikutnya ditandai terlewat');

      expect(p.sessionById(nextPlannedSession1.id)!.status, SessionStatus.missed);
      expect(p.sessionById(nextPlannedSession1.id)!.remainingAfter, isNull);
      expect(
        p.taskById(nextPlannedSession1.taskId)!.remainingMinutes,
        remainingBeforeMissed,
        reason: 'Sesi terlewat tidak boleh mengubah sisa pengerjaan tugas (AC11)',
      );

      // Upaya menutup sesi terlewat untuk kedua kali ditolak
      final doubleCloseMissed = await t.runAsync(
        () => p.recordProgress(nextPlannedSession1.id, SessionStatus.missed, null),
      );
      expect(doubleCloseMissed, isFalse);
      debugPrint('[STEP 10] Upaya penutupan sesi terlewat kedua kali berhasil ditolak');

      // Buka kembali untuk memastikan read-only
      await t.ensureVisible(nextCard1);
      await t.tap(nextCard1);
      await t.pumpAndSettle();
      expect(find.text('Hanya baca · sesi sudah ditutup'), findsOneWidget);
      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();

      // =========================================================================
      // 5. UJI SESI SELESAI DENGAN SISA NOL (remaining = 0)
      // =========================================================================
      await t.ensureVisible(find.text('Majukan jam demo ke sesi berikutnya'));
      await t.tap(find.text('Majukan jam demo ke sesi berikutnya'));
      await t.pumpAndSettle();

      final nextPlannedSession2 = p.snapshot.sessions.firstWhere(
        (s) => s.status == SessionStatus.planned && s.startsAt.isAfter(p.now.subtract(const Duration(seconds: 2))),
      );
      final nextCard2 = find.byKey(Key('session-${nextPlannedSession2.id}'));
      await t.ensureVisible(nextCard2);
      await t.tap(nextCard2);
      await t.pumpAndSettle();

      await t.tap(find.text('Selesai dikerjakan'));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('remaining-after')), '0');
      await t.tap(find.text('Simpan progres'));
      await t.pumpAndSettle();
      debugPrint('[STEP 11] Sesi ditandai selesai dengan sisa 0 menit');

      expect(p.sessionById(nextPlannedSession2.id)!.status, SessionStatus.completed);
      expect(p.sessionById(nextPlannedSession2.id)!.remainingAfter, 0);
      expect(p.taskById(nextPlannedSession2.taskId)!.remainingMinutes, 0);

      // Upaya menutup sesi sisa 0 untuk kedua kali ditolak
      final doubleCloseZero = await t.runAsync(
        () => p.recordProgress(nextPlannedSession2.id, SessionStatus.completed, 10),
      );
      expect(doubleCloseZero, isFalse);
      debugPrint('[STEP 12] Upaya penutupan sesi selesai kedua kali berhasil ditolak');

      // =========================================================================
      // 6. UJI PENJADWALAN BERIKUTNYA TIDAK MENGALOKASIKAN TUGAS DENGAN SISA 0
      // =========================================================================
      await t.ensureVisible(find.text('Hitung pratinjau'));
      await t.tap(find.text('Hitung pratinjau'));
      await t.pumpAndSettle();
      debugPrint('[STEP 13] Pratinjau baru berhasil dihitung');

      expect(p.preview, isNotNull);

      // Tugas dengan sisa 0 menit tidak boleh menerima alokasi sesi baru
      final newAllocated = p.preview!.sessions;
      expect(
        newAllocated.where((s) => s.taskId == nextPlannedSession2.taskId),
        isEmpty,
        reason: 'Tugas dengan sisa 0 menit tidak boleh menerima alokasi sesi baru di pratinjau',
      );

      // Konfirmasi jadwal baru
      await t.ensureVisible(find.text('Konfirmasi jadwal'));
      await t.tap(find.text('Konfirmasi jadwal'));
      await t.pumpAndSettle();
      debugPrint('[STEP 14] Jadwal baru berhasil dikonfirmasi');

      // =========================================================================
      // 7. VERIFIKASI RIWAYAT SESI MENAMPILKAN STATUS DENGAN BENAR
      // =========================================================================
      // - Sesi 1 (completed, sisa 90)
      expect(p.sessionById(session1.id)!.status, SessionStatus.completed);
      expect(p.sessionById(session1.id)!.remainingAfter, 90);

      // - Sesi terlewat (missed)
      expect(p.sessionById(nextPlannedSession1.id)!.status, SessionStatus.missed);
      expect(p.sessionById(nextPlannedSession1.id)!.remainingAfter, isNull);

      // - Sesi selesai dengan sisa 0 (completed)
      expect(p.sessionById(nextPlannedSession2.id)!.status, SessionStatus.completed);
      expect(p.sessionById(nextPlannedSession2.id)!.remainingAfter, 0);

      // - Sesi yang digantikan (cancelled)
      expect(
        p.snapshot.sessions.where((s) => s.status == SessionStatus.cancelled),
        isNotEmpty,
      );

      // - Di tab Jadwal UI, semua sesi riwayat muncul dengan label status yang sesuai
      expect(find.text('Selesai'), findsWidgets);
      expect(find.text('Terlewat'), findsWidgets);
      expect(find.text('Dibatalkan'), findsWidgets);

      debugPrint('[SELESAI] Seluruh alur verifikasi berhasil 100%');
    },
  );
}
