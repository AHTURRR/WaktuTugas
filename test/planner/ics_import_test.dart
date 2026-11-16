import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/planner/ics_import.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  const parser = IcsCalendarParser();

  test('membaca file .ics valid dengan UTC dan zona waktu lain ke WIB', () {
    const ics = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:ev-utc
SUMMARY:Rapat Proyek, Tim A
DTSTART:20260601T120000Z
DTEND:20260601T140000Z
END:VEVENT
BEGIN:VEVENT
UID:ev-tokyo
SUMMARY:Seminar
  Daring
DTSTART;TZID=Asia/Tokyo:20260602T210000
DTEND;TZID=Asia/Tokyo:20260602T223000
END:VEVENT
END:VCALENDAR''';

    final result = parser.parse(ics);
    expect(result.skipped, isEmpty);
    expect(result.candidates.length, 2);

    // 12:00-14:00 UTC -> 19:00-21:00 WIB (1140..1260)
    final c1 = result.candidates[0];
    expect(c1.summary, 'Rapat Proyek, Tim A');
    expect(c1.sourceTimeZone, 'UTC');
    expect(c1.segments.single.date, '2026-06-01');
    expect(c1.segments.single.startMinute, 1140);
    expect(c1.segments.single.endMinute, 1260);

    // 21:00-22:30 Asia/Tokyo (+9) -> 19:00-20:30 WIB (+7) (1140..1230)
    final c2 = result.candidates[1];
    expect(c2.summary, 'Seminar Daring');
    expect(c2.sourceTimeZone, 'Asia/Tokyo');
    expect(c2.segments.single.date, '2026-06-02');
    expect(c2.segments.single.startMinute, 1140);
    expect(c2.segments.single.endMinute, 1230);
  });

  test('menolak file .ics rusak atau tidak lengkap', () {
    expect(() => parser.parse(''), throwsFormatException);
    expect(
      () => parser.parse('BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR'),
      throwsFormatException,
    );
    expect(() => parser.parse('BUKAN FILE ICS'), throwsFormatException);
  });

  test(
    'melewati acara sepanjang hari, aturan pengulangan, dan zona waktu tidak dikenal dengan alasan',
    () {
      const ics = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:all-day
SUMMARY:Libur Nasional
DTSTART;VALUE=DATE:20260601
DTEND;VALUE=DATE:20260602
END:VEVENT
BEGIN:VEVENT
UID:recurring
SUMMARY:Kuliah Mingguan
DTSTART;TZID=Asia/Jakarta:20260601T090000
DTEND;TZID=Asia/Jakarta:20260601T110000
RRULE:FREQ=WEEKLY;COUNT=4
END:VEVENT
BEGIN:VEVENT
UID:bad-tz
SUMMARY:Konferensi Planet
DTSTART;TZID=Mars/Olympus:20260601T090000
DTEND;TZID=Mars/Olympus:20260601T100000
END:VEVENT
END:VCALENDAR''';

      final result = parser.parse(ics);
      expect(result.candidates, isEmpty);
      expect(result.skipped.length, 3);
      expect(result.skipped[0].summary, 'Libur Nasional');
      expect(result.skipped[0].reason, contains('sepanjang hari'));
      expect(result.skipped[1].summary, 'Kuliah Mingguan');
      expect(result.skipped[1].reason, contains('pengulangan'));
      expect(result.skipped[2].summary, 'Konferensi Planet');
      expect(result.skipped[2].reason, contains('Mars/Olympus'));
    },
  );

  test('mendeteksi acara yang sudah pernah diimpor agar tidak digandakan', () {
    const ics = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:ev-1
SUMMARY:Rapat Tim
DTSTART:20260601T120000Z
DTEND:20260601T130000Z
END:VEVENT
END:VCALENDAR''';

    final existing = [
      Activity(
        id: 'existing-uuid-from-server',
        date: '2026-06-01',
        startMinute: 1140,
        endMinute: 1200,
        kind: ActivityKind.blocked,
        label: 'Rapat Tim',
      ),
    ];

    final result = parser.parse(ics, existingActivities: existing);
    expect(result.candidates.length, 1);
    expect(result.candidates.single.isDuplicate, isTrue);
  });

  test('acara terimpor memotong kapasitas belajar di pratinjau jadwal', () {
    const ics = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:ev-block
SUMMARY:Rapat Malam
DTSTART:20260601T120000Z
DTEND:20260601T130000Z
END:VEVENT
END:VCALENDAR''';

    final parsed = parser.parse(ics);
    final blocked = parsed.candidates.single.segments.single.toBlockedActivity(
      id: 'act-1',
    );

    final now = DateTime.utc(2026, 6, 1, 2, 0); // 09:00 WIB
    final baseSnapshot = PlannerSnapshot(
      revision: 1,
      tasks: [
        Task(
          id: 't1',
          title: 'Tugas',
          remainingMinutes: 120,
          deadlineAt: DateTime.utc(2026, 6, 2, 16, 59),
          createdAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      timeWindows: [
        TimeWindow(
          id: 'w1',
          date: '2026-06-01',
          startMinute: 1140, // 19:00
          endMinute: 1260, // 21:00 (120 menit)
        ),
      ],
      activities: [],
      sessions: [],
    );

    final previewBefore = buildPreview(baseSnapshot, now);
    expect(previewBefore.unallocated, isEmpty);

    final snapshotWithImport = PlannerSnapshot(
      revision: 2,
      tasks: baseSnapshot.tasks,
      timeWindows: baseSnapshot.timeWindows,
      activities: [blocked],
      sessions: const [],
    );
    final previewAfter = buildPreview(snapshotWithImport, now);
    expect(previewAfter.sessions.single.endsAt.difference(previewAfter.sessions.single.startsAt).inMinutes, 60);
    expect(previewAfter.unallocated.single.minutes, 60);
    expect(
      previewAfter.unallocated.single.reason,
      UnallocatedReason.insufficientCapacity,
    );
  });
}
