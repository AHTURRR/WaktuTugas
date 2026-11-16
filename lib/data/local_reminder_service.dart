import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import '../planner/models.dart';
import '../planner/schedule.dart';

/// Penyimpanan status aktif/nonaktif pengingat lokal per akun.
abstract class LocalReminderStorage {
  Future<bool> isEnabled(String userKey);
  Future<void> setEnabled(String userKey, bool enabled);
}

class SecureLocalReminderStorage implements LocalReminderStorage {
  final FlutterSecureStorage storage;
  const SecureLocalReminderStorage(this.storage);

  String _key(String userKey) => 'waktutugas.local_reminder.$userKey';

  @override
  Future<bool> isEnabled(String userKey) async {
    try {
      return await storage.read(key: _key(userKey)) == 'true';
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> setEnabled(String userKey, bool enabled) async {
    try {
      await storage.write(
        key: _key(userKey),
        value: enabled ? 'true' : 'false',
      );
    } on Exception {
      debugPrint('Preferensi pengingat lokal tidak dapat disimpan.');
    }
  }
}

class MemoryLocalReminderStorage implements LocalReminderStorage {
  final Map<String, bool> _store = {};

  @override
  Future<bool> isEnabled(String userKey) async => _store[userKey] ?? false;

  @override
  Future<void> setEnabled(String userKey, bool enabled) async {
    _store[userKey] = enabled;
  }
}

/// Abstraksi gateway notifikasi lokal agar logika penjadwalan dapat diuji terisolasi.
abstract class LocalNotificationGateway {
  Future<void> initialize({required void Function(String? payload) onTap});
  Future<String?> getLaunchPayload();
  Future<bool> requestPermission();
  Future<void> scheduleSessionReminder({
    required int id,
    required DateTime fireAtUtc,
    required String title,
    required String body,
    required String payload,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

class FlutterLocalNotificationGateway implements LocalNotificationGateway {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  FlutterLocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (_initialized) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _initialized = true;
      return;
    }
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    _initialized = true;
  }

  @override
  Future<String?> getLaunchPayload() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  @override
  Future<void> scheduleSessionReminder({
    required int id,
    required DateTime fireAtUtc,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final scheduled = tz.TZDateTime.from(fireAtUtc, jakarta);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'session_reminders',
        'Pengingat Sesi Belajar',
        channelDescription:
            'Pengingat lokal 15 menit sebelum sesi belajar yang dikonfirmasi dimulai.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: mode,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _plugin.cancelAll();
  }
}

/// Layanan pengingat lokal 15 menit sebelum sesi belajar yang dikonfirmasi.
class LocalSessionReminderService {
  static const Duration leadTime = Duration(minutes: 15);
  static const String payloadPrefix = 'session:';

  final LocalReminderStorage storage;
  final LocalNotificationGateway gateway;
  final DateTime Function() clock;

  bool _enabled = false;
  String? _userKey;
  String? lastError;

  LocalSessionReminderService({
    required this.storage,
    required this.gateway,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  bool get isEnabled => _enabled;

  static int notificationIdForSession(String sessionId) {
    // FNV-1a 32-bit stabil lintas sesi & platform, dipetakan ke int positif 31-bit.
    var hash = 0x811c9dc5;
    for (final unit in sessionId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static String? sessionIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    final id = payload.substring(payloadPrefix.length).trim();
    return id.isEmpty ? null : id;
  }

  Future<void> initialize({
    required void Function(String sessionId) onOpenSession,
  }) async {
    await gateway.initialize(
      onTap: (payload) {
        final sessionId = sessionIdFromPayload(payload);
        if (sessionId != null) onOpenSession(sessionId);
      },
    );
    final launchPayload = await gateway.getLaunchPayload();
    final launchSessionId = sessionIdFromPayload(launchPayload);
    if (launchSessionId != null) {
      onOpenSession(launchSessionId);
    }
  }

  Future<void> loadForUser(String userKey) async {
    _userKey = userKey;
    lastError = null;
    _enabled = await storage.isEnabled(userKey);
  }

  Future<bool> setEnabled(
    bool value, {
    required String? userKey,
    required PlannerSnapshot snapshot,
    String Function(String taskId)? taskTitleLookup,
  }) async {
    lastError = null;
    _userKey = userKey;
    if (!value) {
      _enabled = false;
      if (userKey != null) await storage.setEnabled(userKey, false);
      await gateway.cancelAll();
      return true;
    }

    final granted = await gateway.requestPermission();
    if (!granted) {
      _enabled = false;
      if (userKey != null) await storage.setEnabled(userKey, false);
      await gateway.cancelAll();
      lastError =
          'Izin notifikasi Android ditolak. Aktifkan izin notifikasi di pengaturan perangkat.';
      return false;
    }

    _enabled = true;
    if (userKey != null) await storage.setEnabled(userKey, true);
    await syncSessions(snapshot, taskTitleLookup: taskTitleLookup);
    return true;
  }

  Future<void> syncSessions(
    PlannerSnapshot snapshot, {
    String Function(String taskId)? taskTitleLookup,
  }) async {
    await gateway.cancelAll();
    if (!_enabled || _userKey == null) return;

    final now = clock().toUtc();
    for (final session in snapshot.sessions) {
      if (session.status != SessionStatus.planned) continue;
      final fireAtUtc = session.startsAt.toUtc().subtract(leadTime);
      if (!fireAtUtc.isAfter(now)) continue;

      final taskTitle = taskTitleLookup?.call(session.taskId) ?? 'Sesi belajar';
      final startWib = tz.TZDateTime.from(session.startsAt, jakarta);
      final hh = startWib.hour.toString().padLeft(2, '0');
      final mm = startWib.minute.toString().padLeft(2, '0');
      await gateway.scheduleSessionReminder(
        id: notificationIdForSession(session.id),
        fireAtUtc: fireAtUtc,
        title: 'Sesi belajar 15 menit lagi',
        body: '$taskTitle dimulai pukul $hh:$mm WIB.',
        payload: '$payloadPrefix${session.id}',
      );
    }
  }

  Future<void> onSignedOutOrSwitched() async {
    _enabled = false;
    _userKey = null;
    lastError = null;
    await gateway.cancelAll();
  }
}
