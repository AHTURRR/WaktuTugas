import 'models.dart';

final demoNow = DateTime.utc(2026, 11, 9, 11);

PlannerSnapshot demoSnapshot() => PlannerSnapshot(
  revision: 0,
  tasks: [
    Task(
      id: 'T01',
      title: 'Laporan Pemrograman Platform',
      deadlineAt: DateTime.utc(2026, 11, 11, 11),
      remainingMinutes: 240,
      createdAt: demoNow,
    ),
    Task(
      id: 'T02',
      title: 'Latihan Basis Data',
      deadlineAt: DateTime.utc(2026, 11, 12, 16),
      remainingMinutes: 120,
      createdAt: demoNow,
    ),
    Task(
      id: 'T03',
      title: 'Presentasi Interaksi Manusia Komputer',
      deadlineAt: DateTime.utc(2026, 11, 13, 5),
      remainingMinutes: 180,
      createdAt: demoNow,
    ),
  ],
  timeWindows: [
    TimeWindow(
      id: 'W01',
      date: '2026-11-09',
      startMinute: 1140,
      endMinute: 1320,
    ),
    TimeWindow(
      id: 'W02',
      date: '2026-11-10',
      startMinute: 1140,
      endMinute: 1260,
    ),
    TimeWindow(
      id: 'W03',
      date: '2026-11-11',
      startMinute: 1140,
      endMinute: 1260,
    ),
    TimeWindow(
      id: 'W04',
      date: '2026-11-12',
      startMinute: 1140,
      endMinute: 1200,
    ),
  ],
  activities: [
    Activity(
      id: 'A01',
      date: '2026-11-09',
      startMinute: 1200,
      endMinute: 1260,
      kind: ActivityKind.event,
      label: 'Kegiatan kampus',
    ),
  ],
  sessions: [],
);
