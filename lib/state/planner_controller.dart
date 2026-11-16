// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../data/cache.dart';
import '../data/local_reminder_service.dart';
import '../data/onboarding_storage.dart';
import '../data/planner_api.dart';
import '../data/session_timer_service.dart';
import '../planner/fixtures.dart';
import '../planner/models.dart';
import '../planner/schedule.dart';

PlannerSnapshot _emptySnapshot() => PlannerSnapshot(
  revision: 0,
  tasks: [],
  timeWindows: [],
  activities: [],
  sessions: [],
);

class PlannerController extends ChangeNotifier {
  PlannerSnapshot _snapshot;
  PlannerSnapshot get snapshot => _snapshot;
  SchedulePreview? _preview;
  SchedulePreview? get preview => _preview;
  bool _isPending = false;
  bool get isPending => _isPending;
  String? error;
  String? errorCode;
  bool needsReschedule = false;
  bool _isOfflineSnapshot = false;
  DateTime? _fetchedAt;
  bool get isOfflineSnapshot => _isOfflineSnapshot;
  DateTime? get fetchedAt => _fetchedAt;
  DateTime _demoTime = demoNow;
  bool _demoMode = false;
  int _authEpoch = 0;
  String? _userId;
  String? get userId => _userId;
  final DateTime Function()? _clock;
  final PlannerApi? api;
  final LocalCache? cache;
  final OnboardingStorage? onboardingStorage;
  final LocalSessionReminderService? reminderService;
  late final SessionTimerService _timerService;
  final VoidCallback? onUnauthenticated;
  bool _onboardingFinished = false;
  bool get isOnboardingFinished => _onboardingFinished;
  String get _onboardingKey => (!_demoMode && _userId != null) ? _userId! : 'demo';
  bool get shouldShowOnboardingGuide =>
      !_onboardingFinished && snapshot.sessions.isEmpty;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime get now =>
      ((_demoMode ? null : _clock)?.call() ?? _demoTime).toUtc();
  bool get isApiBacked => api != null && !_demoMode;

  PlannerController({
    PlannerSnapshot? initial,
    DateTime Function()? clock,
    this.api,
    this.cache,
    this.onboardingStorage,
    this.reminderService,
    SessionTimerService? timerService,
    String? userId,
    this.onUnauthenticated,
    Stream<List<ConnectivityResult>>? connectivityStream,
  }) : _clock = clock,
       _userId = userId,
       _snapshot =
           initial ?? (api != null ? _emptySnapshot() : demoSnapshot()) {
    _timerService =
        timerService ??
        SessionTimerService(
          storage: MemorySessionTimerStorage(),
          clock: () => now,
        );
    _connectivitySub = connectivityStream?.listen(_onConnectivityChanged);
    unawaited(loadOnboardingState());
    unawaited(_loadAndSyncReminders());
    unawaited(_loadAndReconcileTimer());
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!isApiBacked) return;
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (!offline && _isOfflineSnapshot && !_isPending && _userId != null) {
      fetchSnapshot(userId: _userId);
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  bool get localReminderEnabled => reminderService?.isEnabled ?? false;
  String? get localReminderError => reminderService?.lastError;

  Future<void> _loadAndSyncReminders() async {
    final service = reminderService;
    if (service == null) return;
    final epoch = _authEpoch;
    final key = _onboardingKey;
    await service.loadForUser(key);
    if (_authEpoch != epoch || _onboardingKey != key) return;
    await service.syncSessions(
      _snapshot,
      taskTitleLookup: (id) => taskById(id)?.title ?? 'Sesi belajar',
    );
    notifyListeners();
  }

  Future<void> _syncLocalReminders() async {
    final service = reminderService;
    if (service == null) return;
    await service.syncSessions(
      _snapshot,
      taskTitleLookup: (id) => taskById(id)?.title ?? 'Sesi belajar',
    );
  }

  Future<bool> setLocalReminderEnabled(bool enabled) async {
    final service = reminderService;
    if (service == null) return false;
    final ok = await service.setEnabled(
      enabled,
      userKey: _onboardingKey,
      snapshot: _snapshot,
      taskTitleLookup: (id) => taskById(id)?.title ?? 'Sesi belajar',
    );
    notifyListeners();
    return ok;
  }

  SessionTimerState? get activeSessionTimer => _timerService.activeTimer;
  Duration sessionTimerElapsed(String sessionId) =>
      _timerService.elapsedFor(sessionId);
  bool isTimerActiveForSession(String sessionId) =>
      _timerService.isActiveFor(sessionId);
  bool hasOtherActiveTimer(String sessionId) =>
      _timerService.hasOtherActiveSession(sessionId);
  String? get sessionTimerError => _timerService.lastError;

  Future<void> _loadAndReconcileTimer() async {
    final epoch = _authEpoch;
    final key = _onboardingKey;
    await _timerService.loadForUser(key, _snapshot);
    if (_authEpoch != epoch || _onboardingKey != key) return;
    notifyListeners();
  }

  Future<bool> startSessionTimer(String sessionId) async {
    final session = sessionById(sessionId);
    if (session == null || session.status != SessionStatus.planned) {
      return false;
    }
    final ok = await _timerService.start(session, userKey: _onboardingKey);
    notifyListeners();
    return ok;
  }

  Future<bool> pauseSessionTimer(String sessionId) async {
    final ok = await _timerService.pause(sessionId);
    notifyListeners();
    return ok;
  }

  Future<bool> resumeSessionTimer(String sessionId) async {
    final ok = await _timerService.resume(sessionId);
    notifyListeners();
    return ok;
  }

  Future<Duration> finishSessionTimer(String sessionId) async {
    final duration = await _timerService.finishAndPause(sessionId);
    notifyListeners();
    return duration;
  }

  Future<void> loadOnboardingState() async {
    final storage = onboardingStorage;
    if (storage == null) return;
    final epoch = _authEpoch;
    final key = _onboardingKey;
    final finished = await storage.isFinished(key);
    if (_authEpoch != epoch || _onboardingKey != key) return;
    if (_onboardingFinished != finished) {
      _onboardingFinished = finished;
      notifyListeners();
    }
  }

  Future<void> dismissOnboarding() async {
    if (!_onboardingFinished) {
      _onboardingFinished = true;
      notifyListeners();
    }
    await onboardingStorage?.markFinished(_onboardingKey);
  }

  Future<void> completeOnboarding() async {
    if (!_onboardingFinished) {
      _onboardingFinished = true;
      notifyListeners();
    }
    await onboardingStorage?.markFinished(_onboardingKey);
  }

  void bindUser(String? nextUserId) {
    if (_userId == nextUserId && !_demoMode) return;
    _authEpoch++;
    _userId = nextUserId;
    _demoMode = false;
    _isPending = false;
    _onboardingFinished = false;
    _snapshot = _emptySnapshot();
    _preview = null;
    error = null;
    errorCode = null;
    _isOfflineSnapshot = false;
    _fetchedAt = null;
    needsReschedule = false;
    notifyListeners();
    unawaited(loadOnboardingState());
    unawaited(
      reminderService?.onSignedOutOrSwitched().then((_) => _loadAndSyncReminders()) ??
          Future<void>.value(),
    );
    _timerService.resetMemoryOnSignOut();
    unawaited(_loadAndReconcileTimer());
  }

  Task? taskById(String id) =>
      snapshot.tasks.where((t) => t.id == id).firstOrNull;
  PlannerSession? sessionById(String id) =>
      snapshot.sessions.where((s) => s.id == id).firstOrNull;
  bool get hasStartedPlanned => snapshot.sessions.any(
    (s) => s.status == SessionStatus.planned && !s.startsAt.isAfter(now),
  );

  void resetDemo() {
    _authEpoch++;
    _demoMode = true;
    _userId = null;
    _isPending = false;
    _onboardingFinished = false;
    _snapshot = demoSnapshot();
    _preview = null;
    error = null;
    errorCode = null;
    _isOfflineSnapshot = false;
    _fetchedAt = null;
    needsReschedule = false;
    _demoTime = demoNow;
    notifyListeners();
    unawaited(loadOnboardingState());
    unawaited(
      reminderService?.onSignedOutOrSwitched().then((_) => _loadAndSyncReminders()) ??
          Future<void>.value(),
    );
    _timerService.resetMemoryOnSignOut();
    unawaited(_loadAndReconcileTimer());
  }

  void clear() {
    _authEpoch++;
    _userId = null;
    _demoMode = false;
    _isPending = false;
    _onboardingFinished = false;
    _snapshot = _emptySnapshot();
    _preview = null;
    error = null;
    errorCode = null;
    _isOfflineSnapshot = false;
    _fetchedAt = null;
    needsReschedule = false;
    notifyListeners();
    unawaited(reminderService?.onSignedOutOrSwitched());
    _timerService.resetMemoryOnSignOut();
  }

  Future<bool> fetchSnapshot({
    String? userId,
    bool allowPending = false,
    bool preserveRescheduleFlag = false,
  }) async {
    final api = this.api;
    if (api == null) return false;
    if (_isPending && !allowPending) return false;

    if (userId != null && userId != _userId) {
      _authEpoch++;
      _userId = userId;
      _demoMode = false;
      _onboardingFinished = false;
      _snapshot = _emptySnapshot();
      _preview = null;
      _isOfflineSnapshot = false;
      _fetchedAt = null;
      needsReschedule = false;
    } else {
      _demoMode = false;
    }
    final reqEpoch = _authEpoch;
    final resolvedUserId = userId ?? _userId;

    _isPending = true;
    error = null;
    errorCode = null;
    notifyListeners();
    try {
      final fetched = await api.fetchSnapshot();
      if (_authEpoch != reqEpoch || _userId != resolvedUserId) {
        return false;
      }
      _snapshot = fetched;
      _preview = null;
      _isOfflineSnapshot = false;
      _fetchedAt = DateTime.now().toUtc();
      if (!preserveRescheduleFlag) {
        needsReschedule = false;
      }
      if (fetched.sessions.isNotEmpty) {
        _onboardingFinished = true;
        await onboardingStorage?.markFinished(resolvedUserId ?? 'demo');
      } else if (onboardingStorage != null) {
        _onboardingFinished = await onboardingStorage!.isFinished(
          resolvedUserId ?? 'demo',
        );
      }
      if (_authEpoch != reqEpoch || _userId != resolvedUserId) {
        return false;
      }
      final cache = this.cache;
      if (cache != null && resolvedUserId != null) {
        await cache.writeCachedSnapshot(resolvedUserId, fetched, _fetchedAt!);
      }
      await _loadAndSyncReminders();
      await _loadAndReconcileTimer();
      return true;
    } on PlannerApiException catch (e) {
      if (_authEpoch != reqEpoch || _userId != resolvedUserId) {
        return false;
      }
      if (e.code == 'UNAUTHENTICATED') {
        _setApiError(e);
        onUnauthenticated?.call();
        return false;
      }
      final cache = this.cache;
      if (cache != null && resolvedUserId != null && !allowPending) {
        final cached = await cache.readCachedSnapshot(resolvedUserId);
        if (_authEpoch != reqEpoch || _userId != resolvedUserId) {
          return false;
        }
        if (cached != null) {
          _snapshot = cached.snapshot;
          _preview = null;
          _isOfflineSnapshot = true;
          _fetchedAt = cached.fetchedAt;
          needsReschedule = false;
          if (cached.snapshot.sessions.isNotEmpty) {
            _onboardingFinished = true;
          } else if (onboardingStorage != null) {
            _onboardingFinished = await onboardingStorage!.isFinished(
              resolvedUserId,
            );
          }
          return true;
        }
      }
      _setApiError(e);
      return false;
    } finally {
      if (_authEpoch == reqEpoch) {
        _isPending = false;
      }
      notifyListeners();
    }
  }

  void advanceDemoClock() {
    if ((_clock != null && !_demoMode) || isApiBacked || isPending) return;
    final starts = [
      ...snapshot.sessions
          .where((s) => s.status == SessionStatus.planned)
          .map((s) => s.startsAt),
      ...?_preview?.sessions.map((s) => s.startsAt),
    ]..sort();
    final next = starts.where((s) => s.isAfter(now)).firstOrNull;
    if (next != null) {
      _demoTime = next.add(const Duration(seconds: 1));
      notifyListeners();
    }
  }

  Future<bool> _run(void Function() action) async {
    if (_isPending) return false;
    if (_isOfflineSnapshot) {
      error = 'Mode luring hanya mendukung pembacaan jadwal tersimpan.';
      errorCode = 'OFFLINE';
      notifyListeners();
      return false;
    }
    _isPending = true;
    error = null;
    errorCode = null;
    notifyListeners();
    final before = snapshot;
    try {
      await Future<void>.delayed(Duration.zero);
      if (!identical(before, snapshot)) {
        throw StateError('Data berubah. Muat ulang formulir.');
      }
      action();
      return true;
    } on FormatException catch (e) {
      error = e.message;
      return false;
    } on StateError catch (e) {
      error = e.message;
      return false;
    } finally {
      _isPending = false;
      notifyListeners();
    }
  }

  Future<void> _reloadSnapshotAfterUncertainOrStale(
    int reqEpoch,
    String? reqUserId,
  ) async {
    final api = this.api;
    if (api == null) return;
    try {
      final fetched = await api.fetchSnapshot();
      if (_authEpoch != reqEpoch || _userId != reqUserId) return;
      _snapshot = fetched;
      _isOfflineSnapshot = false;
      _fetchedAt = DateTime.now().toUtc();
      final cache = this.cache;
      if (cache != null && reqUserId != null) {
        await cache.writeCachedSnapshot(reqUserId, fetched, _fetchedAt!);
      }
    } catch (_) {}
  }

  Future<bool> _runApi(
    Future<int> Function(int revision) action, {
    bool marksReschedule = true,
  }) async {
    final api = this.api;
    if (api == null || _demoMode || _isPending) return false;
    if (_isOfflineSnapshot) {
      error = 'Mode luring hanya mendukung pembacaan jadwal tersimpan.';
      errorCode = 'OFFLINE';
      notifyListeners();
      return false;
    }
    final reqEpoch = _authEpoch;
    final reqUserId = _userId;
    _isPending = true;
    error = null;
    errorCode = null;
    notifyListeners();
    try {
      await action(snapshot.revision);
      if (_authEpoch != reqEpoch || _userId != reqUserId) return false;
      final ok = await fetchSnapshot(
        userId: reqUserId,
        allowPending: true,
        preserveRescheduleFlag: marksReschedule,
      );
      if (ok && marksReschedule) {
        needsReschedule = true;
      }
      return ok;
    } on PlannerApiException catch (e) {
      if (_authEpoch != reqEpoch || _userId != reqUserId) return false;
      if (e.code == 'TIMEOUT' || e.code == 'STALE_REVISION') {
        await _reloadSnapshotAfterUncertainOrStale(reqEpoch, reqUserId);
      }
      if (e.code == 'UNAUTHENTICATED') {
        onUnauthenticated?.call();
      }
      _setApiError(e);
      return false;
    } finally {
      if (_authEpoch == reqEpoch) {
        _isPending = false;
      }
      notifyListeners();
    }
  }

  void _setApiError(PlannerApiException exception) {
    errorCode = exception.code;
    error = exception.message;
  }

  void _checkRevision(int? expected) {
    if (expected != null && expected != snapshot.revision) {
      throw StateError('Data berubah. Buka ulang formulir.');
    }
  }

  void _replace({
    List<Task>? tasks,
    List<TimeWindow>? windows,
    List<Activity>? activities,
    List<PlannerSession>? sessions,
    bool markReschedule = true,
  }) {
    _snapshot = PlannerSnapshot(
      revision: snapshot.revision + 1,
      tasks: tasks ?? snapshot.tasks,
      timeWindows: windows ?? snapshot.timeWindows,
      activities: activities ?? snapshot.activities,
      sessions: sessions ?? snapshot.sessions,
    );
    if (markReschedule) {
      needsReschedule = true;
    }
    unawaited(_syncLocalReminders());
    unawaited(_timerService.reconcileWithSnapshot(_snapshot));
  }

  Future<bool> saveTask({
    String? id,
    required String title,
    required String? course,
    required DateTime deadline,
    required int remaining,
    int? expectedRevision,
  }) {
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => api.saveTask(
          taskId: id,
          title: title,
          course: course,
          deadlineAt: deadline,
          remainingMinutes: remaining,
          expectedRevision: expectedRevision ?? revision,
        ),
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      final existing = id == null ? null : taskById(id);
      if (id != null && existing == null) {
        throw StateError('Tugas tidak ditemukan.');
      }
      require(
        existing != null || remaining > 0,
        'Tugas baru harus memiliki menit positif.',
      );
      final task = Task(
        id: id ?? 'task-${snapshot.revision + 1}',
        title: title,
        course: course,
        deadlineAt: deadline,
        remainingMinutes: remaining,
        createdAt: existing?.createdAt ?? now,
        subtasks: existing?.subtasks ?? const <Subtask>[],
      );
      _replace(
        tasks: [
          for (final t in snapshot.tasks)
            if (t.id == task.id) task else t,
          if (existing == null) task,
        ],
      );
    });
  }

  Future<bool> deleteTask(
    String id, {
    required bool confirmed,
    int? expectedRevision,
  }) async {
    if (!confirmed) return false;
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => api.deleteTask(
          taskId: id,
          expectedRevision: expectedRevision ?? revision,
        ),
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      if (taskById(id) == null) throw StateError('Tugas tidak ditemukan.');
      _replace(
        tasks: snapshot.tasks.where((t) => t.id != id).toList(),
        sessions: snapshot.sessions.where((s) => s.taskId != id).toList(),
      );
    });
  }

  Future<bool> saveSubtask({
    required String taskId,
    String? subtaskId,
    required String title,
    required bool isCompleted,
    int? expectedRevision,
  }) {
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => api.saveSubtask(
          subtaskId: subtaskId,
          taskId: taskId,
          title: title,
          isCompleted: isCompleted,
          expectedRevision: expectedRevision ?? revision,
        ),
        marksReschedule: false,
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      final task = taskById(taskId);
      if (task == null) throw StateError('Tugas tidak ditemukan.');
      final existing = subtaskId == null
          ? null
          : task.subtasks.where((s) => s.id == subtaskId).firstOrNull;
      if (subtaskId != null && existing == null) {
        throw StateError('Subtugas tidak ditemukan.');
      }
      final subtask = Subtask(
        id: subtaskId ?? 'subtask-${snapshot.revision + 1}-${task.subtasks.length + 1}',
        taskId: taskId,
        title: title,
        isCompleted: isCompleted,
      );
      final nextSubtasks = [
        for (final s in task.subtasks)
          if (s.id == subtask.id) subtask else s,
        if (existing == null) subtask,
      ];
      _replace(
        tasks: [
          for (final t in snapshot.tasks)
            if (t.id == task.id) t.withSubtasks(nextSubtasks) else t,
        ],
        markReschedule: false,
      );
    });
  }

  Future<bool> deleteSubtask({
    required String taskId,
    required String subtaskId,
    int? expectedRevision,
  }) {
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => api.deleteSubtask(
          subtaskId: subtaskId,
          expectedRevision: expectedRevision ?? revision,
        ),
        marksReschedule: false,
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      final task = taskById(taskId);
      if (task == null) throw StateError('Tugas tidak ditemukan.');
      if (!task.subtasks.any((s) => s.id == subtaskId)) {
        throw StateError('Subtugas tidak ditemukan.');
      }
      _replace(
        tasks: [
          for (final t in snapshot.tasks)
            if (t.id == task.id)
              t.withSubtasks(
                t.subtasks.where((s) => s.id != subtaskId).toList(),
              )
            else
              t,
        ],
        markReschedule: false,
      );
    });
  }

  Future<bool> saveWindow(TimeWindow window, {int? expectedRevision}) {
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => api.saveTimeWindow(
          id: snapshot.timeWindows.any((w) => w.id == window.id)
              ? window.id
              : null,
          weekday: window.weekday,
          date: window.date,
          startMinute: window.startMinute,
          endMinute: window.endMinute,
          expectedRevision: expectedRevision ?? revision,
        ),
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      final exists = snapshot.timeWindows.any((w) => w.id == window.id);
      _replace(
        windows: [
          for (final w in snapshot.timeWindows)
            if (w.id == window.id) window else w,
          if (!exists) window,
        ],
      );
    });
  }

  Future<bool> saveActivity(Activity activity, {int? expectedRevision}) {
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => api.saveActivity(
          id: snapshot.activities.any((a) => a.id == activity.id)
              ? activity.id
              : null,
          kind: activity.kind.name,
          label: activity.label,
          weekday: activity.weekday,
          date: activity.date,
          startMinute: activity.startMinute,
          endMinute: activity.endMinute,
          expectedRevision: expectedRevision ?? revision,
        ),
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      final exists = snapshot.activities.any((a) => a.id == activity.id);
      _replace(
        activities: [
          for (final a in snapshot.activities)
            if (a.id == activity.id) activity else a,
          if (!exists) activity,
        ],
      );
    });
  }

  Future<bool> deleteWindow(
    String id, {
    required bool activity,
    int? expectedRevision,
  }) {
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => activity
            ? api.deleteActivity(
                id: id,
                expectedRevision: expectedRevision ?? revision,
              )
            : api.deleteTimeWindow(
                id: id,
                expectedRevision: expectedRevision ?? revision,
              ),
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      require(
        (activity ? snapshot.activities : snapshot.timeWindows).any(
          (w) => w.id == id,
        ),
        'Rentang tidak ditemukan.',
      );
      if (activity) {
        _replace(
          activities: snapshot.activities.where((a) => a.id != id).toList(),
        );
      } else {
        _replace(
          windows: snapshot.timeWindows.where((w) => w.id != id).toList(),
        );
      }
    });
  }

  Future<bool> generatePreview() async {
    final ok = await _run(() {
      _preview = null;
      _preview = buildPreview(snapshot, now);
    });
    if (ok && snapshot.tasks.isNotEmpty && snapshot.timeWindows.isNotEmpty) {
      await completeOnboarding();
    }
    return ok;
  }
  Future<bool> confirmSchedule() {
    final api = this.api;
    if (api != null && !_demoMode) {
      final candidate = _preview;
      if (candidate == null) {
        error = 'Hitung pratinjau terlebih dahulu.';
        errorCode = 'VALIDATION_ERROR';
        notifyListeners();
        return Future.value(false);
      }
      if (candidate.inputRevision != snapshot.revision) {
        error = 'Data berubah. Hitung ulang pratinjau sebelum konfirmasi.';
        errorCode = 'STALE_REVISION';
        notifyListeners();
        return Future.value(false);
      }
      if (hasStartedPlanned) {
        error = 'Tutup progres sesi yang sudah mulai.';
        errorCode = 'VALIDATION_ERROR';
        notifyListeners();
        return Future.value(false);
      }
      if (candidate.windowEnd != horizonEnd(now) ||
          candidate.sessions.any((s) => !s.startsAt.isAfter(now))) {
        error = 'Pratinjau kedaluwarsa. Hitung ulang sebelum konfirmasi.';
        errorCode = 'VALIDATION_ERROR';
        notifyListeners();
        return Future.value(false);
      }
      return _runApi(
        (_) => api.confirmSchedule(preview: candidate),
        marksReschedule: false,
      );
    }
    return _run(() {
      final candidate = _preview;
      if (candidate == null) {
        throw StateError('Hitung pratinjau terlebih dahulu.');
      }
      _checkRevision(candidate.inputRevision);
      if (hasStartedPlanned) {
        throw StateError('Tutup progres sesi yang sudah mulai.');
      }
      if (candidate.windowEnd != horizonEnd(now) ||
          candidate.sessions.any((s) => !s.startsAt.isAfter(now))) {
        throw StateError(
          'Pratinjau kedaluwarsa. Hitung ulang sebelum konfirmasi.',
        );
      }
      final sessions = [
        for (final s in snapshot.sessions)
          if (s.status == SessionStatus.planned)
            PlannerSession(
              id: s.id,
              taskId: s.taskId,
              startsAt: s.startsAt,
              endsAt: s.endsAt,
              status: SessionStatus.cancelled,
            )
          else
            s,
        for (final (i, s) in candidate.sessions.indexed)
          PlannerSession(
            id: 'session-${snapshot.revision + 1}-$i',
            taskId: s.taskId,
            startsAt: s.startsAt,
            endsAt: s.endsAt,
            status: SessionStatus.planned,
          ),
      ];
      _replace(sessions: sessions);
      needsReschedule = false;
      _preview = null;
    });
  }

  Future<bool> recordProgress(
    String id,
    SessionStatus status,
    int? remainingAfter, {
    int? expectedRevision,
  }) {
    final api = this.api;
    if (api != null && !_demoMode) {
      return _runApi(
        (revision) => api.recordProgress(
          sessionId: id,
          status: status,
          remainingAfter: remainingAfter,
          expectedRevision: expectedRevision ?? revision,
        ),
      );
    }
    return _run(() {
      _checkRevision(expectedRevision);
      final session = sessionById(id);
      if (session == null) throw StateError('Sesi tidak ditemukan.');
      if (session.status != SessionStatus.planned) {
        throw StateError('Sesi sudah ditutup.');
      }
      if (session.startsAt.isAfter(now)) throw StateError('Sesi belum mulai.');
      require(
        status == SessionStatus.completed || status == SessionStatus.missed,
        'Pilih selesai atau terlewat.',
      );
      require(
        status == SessionStatus.completed
            ? remainingAfter != null && remainingAfter >= 0
            : remainingAfter == null,
        'Sisa aktual harus bilangan bulat nonnegatif.',
      );
      final closed = PlannerSession(
        id: session.id,
        taskId: session.taskId,
        startsAt: session.startsAt,
        endsAt: session.endsAt,
        status: status,
        remainingAfter: remainingAfter,
        closedAt: now,
      );
      _replace(
        sessions: [
          for (final s in snapshot.sessions)
            if (s.id == id) closed else s,
        ],
        tasks: [
          for (final t in snapshot.tasks)
            if (t.id == session.taskId && status == SessionStatus.completed)
              t.withRemaining(remainingAfter!)
            else
              t,
        ],
      );
    });
  }

  List<String> get invalidPlannedIds {
    final available = expandWindows(snapshot, now);
    final totals = <String, int>{};
    final invalid = <String>[];
    for (final s in snapshot.sessions.where(
      (s) => s.status == SessionStatus.planned && s.startsAt.isAfter(now),
    )) {
      final task = taskById(s.taskId)!;
      totals[s.taskId] =
          (totals[s.taskId] ?? 0) + s.endsAt.difference(s.startsAt).inMinutes;
      if (s.endsAt.isAfter(task.deadlineAt) ||
          totals[s.taskId]! > task.remainingMinutes ||
          !available.any(
            (w) => !s.startsAt.isBefore(w.start) && !s.endsAt.isAfter(w.end),
          )) {
        invalid.add(s.id);
      }
    }
    return invalid;
  }
}
