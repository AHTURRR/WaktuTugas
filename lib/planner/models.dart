typedef Json = Map<String, dynamic>;

void require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

String textField(Json json, String key) {
  final value = json[key];
  require(value is String, '$key harus teks.');
  return value as String;
}

int intField(Json json, String key) {
  final value = json[key];
  require(value is int, '$key harus bilangan bulat.');
  return value as int;
}

DateTime instant(Json json, String key) {
  final value = textField(json, key);
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(value);
  require(match != null, '$key harus timestamp ISO dengan zona waktu.');
  validDate(match![1]!);
  require(
    int.parse(match[2]!) < 24 &&
        int.parse(match[3]!) < 60 &&
        int.parse(match[4]!) < 60 &&
        (match[6] == null ||
            (int.parse(match[6]!) < 24 && int.parse(match[7]!) < 60)),
    '$key memuat jam tidak valid.',
  );
  require(
    RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value),
    '$key wajib memiliki zona waktu.',
  );
  final parsed = DateTime.tryParse(value);
  require(parsed != null, '$key tidak valid.');
  return parsed!.toUtc();
}

String validDate(String value) {
  final parsed = DateTime.tryParse(value);
  require(
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        parsed != null &&
        parsed.toIso8601String().substring(0, 10) == value,
    'Tanggal tidak valid.',
  );
  return value;
}

T parseEnum<T extends Enum>(
  Iterable<T> values,
  String name,
  String Function(T) key,
) {
  for (final value in values) {
    if (key(value) == name) return value;
  }
  throw FormatException('Status tidak dikenal: $name');
}

List<T> jsonList<T>(Json json, String key, T Function(Json) parse) {
  final value = json[key];
  require(value is List, '$key harus daftar.');
  return (value as List).map((item) {
    require(item is Map<String, dynamic>, '$key memuat data tidak valid.');
    return parse(item as Json);
  }).toList();
}

class Task {
  final String id, title;
  final String? course;
  final DateTime deadlineAt, createdAt;
  final int remainingMinutes;
  Task({
    required this.id,
    required String title,
    this.course,
    required DateTime deadlineAt,
    required this.remainingMinutes,
    required DateTime createdAt,
  }) : title = title.trim(),
       deadlineAt = deadlineAt.toUtc(),
       createdAt = createdAt.toUtc() {
    require(
      id.isNotEmpty && this.title.isNotEmpty && this.title.length <= 120,
      'Nama tugas wajib diisi, maksimal 120 karakter.',
    );
    require(
      course == null || course!.length <= 100,
      'Mata kuliah maksimal 100 karakter.',
    );
    require(remainingMinutes >= 0, 'Sisa menit tidak boleh negatif.');
  }
  factory Task.fromJson(Json j) {
    require(
      j['course'] == null || j['course'] is String,
      'Mata kuliah harus teks.',
    );
    return Task(
      id: textField(j, 'id'),
      title: textField(j, 'title'),
      course: j['course'] as String?,
      deadlineAt: instant(j, 'deadline_at'),
      remainingMinutes: intField(j, 'remaining_minutes'),
      createdAt: instant(j, 'created_at'),
    );
  }
  Json toJson() => {
    'id': id,
    'title': title,
    'course': course,
    'deadline_at': deadlineAt.toIso8601String(),
    'remaining_minutes': remainingMinutes,
    'created_at': createdAt.toIso8601String(),
  };
  Task withRemaining(int minutes) => Task(
    id: id,
    title: title,
    course: course,
    deadlineAt: deadlineAt,
    remainingMinutes: minutes,
    createdAt: createdAt,
  );
}

class TimeWindow {
  final String id;
  final int? weekday;
  final String? date;
  final int startMinute, endMinute;
  TimeWindow({
    required this.id,
    this.weekday,
    this.date,
    required this.startMinute,
    required this.endMinute,
  }) {
    require(id.isNotEmpty, 'ID tidak boleh kosong.');
    require(
      (weekday == null) != (date == null),
      'Pilih tepat satu hari mingguan atau tanggal.',
    );
    require(
      weekday == null || (weekday! >= 1 && weekday! <= 7),
      'Hari harus 1–7.',
    );
    if (date != null) validDate(date!);
    require(
      startMinute >= 0 &&
          startMinute < 1440 &&
          endMinute <= 1440 &&
          endMinute > startMinute,
      'Jam selesai harus setelah mulai, dalam satu hari.',
    );
  }
  factory TimeWindow.fromJson(Json j) {
    require(
      j['weekday'] == null || j['weekday'] is int,
      'Hari harus bilangan bulat.',
    );
    require(j['date'] == null || j['date'] is String, 'Tanggal harus teks.');
    return TimeWindow(
      id: textField(j, 'id'),
      weekday: j['weekday'] as int?,
      date: j['date'] as String?,
      startMinute: intField(j, 'start_minute'),
      endMinute: intField(j, 'end_minute'),
    );
  }
  Json toJson() => {
    'id': id,
    'weekday': weekday,
    'date': date,
    'start_minute': startMinute,
    'end_minute': endMinute,
  };
}

enum ActivityKind { routine, event, blocked }

class Activity extends TimeWindow {
  final ActivityKind kind;
  final String label;
  Activity({
    required super.id,
    super.weekday,
    super.date,
    required super.startMinute,
    required super.endMinute,
    required this.kind,
    required this.label,
  }) {
    require(label.length <= 120, 'Label maksimal 120 karakter.');
    require(
      kind == ActivityKind.routine ? weekday != null : date != null,
      'Kegiatan rutin memakai hari; kegiatan sekali/penutupan memakai tanggal.',
    );
  }
  factory Activity.fromJson(Json j) {
    final window = TimeWindow.fromJson(j);
    return Activity(
      id: window.id,
      weekday: window.weekday,
      date: window.date,
      startMinute: window.startMinute,
      endMinute: window.endMinute,
      kind: parseEnum(ActivityKind.values, textField(j, 'kind'), (v) => v.name),
      label: textField(j, 'label'),
    );
  }
  @override
  Json toJson() => {...super.toJson(), 'kind': kind.name, 'label': label};
}

class Interval {
  final DateTime start, end;
  Interval(DateTime start, DateTime end)
    : start = start.toUtc(),
      end = end.toUtc() {
    require(end.isAfter(start), 'Rentang harus berdurasi positif.');
  }
  int get minutes => end.difference(start).inMinutes;
  factory Interval.fromJson(Json j) =>
      Interval(instant(j, 'start'), instant(j, 'end'));
  Json toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };
}

enum SessionStatus { planned, completed, missed, cancelled }

class ProposedSession {
  final String taskId;
  final DateTime startsAt, endsAt;
  ProposedSession({
    required this.taskId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) : startsAt = startsAt.toUtc(),
       endsAt = endsAt.toUtc() {
    require(
      taskId.isNotEmpty &&
          endsAt.isAfter(startsAt) &&
          endsAt.difference(startsAt).inMicroseconds %
                  Duration.microsecondsPerMinute ==
              0,
      'Sesi harus berdurasi menit positif.',
    );
  }
  factory ProposedSession.fromJson(Json j) => ProposedSession(
    taskId: textField(j, 'task_id'),
    startsAt: instant(j, 'starts_at'),
    endsAt: instant(j, 'ends_at'),
  );
  Json toJson() => {
    'task_id': taskId,
    'starts_at': startsAt.toIso8601String(),
    'ends_at': endsAt.toIso8601String(),
  };
}

class PlannerSession extends ProposedSession {
  final String id;
  final SessionStatus status;
  final int? remainingAfter;
  final DateTime? closedAt;
  PlannerSession({
    required this.id,
    required super.taskId,
    required super.startsAt,
    required super.endsAt,
    required this.status,
    this.remainingAfter,
    DateTime? closedAt,
  }) : closedAt = closedAt?.toUtc() {
    require(id.isNotEmpty, 'ID sesi wajib diisi.');
    require(
      status == SessionStatus.completed
          ? remainingAfter != null && remainingAfter! >= 0
          : remainingAfter == null,
      'Sisa aktual hanya wajib untuk sesi selesai.',
    );
    require(
      status == SessionStatus.completed || status == SessionStatus.missed
          ? closedAt != null
          : closedAt == null,
      'Waktu penutupan tidak sesuai status.',
    );
  }
  factory PlannerSession.fromJson(Json j) {
    require(
      j['remaining_after'] == null || j['remaining_after'] is int,
      'Sisa aktual harus bilangan bulat.',
    );
    return PlannerSession(
      id: textField(j, 'id'),
      taskId: textField(j, 'task_id'),
      startsAt: instant(j, 'starts_at'),
      endsAt: instant(j, 'ends_at'),
      status: parseEnum(
        SessionStatus.values,
        textField(j, 'status'),
        (v) => v.name,
      ),
      remainingAfter: j['remaining_after'] as int?,
      closedAt: j['closed_at'] == null ? null : instant(j, 'closed_at'),
    );
  }
  @override
  Json toJson() => {
    ...super.toJson(),
    'id': id,
    'status': status.name,
    'remaining_after': remainingAfter,
    'closed_at': closedAt?.toIso8601String(),
  };
}

enum UnallocatedReason {
  pastDeadline('past_deadline', 'Tenggat sudah lewat'),
  insufficientCapacity(
    'insufficient_capacity',
    'Waktu sebelum tenggat tidak cukup',
  ),
  outsideHorizon('outside_horizon', 'Belum direncanakan di luar jendela ini');

  final String json, label;
  const UnallocatedReason(this.json, this.label);
}

class Unallocated {
  final String taskId;
  final int minutes;
  final UnallocatedReason reason;
  Unallocated({
    required this.taskId,
    required this.minutes,
    required this.reason,
  }) {
    require(taskId.isNotEmpty && minutes > 0, 'Sisa alokasi harus positif.');
  }
  factory Unallocated.fromJson(Json j) => Unallocated(
    taskId: textField(j, 'task_id'),
    minutes: intField(j, 'minutes'),
    reason: parseEnum(
      UnallocatedReason.values,
      textField(j, 'reason'),
      (v) => v.json,
    ),
  );
  Json toJson() => {
    'task_id': taskId,
    'minutes': minutes,
    'reason': reason.json,
  };
}

class PlannerSnapshot {
  final int revision;
  final List<Task> tasks;
  final List<TimeWindow> timeWindows;
  final List<Activity> activities;
  final List<PlannerSession> sessions;
  PlannerSnapshot({
    required this.revision,
    required List<Task> tasks,
    required List<TimeWindow> timeWindows,
    required List<Activity> activities,
    required List<PlannerSession> sessions,
  }) : tasks = List.unmodifiable(tasks),
       timeWindows = List.unmodifiable(timeWindows),
       activities = List.unmodifiable(activities),
       sessions = List.unmodifiable(sessions) {
    require(revision >= 0, 'Revisi tidak boleh negatif.');
    for (final ids in [
      tasks.map((v) => v.id),
      timeWindows.map((v) => v.id),
      activities.map((v) => v.id),
      sessions.map((v) => v.id),
    ]) {
      require(ids.toSet().length == ids.length, 'ID duplikat dalam snapshot.');
    }
    require(
      sessions.every((s) => tasks.any((t) => t.id == s.taskId)),
      'Tugas sesi tidak ditemukan.',
    );
  }
  factory PlannerSnapshot.fromJson(Json j) => PlannerSnapshot(
    revision: intField(j, 'revision'),
    tasks: jsonList(j, 'tasks', Task.fromJson),
    timeWindows: jsonList(j, 'time_windows', TimeWindow.fromJson),
    activities: jsonList(j, 'activities', Activity.fromJson),
    sessions: jsonList(j, 'sessions', PlannerSession.fromJson),
  );
  Json toJson() => {
    'revision': revision,
    'tasks': tasks.map((v) => v.toJson()).toList(),
    'time_windows': timeWindows.map((v) => v.toJson()).toList(),
    'activities': activities.map((v) => v.toJson()).toList(),
    'sessions': sessions.map((v) => v.toJson()).toList(),
  };
}

class SchedulePreview {
  final int inputRevision;
  final DateTime generatedAt, windowStart, windowEnd;
  final List<ProposedSession> sessions;
  final List<Unallocated> unallocated;
  SchedulePreview({
    required this.inputRevision,
    required DateTime generatedAt,
    required DateTime windowStart,
    required DateTime windowEnd,
    required List<ProposedSession> sessions,
    required List<Unallocated> unallocated,
  }) : generatedAt = generatedAt.toUtc(),
       windowStart = windowStart.toUtc(),
       windowEnd = windowEnd.toUtc(),
       sessions = List.unmodifiable(sessions),
       unallocated = List.unmodifiable(unallocated) {
    require(
      inputRevision >= 0 && windowEnd.isAfter(windowStart),
      'Jendela/revisi tidak valid.',
    );
  }
  factory SchedulePreview.fromJson(Json j) => SchedulePreview(
    inputRevision: intField(j, 'input_revision'),
    generatedAt: instant(j, 'generated_at'),
    windowStart: instant(j, 'window_start'),
    windowEnd: instant(j, 'window_end'),
    sessions: jsonList(j, 'sessions', ProposedSession.fromJson),
    unallocated: jsonList(j, 'unallocated', Unallocated.fromJson),
  );
  Json toJson() => {
    'input_revision': inputRevision,
    'generated_at': generatedAt.toIso8601String(),
    'window_start': windowStart.toIso8601String(),
    'window_end': windowEnd.toIso8601String(),
    'sessions': sessions.map((v) => v.toJson()).toList(),
    'unallocated': unallocated.map((v) => v.toJson()).toList(),
  };
}
