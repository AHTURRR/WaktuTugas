import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/schedule/weekly_summary_card.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';
import 'package:waktu_tugas/planner/weekly_summary.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class _OfflinePlanner extends PlannerController {
  final DateTime _cachedAt;
  _OfflinePlanner({super.clock, super.initial, required this._cachedAt});
  @override
  bool get isOfflineSnapshot => true;
  @override
  DateTime? get fetchedAt => _cachedAt;
}

DateTime wib(int y, int mo, int d, int h, [int mi = 0]) =>
    tz.TZDateTime(jakarta, y, mo, d, h, mi).toUtc();

PlannerSession session(
  String id,
  DateTime start,
  DateTime end,
  SessionStatus status,
) => PlannerSession(
  id: id,
  taskId: 't1',
  startsAt: start,
  endsAt: end,
  status: status,
  remainingAfter: status == SessionStatus.completed ? 30 : null,
  closedAt: status == SessionStatus.completed || status == SessionStatus.missed
      ? end
      : null,
);

PlannerSnapshot snap(List<PlannerSession> sessions) => PlannerSnapshot(
  revision: 1,
  tasks: [
    Task(
      id: 't1',
      title: 'Tugas',
      remainingMinutes: 120,
      deadlineAt: wib(2026, 12, 31, 23),
      createdAt: wib(2026, 11, 1, 8),
    ),
  ],
  timeWindows: [],
  activities: [],
  sessions: sessions,
);

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('id_ID');
  });

  // 16 Nov 2026 adalah Senin.
  test('batas minggu Senin–Minggu WIB dan perpindahan minggu', () {
    final sundayLate = wibWeekBounds(wib(2026, 11, 22, 23, 59));
    expect(sundayLate.start, wib(2026, 11, 16, 0));
    expect(sundayLate.end, wib(2026, 11, 23, 0));

    final mondayEarly = wibWeekBounds(wib(2026, 11, 23, 0, 1));
    expect(mondayEarly.start, wib(2026, 11, 23, 0));
    expect(mondayEarly.end, wib(2026, 11, 30, 0));

    // 23:30 Minggu WIB = 16:30 UTC hari yang sama: tetap minggu yang sama.
    expect(wibWeekBounds(DateTime.utc(2026, 11, 22, 16, 30)).start,
        wib(2026, 11, 16, 0));
    // 00:30 Senin WIB = 17:30 UTC Minggu: sudah minggu berikutnya.
    expect(wibWeekBounds(DateTime.utc(2026, 11, 22, 17, 30)).start,
        wib(2026, 11, 23, 0));
  });

  test('sesi di sekitar tengah malam dan sesi yang melewati batas minggu', () {
    final data = snap([
      // Senin 00:00–01:00 WIB (awal minggu) -> 60 menit, selesai.
      session('a', wib(2026, 11, 16, 0), wib(2026, 11, 16, 1),
          SessionStatus.completed),
      // Minggu sebelumnya 23:00–23:59 WIB -> di luar minggu ini.
      session('b', wib(2026, 11, 15, 23), wib(2026, 11, 15, 23, 59),
          SessionStatus.missed),
      // Minggu 23:30 – Senin 00:30 WIB -> hanya 30 menit di minggu ini.
      session('c', wib(2026, 11, 22, 23, 30), wib(2026, 11, 23, 0, 30),
          SessionStatus.planned),
    ]);

    final thisWeek = buildWeeklySummary(data, wib(2026, 11, 18, 12));
    expect(thisWeek.scheduledMinutes, 90);
    expect(thisWeek.completedCount, 1);
    expect(thisWeek.missedCount, 0);
    expect(thisWeek.plannedCount, 1);
    expect(thisWeek.measuredFocusMinutes, isNull);

    final nextWeek = buildWeeklySummary(data, wib(2026, 11, 24, 12));
    expect(nextWeek.scheduledMinutes, 30);
    expect(nextWeek.plannedCount, 1);
    expect(nextWeek.completedCount, 0);

    final lastWeek = buildWeeklySummary(data, wib(2026, 11, 15, 12));
    expect(lastWeek.missedCount, 1);
    expect(lastWeek.scheduledMinutes, 59);
  });

  test('sesi dibatalkan dipisahkan dari terlewat dan tidak dihitung durasinya',
      () {
    final data = snap([
      session('m', wib(2026, 11, 17, 19), wib(2026, 11, 17, 20),
          SessionStatus.missed),
      session('x', wib(2026, 11, 17, 20), wib(2026, 11, 17, 21),
          SessionStatus.cancelled),
    ]);
    final s = buildWeeklySummary(data, wib(2026, 11, 18, 9));
    expect(s.missedCount, 1);
    expect(s.cancelledCount, 1);
    expect(s.scheduledMinutes, 60);
  });

  test('akun kosong menghasilkan ringkasan kosong', () {
    final s = buildWeeklySummary(snap([]), wib(2026, 11, 18, 9));
    expect(s.isEmpty, isTrue);
    expect(s.scheduledMinutes, 0);
  });

  Future<void> pumpCard(WidgetTester t, PlannerController p) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: WeeklySummaryCard(planner: p)),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('kartu kosong menampilkan keadaan kosong dan rentang tanggal',
      (t) async {
    final now = wib(2026, 11, 18, 9);
    await pumpCard(t, PlannerController(clock: () => now, initial: snap([])));
    expect(find.text('Minggu ini'), findsOneWidget);
    expect(find.byKey(const Key('weekly-summary-empty')), findsOneWidget);
    expect(find.textContaining('Sen 16 Nov'), findsOneWidget);
    expect(find.textContaining('Min 22 Nov'), findsOneWidget);
  });

  testWidgets('kartu dengan data dan cache luring menampilkan total dan sumber',
      (t) async {
    final now = wib(2026, 11, 18, 9);
    final planner = _OfflinePlanner(
      clock: () => now,
      cachedAt: wib(2026, 11, 18, 8),
      initial: snap([
        session('a', wib(2026, 11, 16, 19), wib(2026, 11, 16, 20, 30),
            SessionStatus.completed),
        session('m', wib(2026, 11, 17, 19), wib(2026, 11, 17, 20),
            SessionStatus.missed),
        session('x', wib(2026, 11, 17, 20), wib(2026, 11, 17, 21),
            SessionStatus.cancelled),
      ]),
    );
    await pumpCard(t, planner);

    expect(find.textContaining('Dari cache luring'), findsOneWidget);
    expect(find.text('2 jam 30 menit'), findsOneWidget);
    expect(
      (t.widget<Text>(find.byKey(const Key('weekly-completed')))).data,
      '1',
    );
    expect((t.widget<Text>(find.byKey(const Key('weekly-missed')))).data, '1');
    expect(find.byKey(const Key('weekly-cancelled')), findsOneWidget);
    expect(find.byKey(const Key('weekly-source-note')), findsOneWidget);
    expect(find.textContaining('Fokus terukur'), findsNothing);
  });
}
