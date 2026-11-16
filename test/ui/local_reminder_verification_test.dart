import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/data/local_reminder_service.dart';
import 'package:waktu_tugas/features/auth/account_screen.dart';
import 'package:waktu_tugas/features/schedule/session_screen.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class _TestGateway implements LocalNotificationGateway {
  bool permissionToGrant = true;
  String? launchPayload;
  void Function(String? payload)? onTap;
  final Map<int, DateTime> scheduled = {};

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    this.onTap = onTap;
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
    scheduled[id] = fireAtUtc;
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> cancelAll() async => scheduled.clear();
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('id_ID');
  });

  final now = DateTime.utc(2026, 6, 1, 2, 0); // 09:00 WIB

  PlannerSnapshot sampleSnapshot() {
    return PlannerSnapshot(
      revision: 1,
      tasks: [
        Task(
          id: 't1',
          title: 'Tugas Basis Data',
          remainingMinutes: 60,
          deadlineAt: DateTime.utc(2026, 6, 3, 16, 59),
          createdAt: DateTime.utc(2026, 5, 30),
        ),
      ],
      timeWindows: [
        TimeWindow(
          id: 'w1',
          date: '2026-06-01',
          startMinute: 1140,
          endMinute: 1200,
        ),
      ],
      activities: [],
      sessions: [
        PlannerSession(
          id: 's1',
          taskId: 't1',
          startsAt: DateTime.utc(2026, 6, 1, 12, 0), // 19:00 WIB
          endsAt: DateTime.utc(2026, 6, 1, 13, 0),
          status: SessionStatus.planned,
        ),
      ],
    );
  }

  testWidgets(
    'AccountScreen menampilkan sakelar pengingat lokal terpisah dan menangani izin diberikan/ditolak',
    (tester) async {
      final gateway = _TestGateway()..permissionToGrant = false;
      final service = LocalSessionReminderService(
        storage: MemoryLocalReminderStorage(),
        gateway: gateway,
        clock: () => now,
      );
      final planner = PlannerController(
        clock: () => now,
        initial: sampleSnapshot(),
        reminderService: service,
      );
      final auth = AuthController()..enterDemo();
      final themeMode = ValueNotifier(ThemeMode.light);
      addTearDown(themeMode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: AccountScreen(
            auth: auth,
            themeMode: themeMode,
            planner: planner,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pengingat sesi lokal'), findsOneWidget);
      expect(find.text('Pengingat 15 menit sebelum sesi'), findsOneWidget);

      // 1. Izin ditolak -> tetap nonaktif & tampilkan pesan
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(planner.localReminderEnabled, isFalse);
      expect(find.text('Izin notifikasi diperlukan'), findsOneWidget);

      // 2. Izin diberikan -> aktif & menjadwalkan sesi yang ada
      gateway.permissionToGrant = true;
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(planner.localReminderEnabled, isTrue);
      expect(gateway.scheduled.length, 1);

      // 3. Matikan sakelar -> membatalkan pengingat
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(planner.localReminderEnabled, isFalse);
      expect(gateway.scheduled, isEmpty);
    },
  );

  testWidgets(
    'Mengetuk notifikasi saat aplikasi ditutup (cold-start) membuka detail sesi jika masih tersedia',
    (tester) async {
      final gateway = _TestGateway()..launchPayload = 'session:s1';
      final service = LocalSessionReminderService(
        storage: MemoryLocalReminderStorage(),
        gateway: gateway,
        clock: () => now,
      );
      final planner = PlannerController(
        clock: () => now,
        initial: sampleSnapshot(),
        reminderService: service,
      );
      final auth = AuthController()..enterDemo();

      await tester.pumpWidget(WaktuTugasApp(auth: auth, planner: planner));
      await tester.pumpAndSettle();

      expect(find.byType(SessionScreen), findsOneWidget);
      expect(find.text('Tugas Basis Data'), findsWidgets);
    },
  );

  testWidgets(
    'Mengetuk notifikasi untuk sesi yang sudah dihapus tidak memicu error navigasi',
    (tester) async {
      final gateway = _TestGateway();
      final service = LocalSessionReminderService(
        storage: MemoryLocalReminderStorage(),
        gateway: gateway,
        clock: () => now,
      );
      final planner = PlannerController(
        clock: () => now,
        initial: sampleSnapshot(),
        reminderService: service,
      );
      final auth = AuthController()..enterDemo();

      await tester.pumpWidget(WaktuTugasApp(auth: auth, planner: planner));
      await tester.pumpAndSettle();

      // Ketuk payload sesi yang tidak ada
      gateway.onTap?.call('session:sesi-hilang');
      await tester.pumpAndSettle();

      expect(find.byType(SessionScreen), findsNothing);
    },
  );
}
