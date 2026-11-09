import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
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
