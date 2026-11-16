import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../planner/models.dart';

/// State timer fokus aktif untuk satu sesi belajar per akun.
class SessionTimerState {
  final String sessionId;
  final String taskId;
  final bool isRunning;
  final int accumulatedSeconds;
  final DateTime? startedAtUtc;

  const SessionTimerState({
    required this.sessionId,
    required this.taskId,
    required this.isRunning,
    required this.accumulatedSeconds,
    this.startedAtUtc,
  });

  Duration elapsedAt(DateTime now) {
    final base = math.max(0, accumulatedSeconds);
    if (!isRunning || startedAtUtc == null) {
      return Duration(seconds: base);
    }
    final delta = math.max(
      0,
      now.toUtc().difference(startedAtUtc!.toUtc()).inSeconds,
    );
    return Duration(seconds: base + delta);
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'task_id': taskId,
    'is_running': isRunning,
    'accumulated_seconds': accumulatedSeconds,
    'started_at_utc': startedAtUtc?.toUtc().toIso8601String(),
  };

  factory SessionTimerState.fromJson(Map<String, dynamic> json) {
    final startedRaw = json['started_at_utc'] as String?;
    return SessionTimerState(
      sessionId: json['session_id'] as String,
      taskId: json['task_id'] as String,
      isRunning: json['is_running'] as bool? ?? false,
      accumulatedSeconds: json['accumulated_seconds'] as int? ?? 0,
      startedAtUtc: startedRaw == null ? null : DateTime.parse(startedRaw),
    );
  }
}

/// Penyimpanan state timer aktif per akun.
abstract class SessionTimerStorage {
  Future<SessionTimerState?> read(String userKey);
  Future<void> write(String userKey, SessionTimerState? state);
}

class SecureSessionTimerStorage implements SessionTimerStorage {
  final FlutterSecureStorage storage;
  const SecureSessionTimerStorage(this.storage);

  String _key(String userKey) => 'waktutugas.session_timer.$userKey';

  @override
  Future<SessionTimerState?> read(String userKey) async {
    try {
      final raw = await storage.read(key: _key(userKey));
      if (raw == null || raw.isEmpty) return null;
      return SessionTimerState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(String userKey, SessionTimerState? state) async {
    try {
      if (state == null) {
        await storage.delete(key: _key(userKey));
      } else {
        await storage.write(key: _key(userKey), value: jsonEncode(state.toJson()));
      }
    } on Exception {
      debugPrint('State timer sesi tidak dapat disimpan.');
    }
  }
}

class MemorySessionTimerStorage implements SessionTimerStorage {
  final Map<String, SessionTimerState> _store = {};

  @override
  Future<SessionTimerState?> read(String userKey) async => _store[userKey];

  @override
  Future<void> write(String userKey, SessionTimerState? state) async {
    if (state == null) {
      _store.remove(userKey);
    } else {
      _store[userKey] = state;
    }
  }
}

/// Layanan timer fokus sesi berbasis cap waktu dengan batas satu timer aktif per akun.
class SessionTimerService {
  final SessionTimerStorage storage;
  final DateTime Function() clock;

  SessionTimerState? _active;
  String? _userKey;
  bool _busy = false;
  int _stateVersion = 0;
  String? lastError;

  SessionTimerService({
    required this.storage,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  SessionTimerState? get activeTimer => _active;

  bool isActiveFor(String sessionId) => _active?.sessionId == sessionId;

  bool hasOtherActiveSession(String sessionId) =>
      _active != null && _active!.sessionId != sessionId;

  Duration elapsedFor(String sessionId) {
    final active = _active;
    if (active == null || active.sessionId != sessionId) return Duration.zero;
    return active.elapsedAt(clock());
  }

  Future<void> loadForUser(String userKey, PlannerSnapshot snapshot) async {
    _userKey = userKey;
    lastError = null;
    final versionAtStart = _stateVersion;
    final loaded = await storage.read(userKey);
    if (_stateVersion != versionAtStart || _userKey != userKey) return;
    _active = loaded;
    await reconcileWithSnapshot(snapshot);
  }

  Future<void> reconcileWithSnapshot(PlannerSnapshot snapshot) async {
    final active = _active;
    if (active == null) return;
    final matching = snapshot.sessions
        .where((s) => s.id == active.sessionId)
        .firstOrNull;
    if (matching == null || matching.status != SessionStatus.planned) {
      _active = null;
      if (_userKey != null) {
        await storage.write(_userKey!, null);
      }
    }
  }

  Future<bool> start(PlannerSession session, {required String userKey}) async {
    if (_busy) return false;
    _busy = true;
    try {
      _userKey = userKey;
      lastError = null;
      if (_active != null && _active!.sessionId != session.id) {
        lastError =
            'Sudah ada timer aktif pada sesi lain. Selesaikan atau hentikan timer tersebut terlebih dahulu.';
        return false;
      }
      if (_active != null && _active!.sessionId == session.id) {
        // Idempoten terhadap ketukan ganda saat sudah berjalan/ada.
        if (_active!.isRunning) return true;
        return _resumeInternal();
      }
      _stateVersion++;
      _active = SessionTimerState(
        sessionId: session.id,
        taskId: session.taskId,
        isRunning: true,
        accumulatedSeconds: 0,
        startedAtUtc: clock().toUtc(),
      );
      await storage.write(userKey, _active);
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<bool> pause(String sessionId) async {
    if (_busy) return false;
    _busy = true;
    try {
      final active = _active;
      if (active == null ||
          active.sessionId != sessionId ||
          !active.isRunning) {
        return false;
      }
      final totalSeconds = active.elapsedAt(clock()).inSeconds;
      _active = SessionTimerState(
        sessionId: active.sessionId,
        taskId: active.taskId,
        isRunning: false,
        accumulatedSeconds: totalSeconds,
        startedAtUtc: null,
      );
      if (_userKey != null) {
        await storage.write(_userKey!, _active);
      }
      return true;
    } finally {
      _busy = false;
    }
  }

  Future<bool> resume(String sessionId) async {
    if (_busy) return false;
    _busy = true;
    try {
      final active = _active;
      if (active == null ||
          active.sessionId != sessionId ||
          active.isRunning) {
        return false;
      }
      return _resumeInternal();
    } finally {
      _busy = false;
    }
  }

  Future<bool> _resumeInternal() async {
    final active = _active!;
    _active = SessionTimerState(
      sessionId: active.sessionId,
      taskId: active.taskId,
      isRunning: true,
      accumulatedSeconds: active.accumulatedSeconds,
      startedAtUtc: clock().toUtc(),
    );
    if (_userKey != null) {
      await storage.write(_userKey!, _active);
    }
    return true;
  }

  /// Menjeda timer (jika masih berjalan) dan mengembalikan durasi fokus saat menekan Selesai.
  Future<Duration> finishAndPause(String sessionId) async {
    final active = _active;
    if (active == null || active.sessionId != sessionId) return Duration.zero;
    if (active.isRunning) {
      await pause(sessionId);
    }
    return elapsedFor(sessionId);
  }

  Future<void> clearActive() async {
    _stateVersion++;
    _active = null;
    lastError = null;
    if (_userKey != null) {
      await storage.write(_userKey!, null);
    }
  }

  void resetMemoryOnSignOut() {
    _stateVersion++;
    _active = null;
    _userKey = null;
    lastError = null;
  }
}
