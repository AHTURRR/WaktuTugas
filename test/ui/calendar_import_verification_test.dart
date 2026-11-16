import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/time/calendar_import_screen.dart';
import 'package:waktu_tugas/features/time/time_screen.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class _PartialFailPlannerController extends PlannerController {
  int _saveCalls = 0;

  _PartialFailPlannerController({
    required super.clock,
    required super.initial,
  });

  @override
  Future<bool> saveActivity(Activity activity, {int? expectedRevision}) async {
    _saveCalls++;
    if (_saveCalls == 2) {
      error = 'Gagal menyinkronkan kegiatan kedua.';
      notifyListeners();
      return false;
    }
    return super.saveActivity(activity, expectedRevision: expectedRevision);
  }
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('id_ID');
  });

  final now = DateTime.utc(2026, 6, 1, 2, 0); // 09:00 WIB

  testWidgets('Menu Waktu memiliki tombol Impor kalender', (tester) async {
    final planner = PlannerController(
      clock: () => now,
      initial: PlannerSnapshot(
        revision: 1,
        tasks: [],
        timeWindows: [],
        activities: [],
        sessions: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(brightness: Brightness.light),
        home: Scaffold(body: TimeScreen(planner: planner)),
      ),
    );
    await tester.pumpAndSettle();

    final importBtn = find.text('Impor kalender');
    expect(importBtn, findsOneWidget);

    await tester.ensureVisible(importBtn);
    await tester.tap(importBtn);
    await tester.pumpAndSettle();

    expect(find.byType(CalendarImportScreen), findsOneWidget);
  });

  testWidgets(
    'Alur impor file .ics valid, item dilewati, dampak kapasitas jadwal, dan deteksi impor berulang',
    (tester) async {
      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [
            Task(
              id: 't1',
              title: 'Tugas Kuliah',
              remainingMinutes: 120,
              deadlineAt: DateTime.utc(2026, 6, 2, 16, 59),
              createdAt: DateTime.utc(2026, 5, 30),
            ),
          ],
          timeWindows: [
            TimeWindow(
              id: 'w1',
              date: '2026-06-01',
              startMinute: 1140, // 19:00 WIB
              endMinute: 1260, // 21:00 WIB (120 menit)
            ),
          ],
          activities: [],
          sessions: [],
        ),
      );

      const icsContent = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:ev-1
SUMMARY:Rapat Organisasi
DTSTART:20260601T120000Z
DTEND:20260601T130000Z
END:VEVENT
BEGIN:VEVENT
UID:ev-allday
SUMMARY:Hari Libur
DTSTART;VALUE=DATE:20260602
DTEND;VALUE=DATE:20260603
END:VEVENT
END:VCALENDAR''';

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: CalendarImportScreen(
            planner: planner,
            pickIcsFile: () async =>
                const PickedIcsFile(name: 'jadwal.ics', content: icsContent),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih file .ics'));
      await tester.pumpAndSettle();

      // Menampilkan acara terbaca dalam WIB dan acara dilewati beserta alasan
      expect(find.text('Rapat Organisasi'), findsOneWidget);
      expect(find.text('2026-06-01 · 19:00–20:00 WIB'), findsOneWidget);
      expect(find.text('Hari Libur'), findsOneWidget);
      expect(find.textContaining('sepanjang hari'), findsOneWidget);

      // Simpan sebagai waktu terblokir
      await tester.tap(find.text('Simpan terblokir'));
      await tester.pumpAndSettle();

      expect(planner.snapshot.activities.length, 1);
      expect(planner.snapshot.activities.single.kind, ActivityKind.blocked);
      expect(planner.snapshot.activities.single.label, 'Rapat Organisasi');
      expect(find.text('Sudah pernah diimpor'), findsOneWidget);

      // Verifikasi dampak kapasitas belajar dan pratinjau jadwal
      final available = expandWindows(planner.snapshot, planner.now);
      expect(available.fold<int>(0, (sum, i) => sum + i.minutes), 60);
      await tester.runAsync(() async {
        await planner.generatePreview();
      });
      expect(planner.preview!.unallocated.single.minutes, 60);

      // Impor ulang file yang sama: terdeteksi sudah ada & tidak menggandakan
      await tester.tap(find.text('Ganti file (jadwal.ics)'));
      await tester.pumpAndSettle();
      expect(find.text('Sudah pernah diimpor'), findsOneWidget);
      expect(planner.snapshot.activities.length, 1);
    },
  );

  testWidgets('File .ics rusak menampilkan pesan galat yang jelas', (
    tester,
  ) async {
    final planner = PlannerController(
      clock: () => now,
      initial: PlannerSnapshot(
        revision: 1,
        tasks: [],
        timeWindows: [],
        activities: [],
        sessions: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(brightness: Brightness.light),
        home: CalendarImportScreen(
          planner: planner,
          pickIcsFile: () async => const PickedIcsFile(
            name: 'rusak.ics',
            content: 'BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih file .ics'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal membaca file .ics'), findsOneWidget);
    expect(find.textContaining('VEVENT yang tidak ditutup'), findsOneWidget);
  });

  testWidgets('Impor sebagian gagal menampilkan hasil simpan per item', (
    tester,
  ) async {
    final planner = _PartialFailPlannerController(
      clock: () => now,
      initial: PlannerSnapshot(
        revision: 1,
        tasks: [],
        timeWindows: [],
        activities: [],
        sessions: [],
      ),
    );

    const icsContent = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:ev-a
SUMMARY:Agenda Pertama
DTSTART:20260601T120000Z
DTEND:20260601T130000Z
END:VEVENT
BEGIN:VEVENT
UID:ev-b
SUMMARY:Agenda Kedua
DTSTART:20260602T120000Z
DTEND:20260602T130000Z
END:VEVENT
END:VCALENDAR''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(brightness: Brightness.light),
        home: CalendarImportScreen(
          planner: planner,
          pickIcsFile: () async =>
              const PickedIcsFile(name: 'dua.ics', content: icsContent),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih file .ics'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan terblokir'));
    await tester.pumpAndSettle();

    expect(find.text('Hasil impor'), findsOneWidget);
    expect(find.text('1 berhasil, 1 gagal.'), findsOneWidget);
    expect(find.text('Gagal menyinkronkan kegiatan kedua.'), findsOneWidget);
    expect(planner.snapshot.activities.length, 1);
  });
}
