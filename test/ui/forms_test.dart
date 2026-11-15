import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/features/shared.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';
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
    expect(
      t
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    await t.enterText(find.byKey(const Key('title')), 'Tugas baru');
    await t.enterText(find.byKey(const Key('remaining')), '30');
    await t.pumpAndSettle();
    expect(find.text('Nama wajib diisi.'), findsNothing);
    expect(find.text('Masukkan menit bulat positif.'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is DesignIcon && w.name == 'imgCheckCircle',
      ),
      findsNWidgets(2),
    );
    await t.ensureVisible(find.text('Simpan tugas'));
    await t.tap(find.text('Simpan tugas'));
    await t.pumpAndSettle();
    expect(p.snapshot.tasks.last.title, 'Tugas baru');
  });
  testWidgets('edit form preserves values and accepts zero remaining minutes', (
    t,
  ) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    final p = PlannerController();
    final original = p.snapshot.tasks.first;
    await boot(t, p);
    await tab(t, 'Tugas');
    await t.tap(find.byTooltip('Ubah ${original.title}'));
    await t.pumpAndSettle();

    expect(find.text('Ubah tugas'), findsOneWidget);
    expect(find.text(original.title), findsOneWidget);
    expect(find.text('${original.remainingMinutes}'), findsOneWidget);
    final pickers = find.byType(PickerField);
    expect(pickers, findsNWidgets(2));
    for (final control in [
      pickers.first,
      pickers.last,
      find.byType(AppButton),
      find.widgetWithText(TextButton, 'Batal'),
    ]) {
      expect(t.getSize(control).shortestSide, greaterThanOrEqualTo(48));
    }
    await t.enterText(find.byKey(const Key('remaining')), '0');
    await t.tap(find.text('Simpan tugas'));
    await t.pumpAndSettle();
    final saved = p.taskById(original.id)!;
    expect(saved.remainingMinutes, 0);
    expect(saved.deadlineAt, original.deadlineAt);
    expect(saved.title, original.title);
    expect(saved.course, original.course);
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
  testWidgets('Waktu form edits drive effective WIB capacity and preview', (
    t,
  ) async {
    final now = DateTime.utc(2026, 11, 9, 11); // Monday, 18.00 WIB.
    final p = PlannerController(
      clock: () => now,
      initial: PlannerSnapshot(
        revision: 0,
        tasks: [
          Task(
            id: 'task',
            title: 'Belajar',
            deadlineAt: DateTime.utc(2026, 11, 9, 16),
            remainingMinutes: 240,
            createdAt: now,
          ),
        ],
        timeWindows: [],
        activities: [],
        sessions: [],
      ),
    );
    await boot(t, p);
    await tab(t, 'Waktu');

    Future<void> tap(Finder finder) async {
      await t.ensureVisible(finder);
      await t.tap(finder);
      await t.pumpAndSettle();
    }

    Future<void> hours(String start, String end) async {
      await t.enterText(find.byKey(const Key('start-time')), start);
      await t.enterText(find.byKey(const Key('end-time')), end);
      await tap(find.text('Simpan waktu'));
    }

    Future<void> edit(TimeWindow window) =>
        tap(find.byTooltip('Ubah ${window.id}'));

    Future<void> remove(TimeWindow window) async {
      await tap(find.byTooltip('Hapus ${window.id}'));
      await tap(find.text('Hapus rentang'));
      expect(find.byTooltip('Hapus ${window.id}'), findsNothing);
    }

    await tap(find.text('Tambah rentang'));
    await tap(find.byKey(const Key('scope')));
    await tap(find.text('Mingguan').last);
    await hours('19:00', '22:00');
    final weekly = p.snapshot.timeWindows.single;
    expect(weekly.weekday, DateTime.monday);
    expect(find.text('Senin • 19:00–22:00 WIB'), findsOneWidget);

    await tap(find.text('Tambah rentang'));
    await hours('21:00', '23:00');
    final extra = p.snapshot.timeWindows.singleWhere((w) => w.date != null);
    expect(extra.date, '2026-11-09');
    expect(find.text('9 Nov 2026 • 21:00–23:00 WIB'), findsOneWidget);
    expect(find.text('420 menit'), findsWidgets);

    await tap(find.text('Tambah kegiatan'));
    await t.enterText(
      find.widgetWithText(TextFormField, 'Label kegiatan (opsional)'),
      'Kuliah',
    );
    final revision = p.snapshot.revision;
    await hours('21:00', '20:00');
    expect(find.text('Jam selesai harus setelah mulai.'), findsOneWidget);
    expect(p.snapshot.revision, revision);
    expect(p.snapshot.activities, isEmpty);
    await hours('20:00', '21:00');
    final block = p.snapshot.activities.single;
    expect(block.date, '2026-11-09');
    expect(find.text('Kegiatan sekali: Kuliah'), findsOneWidget);
    expect(find.text('360 menit'), findsWidgets);
    expect(
      find.text('Senin, 9 November 2026 · 19:00–20:00 (60 menit)'),
      findsOneWidget,
    );
    expect(
      find.text('Senin, 9 November 2026 · 21:00–23:00 (120 menit)'),
      findsOneWidget,
    );
    expect(
      find.text('Senin, 16 November 2026 · 19:00–22:00 (180 menit)'),
      findsOneWidget,
    );
    final preview = buildPreview(p.snapshot, now);
    expect(preview.sessions.map((s) => [s.startsAt.hour, s.endsAt.hour]), [
      [12, 13],
      [14, 16],
    ]);
    expect(preview.unallocated.single.minutes, 60);

    await edit(block);
    await hours('20:00', '22:00');
    expect(find.text('300 menit'), findsWidgets);
    await edit(weekly);
    await hours('19:00', '21:00');
    expect(find.text('240 menit'), findsWidgets);
    await edit(extra);
    await hours('21:00', '24:00');
    expect(find.text('300 menit'), findsWidgets);
    await remove(block);
    expect(find.text('420 menit'), findsWidgets);
    await remove(extra);
    expect(find.text('240 menit'), findsWidgets);
    await remove(weekly);
    expect(find.text('0 menit'), findsWidgets);
    expect(p.snapshot.activities, isEmpty);
    expect(p.snapshot.timeWindows, isEmpty);
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
    final firstSession = find.byKey(
      Key('session-${p.snapshot.sessions.first.id}'),
    );
    await t.ensureVisible(firstSession);
    await t.tap(firstSession);
    await t.pumpAndSettle();
    await t.tap(find.text('Selesai dikerjakan'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('remaining-after')), '90');
    await t.tap(find.text('Simpan progres'));
    await t.pumpAndSettle();
    expect(p.snapshot.tasks.first.remainingMinutes, 90);
  });
}
