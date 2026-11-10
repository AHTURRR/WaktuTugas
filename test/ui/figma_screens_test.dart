import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/auth/login_screen.dart';
import 'package:waktu_tugas/features/shared.dart';
import 'package:waktu_tugas/features/time/time_form_screen.dart';
import 'package:waktu_tugas/features/auth/account_screen.dart';
import 'package:waktu_tugas/features/schedule/reasons_screen.dart';
import 'package:waktu_tugas/planner/fixtures.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class RegistrationAuth extends AuthController {
  int registrations = 0, resends = 0;
  @override
  bool get isCloud => true;
  @override
  Future<bool> register(String name, String email, String password) async {
    registrations++;
    return true;
  }

  @override
  Future<bool> resendConfirmation(String email) async {
    resends++;
    return true;
  }
}

class OfflinePlanner extends PlannerController {
  @override
  bool get isOfflineSnapshot => true;
}

class LoadingPlanner extends PlannerController {
  @override
  bool get isApiBacked => true;
  @override
  bool get isPending => true;
}

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    final font = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> capture(WidgetTester t, String name) async {
    expect(t.takeException(), isNull);
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    await t.runAsync(() async {
      final boundary = t.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      const directory = String.fromEnvironment(
        'CAPTURE_DIR',
        defaultValue: 'docs/design/screenshots',
      );
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('main flows at $width dp and text $scale', (t) async {
        t.view.physicalSize = Size(width, 915);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final p = PlannerController();
        await t.pumpWidget(
          RepaintBoundary(
            child: WaktuTugasApp(
              auth: AuthController()..enterDemo(),
              planner: p,
            ),
          ),
        );
        await t.pumpAndSettle();
        final suffix = '${width.toInt()}-$scale';
        await capture(t, 'home-$suffix');
        Future<void> tab(String label) async {
          await t.tap(
            find
                .descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text(label),
                )
                .first,
          );
          await t.pumpAndSettle();
          await capture(t, '${label.toLowerCase()}-$suffix');
        }

        await tab('Tugas');
        await t.tap(find.byTooltip('Tambah tugas'));
        await t.pumpAndSettle();
        await capture(t, 'task-form-$suffix');
        t.view.viewInsets = const FakeViewPadding(bottom: 280);
        await t.pumpAndSettle();
        expect(find.text('Simpan tugas').hitTestable(), findsOneWidget);
        await capture(t, 'task-keyboard-$suffix');
        t.view.resetViewInsets();
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Kembali'));
        await t.pumpAndSettle();
        await tab('Waktu');
        await t.ensureVisible(
          find.text(
            'Izin digabung sekali, lalu dikurangi aktivitas dan penutupan. Waktu kosong bukan izin.',
          ),
        );
        await t.pumpAndSettle();
        await capture(t, 'time-detail-$suffix');
        await tab('Jadwal');
        await t.tap(find.text('Hitung pratinjau'));
        await t.pumpAndSettle();
        expect(find.text('120 menit belum tertampung'), findsOneWidget);
        await capture(t, 'preview-$suffix');
        await t.tap(find.text('Konfirmasi jadwal'));
        await t.pumpAndSettle();
        await capture(t, 'schedule-confirmed-$suffix');
        await t.ensureVisible(find.text('Majukan jam demo ke sesi berikutnya'));
        await t.tap(find.text('Majukan jam demo ke sesi berikutnya'));
        await t.pumpAndSettle();
        final session = find.byKey(
          Key('session-${p.snapshot.sessions.first.id}'),
        );
        await t.ensureVisible(session);
        await t.tap(session);
        await t.pumpAndSettle();
        await capture(t, 'session-$suffix');
        await t.ensureVisible(find.text('Selesai dikerjakan'));
        await t.tap(find.text('Selesai dikerjakan'));
        await t.pumpAndSettle();
        await capture(t, 'progress-$suffix');
        await t.enterText(find.byKey(const Key('remaining-after')), '0');
        await t.tap(find.text('Simpan progres'));
        await t.pumpAndSettle();
        expect(p.snapshot.tasks.first.remainingMinutes, 0);
        expect(p.snapshot.sessions.first.status, SessionStatus.completed);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('registration validates and opens email confirmation', (t) async {
    final auth = RegistrationAuth();
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: LoginScreen(auth: auth),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Belum punya akun? Daftar'));
    await t.tap(find.text('Belum punya akun? Daftar'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Daftar'));
    await t.tap(find.text('Daftar'));
    await t.pumpAndSettle();
    expect(auth.registrations, 0);
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Mahasiswa');
    await t.enterText(fields.at(1), 'mahasiswa@example.com');
    await t.enterText(fields.at(2), 'password123');
    await t.ensureVisible(find.text('Daftar'));
    await t.tap(find.text('Daftar'));
    await t.pumpAndSettle();
    expect(auth.registrations, 1);
    expect(find.text('Konfirmasi email diperlukan'), findsOneWidget);
    await t.ensureVisible(find.text('Kirim ulang email'));
    await t.tap(find.text('Kirim ulang email'));
    await t.pumpAndSettle();
    expect(auth.resends, 1);
    expect(find.text('Email dikirim ulang'), findsOneWidget);
  });

  testWidgets('narrow large text handles empty, long, late and failed forms', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.view.resetViewInsets();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final p = PlannerController(
      initial: PlannerSnapshot(
        revision: 0,
        tasks: [],
        timeWindows: [],
        activities: [],
        sessions: [],
      ),
    );
    await t.pumpWidget(
      RepaintBoundary(
        child: WaktuTugasApp(auth: AuthController()..enterDemo(), planner: p),
      ),
    );
    await t.pumpAndSettle();
    await capture(t, 'empty-home-360-1.8');
    for (final label in ['Tugas', 'Waktu', 'Jadwal']) {
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await t.pumpAndSettle();
      await capture(t, 'empty-${label.toLowerCase()}-360-1.8');
    }
    final title = List.filled(10, 'Penelitian').join(' ');
    await t.runAsync(
      () => p.saveTask(
        title: title,
        course: 'Mata kuliah dengan nama panjang',
        deadline: p.now.subtract(const Duration(days: 1)),
        remaining: 99999,
      ),
    );
    await t.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Tugas'),
      ),
    );
    await t.pumpAndSettle();
    await capture(t, 'long-late-task-360-1.8');
    await t.ensureVisible(find.byTooltip('Hapus $title'));
    final delete = t.getSize(find.byTooltip('Hapus $title'));
    expect(delete.width, greaterThanOrEqualTo(48));
    expect(delete.height, greaterThanOrEqualTo(48));
    await t.tap(find.byTooltip('Tambah tugas'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('remaining')), '-1');
    await t.tap(find.text('Simpan tugas'));
    await t.pumpAndSettle();
    expect(find.text('Nama wajib diisi.'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    t.view.viewInsets = const FakeViewPadding(bottom: 280);
    await t.pumpAndSettle();
    expect(find.text('Simpan tugas').hitTestable(), findsOneWidget);
    await t.ensureVisible(find.text('Masukkan menit bulat positif.'));
    await t.pumpAndSettle();
    await capture(t, 'invalid-keyboard-360-1.8');
  });

  testWidgets('keyboard traverses authentication fields', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: LoginScreen(auth: RegistrationAuth()),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(TextFormField).first);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(
      t.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus,
      isTrue,
    );
    expect(t.takeException(), isNull);
  });

  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('auth, account and time forms at $width and $scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 915);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        Future<void> show(Widget screen, String name) async {
          await t.pumpWidget(
            RepaintBoundary(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                key: UniqueKey(),
                theme: buildTheme(),
                home: screen,
              ),
            ),
          );
          await t.pumpAndSettle();
          await capture(
            t,
            width == 412 && scale == 1 ? name : '$name-${width.toInt()}-$scale',
          );
        }

        final p = PlannerController();
        await show(LoginScreen(auth: RegistrationAuth()), 'login-412');
        await t.ensureVisible(find.text('Belum punya akun? Daftar'));
        await t.tap(find.text('Belum punya akun? Daftar'));
        await t.pumpAndSettle();
        await capture(t, 'register-${width.toInt()}-$scale');
        await show(LoginScreen(auth: AuthController()), 'local-demo-412');
        await show(AccountScreen(auth: AuthController()), 'account-412');
        await t.runAsync(p.generatePreview);
        await show(ReasonsScreen(planner: p), 'reasons-412');
        await show(TimeFormScreen(planner: p), 'extra-range-412');
        await show(
          TimeFormScreen(
            planner: p,
            window: TimeWindow(
              id: 'weekly',
              weekday: 1,
              startMinute: 1140,
              endMinute: 1320,
            ),
          ),
          'weekly-range-412',
        );
        for (final kind in ActivityKind.values) {
          await show(
            TimeFormScreen(
              planner: p,
              activity: true,
              window: Activity(
                id: 'activity',
                kind: kind,
                label: 'Kegiatan belajar',
                weekday: kind == ActivityKind.routine ? 1 : null,
                date: kind == ActivityKind.routine ? null : '2026-11-09',
                startMinute: 1140,
                endMinute: 1200,
              ),
            ),
            'activity-${kind.name}-412',
          );
        }
      });
    }
  }
  testWidgets(
    'stale preview cannot confirm and terminal sessions stay read-only',
    (t) async {
      final p = PlannerController();
      await t.runAsync(() async {
        await p.generatePreview();
        await p.confirmSchedule();
        p.advanceDemoClock();
        await p.recordProgress(
          p.snapshot.sessions.first.id,
          SessionStatus.completed,
          90,
        );
      });
      await t.pumpWidget(
        WaktuTugasApp(auth: AuthController()..enterDemo(), planner: p),
      );
      await t.pumpAndSettle();
      await t.tap(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text('Jadwal'),
            )
            .first,
      );
      await t.pumpAndSettle();
      final session = find.byKey(
        Key('session-${p.snapshot.sessions.first.id}'),
      );
      await t.ensureVisible(session);
      await t.tap(session);
      await t.pumpAndSettle();
      expect(find.text('Hanya baca · sesi sudah ditutup'), findsOneWidget);
      expect(find.text('Simpan progres'), findsNothing);
      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Hitung pratinjau'));
      await t.tap(find.text('Hitung pratinjau'));
      await t.pumpAndSettle();
      await t.runAsync(
        () => p.saveTask(
          id: 'T01',
          title: 'Diubah',
          deadline: demoSnapshot().tasks.first.deadlineAt,
          course: null,
          remaining: 80,
        ),
      );
      await t.pumpAndSettle();
      final confirm = t.widget<AppButton>(
        find.widgetWithText(AppButton, 'Konfirmasi jadwal'),
      );
      expect(confirm.onPressed, isNull);
      expect(
        find.text('Pratinjau kedaluwarsa · belum tersimpan'),
        findsOneWidget,
      );
    },
  );

  testWidgets('offline disables mutations and loading labels the wait', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await t.pumpWidget(
      RepaintBoundary(
        child: WaktuTugasApp(
          auth: AuthController()..enterDemo(),
          planner: OfflinePlanner(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await capture(t, 'offline-360');
    expect(find.text('Luring · hanya baca'), findsOneWidget);
    await t.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Tugas'),
          )
          .first,
    );
    await t.pumpAndSettle();
    final add = t.widget<AppButton>(
      find.widgetWithText(AppButton, 'Tambah tugas'),
    );
    expect(add.onPressed, isNull);
    await t.pumpWidget(
      RepaintBoundary(
        child: WaktuTugasApp(
          key: UniqueKey(),
          auth: AuthController()..enterDemo(),
          planner: LoadingPlanner(),
        ),
      ),
    );
    await t.pump();
    await capture(t, 'loading-360');
    expect(find.text('Menyiapkan ruang fokus'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('landscape navigation and reduced-motion press remain usable', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 412);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    await t.pumpWidget(
      WaktuTugasApp(
        auth: AuthController()..enterDemo(),
        planner: PlannerController(),
      ),
    );
    await t.pumpAndSettle();
    final button = find.byType(AppButton).first;
    final before = t.getRect(button);
    final press = await t.startGesture(t.getCenter(button));
    await t.pump(const Duration(milliseconds: 120));
    expect(t.getRect(button), before);
    await press.cancel();
    await t.pumpAndSettle();
    for (final label in ['Tugas', 'Waktu', 'Jadwal', 'Ringkasan']) {
      await t.tap(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            )
            .first,
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'multi-date closure saves every inclusive date without opening extra time',
    (t) async {
      final p = PlannerController();
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: TimeFormScreen(planner: p, activity: true),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<ActivityKind>));
      await t.pumpAndSettle();
      await t.tap(find.text('Penutupan waktu').last);
      await t.pumpAndSettle();
      final endDate = find.byType(PickerField).last;
      await t.ensureVisible(endDate);
      await t.tap(endDate);
      await t.pumpAndSettle();
      await t.tap(find.text('11').last);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.text('Simpan waktu'));
      await t.pumpAndSettle();
      final closures = p.snapshot.activities.where(
        (a) => a.kind == ActivityKind.blocked,
      );
      expect(closures.map((a) => a.date), [
        '2026-11-09',
        '2026-11-10',
        '2026-11-11',
      ]);
      expect(closures.every((a) => a.weekday == null), isTrue);
    },
  );
}
