import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets('mobile tabs and wide sidebar retain the same selection', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(375, 812);
    t.view.padding = const FakeViewPadding(bottom: 24);
    t.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(() {
      t.view.resetDevicePixelRatio();
      t.view.resetPhysicalSize();
      t.view.resetPadding();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await t.pumpWidget(
      WaktuTugasApp(
        auth: AuthController()..enterDemo(),
        planner: PlannerController(),
      ),
    );
    await t.pumpAndSettle();

    final bar = find.byType(NavigationBar);
    expect(t.getRect(bar).bottom, lessThanOrEqualTo(812 - 24));
    final tasks = find.widgetWithText(NavigationDestination, 'Tugas');
    expect(t.getSize(tasks).shortestSide, greaterThanOrEqualTo(48));
    await t.tap(tasks);
    await t.pumpAndSettle();
    expect(t.widget<NavigationBar>(bar).selectedIndex, 1);

    t.view.physicalSize = const Size(1024, 812);
    await t.pumpAndSettle();
    final rail = find.byType(NavigationRail);
    expect(bar, findsNothing);
    expect(t.widget<NavigationRail>(rail).selectedIndex, 1);
    final focusedLabel = find.descendant(
      of: rail,
      matching: find.byWidgetPredicate(
        (w) => w is Text && w.style?.decoration == TextDecoration.underline,
      ),
    );
    for (var i = 0; i < 20 && focusedLabel.evaluate().isEmpty; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
    }
    expect(focusedLabel, findsOneWidget);
    await t.tap(find.descendant(of: rail, matching: find.text('Jadwal')));
    await t.pumpAndSettle();
    expect(t.widget<NavigationRail>(rail).selectedIndex, 3);

    t.view.physicalSize = const Size(375, 812);
    await t.pumpAndSettle();
    expect(t.widget<NavigationBar>(bar).selectedIndex, 3);
  });
  testWidgets('login redirect, four tabs, root form/back, missing preview', (
    tester,
  ) async {
    final auth = AuthController();
    final planner = PlannerController();
    await tester.pumpWidget(WaktuTugasApp(auth: auth, planner: planner));
    await tester.pumpAndSettle();
    expect(find.text('Buka demo lokal'), findsOneWidget);
    await tester.ensureVisible(find.text('Buka demo lokal'));
    await tester.tap(find.text('Buka demo lokal'));
    await tester.pumpAndSettle();
    for (final label in ['Tugas', 'Waktu', 'Jadwal', 'Ringkasan']) {
      await tester.tap(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    }
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Tugas'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah tugas'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(NavigationBar));
    // Navigate using the same router the application exposes.
    GoRouter.of(context).go('/schedule/preview');
    await tester.pumpAndSettle();
    expect(find.text('Hitung pratinjau terlebih dahulu.'), findsOneWidget);
    auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Buka demo lokal'), findsOneWidget);
    expect(planner.snapshot.tasks, isEmpty);
  });
}
