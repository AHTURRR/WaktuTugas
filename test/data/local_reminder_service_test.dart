import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/data/local_reminder_service.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class _ScheduledRecord {
  final int id;
  final DateTime fireAtUtc;
  final String title;
  final String body;
  final String payload;

  const _ScheduledRecord({
    required this.id,
    required this.fireAtUtc,
    required this.title,
    required this.body,
    required this.payload,
  });
}

class _FakeNotificationGateway implements LocalNotificationGateway {
  bool permissionToGrant = true;
  int cancelAllCount = 0;
  String? launchPayload;
  void Function(String? payload)? onTapCallback;
  final Map<int, _ScheduledRecord> scheduled = {};

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    onTapCallback = onTap;
  }

  @override
  Future<String?> getLaunchPayload() async => launchPayload;

  @override
  Future<bool> requestPermission() async => permissionToGrant;

  @override
  Future<void> scheduleSessionReminder({
    required int id,
    required DateTime fireAtUtc,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled[id] = _ScheduledRecord(
      id: id,
      fireAtUtc: fireAtUtc,
      title: title,
      body: body,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  final now = DateTime.utc(2026, 6, 1, 2, 0); // 09:00 WIB

  PlannerSnapshot makeSnapshot({
    SessionStatus status1 = SessionStatus.planned,
    bool includeSecond = true,
  }) {
    return PlannerSnapshot(
      revision: 1,
      tasks: [
        Task(
          id: 't1',
          title: 'Tugas Algoritma',
          remainingMinutes: 120,
          deadlineAt: DateTime.utc(2026, 6, 3, 16, 59),
          createdAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      timeWindows: [
        TimeWindow(
          id: 'w1',
          date: '2026-06-01',
          startMinute: 1140, // 19:00 WIB
          endMinute: 1320, // 22:00 WIB
        ),
      ],
      activities: [],
      sessions: [
        PlannerSession(
          id: 's1',
          taskId: 't1',
          startsAt: DateTime.utc(2026, 6, 1, 12, 0), // 19:00 WIB
          endsAt: DateTime.utc(2026, 6, 1, 13, 0), // 20:00 WIB
          status: status1,
        ),
        if (includeSecond)
          PlannerSession(
            id: 's2',
            taskId: 't1',
            startsAt: DateTime.utc(2026, 6, 1, 13, 0), // 20:00 WIB
            endsAt: DateTime.utc(2026, 6, 1, 14, 0), // 21:00 WIB
            status: SessionStatus.planned,
          ),
      ],
    );
  }

  test(
    'izin diberikan menjadwalkan sesi yang sudah ada 15 menit sebelum mulai dalam UTC/WIB',
    () async {
      final gateway = _FakeNotificationGateway()..permissionToGrant = true;
      final storage = MemoryLocalReminderStorage();
      final service = LocalSessionReminderService(
        storage: storage,
        gateway: gateway,
        clock: () => now,
      );
      final planner = PlannerController(
        clock: () => now,
        initial: makeSnapshot(),
        reminderService: service,
      );

      final ok = await planner.setLocalReminderEnabled(true);
      expect(ok, isTrue);
      expect(planner.localReminderEnabled, isTrue);
      expect(planner.localReminderError, isNull);
      expect(await storage.isEnabled('demo'), isTrue);

      expect(gateway.scheduled.length, 2);
      final s1Id = LocalSessionReminderService.notificationIdForSession('s1');
      final s1Record = gateway.scheduled[s1Id]!;
      expect(s1Record.fireAtUtc, DateTime.utc(2026, 6, 1, 11, 45)); // 18:45 WIB
      expect(s1Record.body, contains('19:00 WIB'));
      expect(s1Record.payload, 'session:s1');
    },
  );

  test(
    'izin ditolak menjaga pengingat nonaktif dan menampilkan pesan jelas',
    () async {
      final gateway = _FakeNotificationGateway()..permissionToGrant = false;
      final storage = MemoryLocalReminderStorage();
      final service = LocalSessionReminderService(
        storage: storage,
        gateway: gateway,
        clock: () => now,
      );
      final planner = PlannerController(
        clock: () => now,
        initial: makeSnapshot(),
        reminderService: service,
      );

      final ok = await planner.setLocalReminderEnabled(true);
      expect(ok, isFalse);
      expect(planner.localReminderEnabled, isFalse);
      expect(planner.localReminderError, contains('Izin notifikasi Android ditolak'));
      expect(gateway.scheduled, isEmpty);
      expect(await storage.isEnabled('demo'), isFalse);
    },
  );

  test(
    'membatalkan pengingat ketika sesi selesai, terlewat, tugas dihapus, atau keluar/ganti akun',
    () async {
      var currentNow = now;
      final gateway = _FakeNotificationGateway()..permissionToGrant = true;
      final storage = MemoryLocalReminderStorage();
      final service = LocalSessionReminderService(
        storage: storage,
        gateway: gateway,
        clock: () => currentNow,
      );
      final planner = PlannerController(
        clock: () => currentNow,
        initial: makeSnapshot(),
        reminderService: service,
      );

      await planner.setLocalReminderEnabled(true);
      expect(gateway.scheduled.length, 2);

      // Majukan waktu agar s1 sudah mulai, lalu tandai selesai
      currentNow = DateTime.utc(2026, 6, 1, 12, 10);
      await planner.recordProgress('s1', SessionStatus.completed, 60);
      await Future<void>.delayed(Duration.zero);

      final s1Id = LocalSessionReminderService.notificationIdForSession('s1');
      final s2Id = LocalSessionReminderService.notificationIdForSession('s2');
      expect(gateway.scheduled.containsKey(s1Id), isFalse);
      expect(gateway.scheduled.containsKey(s2Id), isTrue);

      // Hapus tugas -> sesi s2 ikut terhapus & pengingat dibatalkan
      await planner.deleteTask('t1', confirmed: true);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.scheduled, isEmpty);

      // Keluar / ganti akun membatalkan semua pengingat
      currentNow = now;
      await service.setEnabled(
        true,
        userKey: 'user-a',
        snapshot: makeSnapshot(),
      );
      expect(gateway.scheduled.length, 2);

      planner.clear();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.scheduled, isEmpty);
      expect(planner.localReminderEnabled, isFalse);

      // Ganti ke user-b yang belum mengaktifkan pengingat
      planner.bindUser('user-b');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.scheduled, isEmpty);
      expect(planner.localReminderEnabled, isFalse);
    },
  );
}
