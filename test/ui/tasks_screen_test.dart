import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/features/shared.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/data/planner_api.dart';
import 'package:waktu_tugas/state/planner_controller.dart';
import 'forms_test.dart' show boot, tab;

class _PendingApi implements PlannerApi {
  final response = Completer<PlannerSnapshot>();

  @override
  Future<PlannerSnapshot> fetchSnapshot() => response.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(tz.initializeTimeZones);

  final now = DateTime.utc(2026, 11, 9, 16, 30);
  Task task(String title, int dayHour, int minute) => Task(
    id: title,
    title: title,
    course: 'Mata kuliah',
    deadlineAt: DateTime.utc(2026, 11, 9, dayHour, minute),
    remainingMinutes: 60,
    createdAt: now.subtract(const Duration(days: 1)),
  );

  for (final (width, brightness) in [
    (375.0, Brightness.light),
    (768.0, Brightness.dark),
    (1280.0, Brightness.light),
  ]) {
    testWidgets('task groups and quick actions at ${width.toInt()} dp', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      final late = task('Tugas A', 16, 0);
      final today = task('Tugas B', 16, 59);
      final upcoming = task('Tugas C', 17, 0);
      final session = PlannerSession(
        id: 'sesi',
        taskId: today.id,
        startsAt: now.subtract(const Duration(hours: 2)),
        endsAt: now.subtract(const Duration(hours: 1)),
        closedAt: now.subtract(const Duration(hours: 1)),
        status: SessionStatus.completed,
        remainingAfter: 60,
      );
      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 0,
          tasks: [upcoming, today, late],
          timeWindows: [],
          activities: [],
          sessions: [session],
        ),
      );
      await boot(t, planner);
      await tab(t, 'Tugas');
      final ordered = [
        'Terlambat',
        late.title,
        'Hari ini',
        today.title,
        'Mendatang',
        upcoming.title,
      ];
      for (var i = 1; i < ordered.length; i++) {
        expect(
          t.getTopLeft(find.text(ordered[i])).dy,
          greaterThan(t.getTopLeft(find.text(ordered[i - 1])).dy),
        );
      }
      expect(find.text('Dalam proses'), findsOneWidget);
      expect(find.text('Belum mulai'), findsNWidgets(2));
      final add = find.byTooltip('Tambah tugas');
      final rail = find.byType(NavigationRail);
      final contentStart = rail.evaluate().isEmpty ? 0 : t.getRect(rail).right;
      expect(t.getCenter(add).dx, closeTo((contentStart + width) / 2, 1));
      expect(t.getSize(add).width, width == 375 ? 335 : 560);
      final checkbox = find.byTooltip('Tandai ${late.title} selesai');
      expect(t.getSize(checkbox), const Size(48, 48));
      await t.tap(checkbox);
      await t.pumpAndSettle();
      expect(find.text('Terlambat'), findsNothing);
      expect(find.text('Tugas selesai'), findsOneWidget);
      final checked = t.widget<Checkbox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Checkbox &&
              widget.semanticLabel == '${late.title} selesai',
        ),
      );
      expect(checked.value, isTrue);
      expect(checked.onChanged, isNull);
      final saved = planner.taskById(late.id)!;
      expect(saved.remainingMinutes, 0);
      expect(saved.deadlineAt, late.deadlineAt);
      expect(saved.course, late.course);
      expect(planner.snapshot.sessions.single, same(session));
      await t.tap(find.byTooltip('Tambah tugas'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('title')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('task list shows loading before the empty state', (t) async {
    final api = _PendingApi();
    final planner = PlannerController(api: api);
    await boot(t, planner);
    await tab(t, 'Tugas');

    final request = planner.fetchSnapshot();
    await t.pump();
    expect(find.text('Memuat tugas…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Belum ada tugas'), findsNothing);
    expect(t.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);

    api.response.complete(planner.snapshot);
    await request;
    await t.pumpAndSettle();
    expect(find.text('Memuat tugas…'), findsNothing);
    expect(find.text('Belum ada tugas'), findsOneWidget);
    expect(t.widget<AppButton>(find.byType(AppButton)).onPressed, isNotNull);
  });
}
