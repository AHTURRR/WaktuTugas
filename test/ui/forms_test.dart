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
  await t.tap(
    find
        .descendant(of: find.byType(NavigationBar), matching: find.text(label))
        .first,
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('phone width and large text keep navigation and forms usable', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final p = PlannerController();
    await boot(t, p);
    for (final name in ['Tugas', 'Waktu', 'Jadwal', 'Ringkasan']) {
      await tab(t, name);
      expect(t.takeException(), isNull);
    }
    await tab(t, 'Tugas');
    await t.tap(find.byTooltip('Tambah tugas'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('title')), 'Layar kecil');
    await t.ensureVisible(find.text('Simpan tugas'));
    await t.tap(find.text('Simpan tugas'));
    await t.pumpAndSettle();
    expect(p.snapshot.tasks.last.title, 'Layar kecil');
    expect(t.takeException(), isNull);
  });
  testWidgets('activity form saves routine then edits into dated closure', (
    t,
  ) async {
    final p = PlannerController();
    await boot(t, p);
    await tab(t, 'Waktu');
    await t.ensureVisible(find.text('Tambah kegiatan'));
    await t.tap(find.text('Tambah kegiatan'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<ActivityKind>));
    await t.pumpAndSettle();
    await t.tap(find.text('Rutin mingguan').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Simpan waktu'));
    await t.tap(find.text('Simpan waktu'));
    await t.pumpAndSettle();
    final activity = p.snapshot.activities.last;
    expect(activity.weekday, 1);
    expect(activity.date, isNull);
    await t.ensureVisible(find.text('Rutin: '));
    await t.tap(find.text('Rutin: '));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<ActivityKind>));
    await t.pumpAndSettle();
    await t.tap(find.text('Penutupan waktu').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Simpan waktu'));
    await t.tap(find.text('Simpan waktu'));
    await t.pumpAndSettle();
    expect(p.snapshot.activities.last.id, activity.id);
    expect(p.snapshot.activities.last.weekday, isNull);
    expect(p.snapshot.activities.last.date, '2026-11-09');
  });
  setUpAll(tz.initializeTimeZones);
  testWidgets('empty name and negative duration keep input and revision', (
    t,
  ) async {
    final p = PlannerController();
    await boot(t, p);
    await tab(t, 'Tugas');
    await t.tap(find.byTooltip('Tambah tugas'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('remaining')), '-1');
    await t.ensureVisible(find.text('Simpan tugas'));
    await t.tap(find.text('Simpan tugas'));
    await t.pumpAndSettle();
    expect(find.text('Nama wajib diisi.'), findsOneWidget);
    expect(find.text('Masukkan menit bulat positif.'), findsOneWidget);
    expect(p.snapshot.revision, 0);
    expect(find.text('-1'), findsOneWidget);
    await t.enterText(find.byKey(const Key('title')), 'Tugas baru');
    await t.enterText(find.byKey(const Key('remaining')), '30');
    await t.ensureVisible(find.text('Simpan tugas'));
    await t.tap(find.text('Simpan tugas'));
    await t.pumpAndSettle();
    expect(p.snapshot.tasks.last.title, 'Tugas baru');
  });
  testWidgets('reversed interval rejected and weekly/date mutually exclusive', (
    t,
  ) async {
    final p = PlannerController();
    await boot(t, p);
    await tab(t, 'Waktu');
    await t.tap(find.text('Tambah rentang'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('start-time')), '22:00');
    await t.enterText(find.byKey(const Key('end-time')), '19:00');
    await t.ensureVisible(find.text('Simpan waktu'));
    await t.tap(find.text('Simpan waktu'));
    await t.pumpAndSettle();
    expect(find.text('Jam selesai harus setelah mulai.'), findsOneWidget);
    expect(p.snapshot.revision, 0);
    await t.enterText(find.byKey(const Key('end-time')), '24:00');
    await t.tap(find.byKey(const Key('scope')));
    await t.pumpAndSettle();
    await t.tap(find.text('Mingguan').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Simpan waktu'));
    await t.tap(find.text('Simpan waktu'));
    await t.pumpAndSettle();
    expect(p.snapshot.timeWindows.last.weekday, isNotNull);
    expect(p.snapshot.timeWindows.last.date, isNull);
    expect(p.snapshot.timeWindows.last.endMinute, 1440);
  });
  testWidgets('delete task requires explicit confirmation', (t) async {
    final p = PlannerController();
    await boot(t, p);
    await tab(t, 'Tugas');
    await t.tap(find.byTooltip('Hapus Laporan Pemrograman Platform'));
    await t.pumpAndSettle();
    await t.tap(find.text('Batal'));
    await t.pumpAndSettle();
    expect(p.snapshot.tasks.length, 3);
    await t.tap(find.byTooltip('Hapus Laporan Pemrograman Platform'));
    await t.pumpAndSettle();
    await t.tap(find.text('Hapus tugas dan sesi'));
    await t.pumpAndSettle();
    expect(p.snapshot.tasks.length, 2);
  });
  testWidgets('full preview confirmation and local progress flow', (t) async {
    final p = PlannerController();
    await boot(t, p);
    await tab(t, 'Jadwal');
    await t.tap(find.text('Hitung pratinjau'));
    await t.pumpAndSettle();
    expect(find.textContaining('120 menit belum tertampung'), findsOneWidget);
    await t.ensureVisible(find.text('Konfirmasi jadwal'));
    await t.tap(find.text('Konfirmasi jadwal'));
    await t.pumpAndSettle();
    expect(p.snapshot.sessions.length, 5);
    await t.ensureVisible(find.text('Majukan jam demo ke sesi berikutnya'));
    await t.tap(find.text('Majukan jam demo ke sesi berikutnya'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('session-${p.snapshot.sessions.first.id}')));
    await t.pumpAndSettle();
    await t.tap(find.text('Selesai dikerjakan'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('remaining-after')), '90');
    await t.tap(find.text('Simpan progres'));
    await t.pumpAndSettle();
    expect(p.snapshot.tasks.first.remainingMinutes, 90);
  });
}
