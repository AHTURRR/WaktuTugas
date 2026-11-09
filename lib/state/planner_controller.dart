import 'package:flutter/foundation.dart';
import '../data/cache.dart';
import '../data/planner_api.dart';
import '../planner/fixtures.dart';
import '../planner/models.dart';
import '../planner/schedule.dart';

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
  final DateTime Function()? _clock;
  final PlannerApi? api;
  final LocalCache? cache;
  final String? userId;
  DateTime get now => (_clock?.call() ?? _demoTime).toUtc();
  bool get isApiBacked => api != null;

  PlannerController({
    PlannerSnapshot? initial,
    this._clock,
    this.api,
    this.cache,
    this.userId,
  }) : _snapshot = initial ?? demoSnapshot();

  Task? taskById(String id) =>
      snapshot.tasks.where((t) => t.id == id).firstOrNull;
  PlannerSession? sessionById(String id) =>
      snapshot.sessions.where((s) => s.id == id).firstOrNull;
  bool get hasStartedPlanned => snapshot.sessions.any(
    (s) => s.status == SessionStatus.planned && !s.startsAt.isAfter(now),
  );

  void resetDemo() {
    _snapshot = demoSnapshot();
    _preview = null;
    error = null;
    errorCode = null;
    _isOfflineSnapshot = false;
    _fetchedAt = null;
    needsReschedule = false;
    _demoTime = demoNow;
    notifyListeners();
  }

  void clear() {
    _snapshot = PlannerSnapshot(
      revision: 0,
      tasks: [],
      timeWindows: [],
      activities: [],
      sessions: [],
    );
    _preview = null;
    error = null;
    errorCode = null;
    _isOfflineSnapshot = false;
    _fetchedAt = null;
    needsReschedule = false;
    notifyListeners();
  }

  Future<bool> fetchSnapshot({
    String? userId,
    bool allowPending = false,
  }) async {
    final api = this.api;
    if (api == null) return false;
    if (_isPending && !allowPending) return false;

    _isPending = true;
    error = null;
    errorCode = null;
    notifyListeners();
    try {
      final fetched = await api.fetchSnapshot();
      _snapshot = fetched;
      _preview = null;
      _isOfflineSnapshot = false;
      _fetchedAt = DateTime.now().toUtc();
      needsReschedule = false;
      final cache = this.cache;
      final resolvedUserId = userId ?? this.userId;
      if (cache != null && resolvedUserId != null) {
        await cache.writeCachedSnapshot(resolvedUserId, fetched, _fetchedAt!);
      }
      return true;
    } on PlannerApiException catch (e) {
      final cache = this.cache;
      final resolvedUserId = userId ?? this.userId;
      if (cache != null &&
          resolvedUserId != null &&
          e.code != 'UNAUTHENTICATED') {
        final cached = await cache.readCachedSnapshot(resolvedUserId);
        if (cached != null) {
          _snapshot = cached.snapshot;
          _preview = null;
          _isOfflineSnapshot = true;
          _fetchedAt = cached.fetchedAt;
          needsReschedule = false;
          return true;
        }
      }
      _setApiError(e);
      return false;
    } finally {
      _isPending = false;
      notifyListeners();
    }
  }

  // shortcut: synthetic clock for the local demonstration, replace with server time at cloud integration.
  void advanceDemoClock() {
    if (_clock != null || isPending) return;
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

  Future<bool> _runApi(Future<int> Function(int revision) action) async {
    if (api == null || _isPending) return false;
    _isPending = true;
    error = null;
    errorCode = null;
    notifyListeners();
    try {
      await action(snapshot.revision);
      return await fetchSnapshot(allowPending: true);
    } on PlannerApiException catch (e) {
      _setApiError(e);
      return false;
    } finally {
      _isPending = false;
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
  }) {
    _snapshot = PlannerSnapshot(
      revision: snapshot.revision + 1,
      tasks: tasks ?? snapshot.tasks,
      timeWindows: windows ?? snapshot.timeWindows,
      activities: activities ?? snapshot.activities,
      sessions: sessions ?? snapshot.sessions,
    );
    needsReschedule = true;
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
    if (api != null) {
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
    if (api != null) {
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

  Future<bool> saveWindow(TimeWindow window, {int? expectedRevision}) {
    final api = this.api;
    if (api != null) {
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
    if (api != null) {
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
    if (api != null) {
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

  Future<bool> generatePreview() => _run(() {
    _preview = null;
    _preview = buildPreview(snapshot, now);
  });
  Future<bool> confirmSchedule() {
    final api = this.api;
    if (api != null) {
      final candidate = _preview;
      if (candidate == null) {
        error = 'Hitung pratinjau terlebih dahulu.';
        errorCode = 'VALIDATION_ERROR';
        notifyListeners();
        return Future.value(false);
      }
      return _runApi((_) => api.confirmSchedule(preview: candidate));
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
    if (api != null) {
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
