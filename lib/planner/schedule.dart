import 'dart:math' as math;
import 'package:timezone/timezone.dart' as tz;
import 'intervals.dart';
import 'models.dart';

tz.Location get jakarta => tz.getLocation('Asia/Jakarta');
DateTime ceilMinute(DateTime instant) {
  const unit = Duration.microsecondsPerMinute;
  return DateTime.fromMicrosecondsSinceEpoch(
    ((instant.microsecondsSinceEpoch + unit - 1) ~/ unit) * unit,
    isUtc: true,
  );
}

DateTime horizonEnd(DateTime now) {
  final day = tz.TZDateTime.from(now, jakarta);
  return tz.TZDateTime(jakarta, day.year, day.month, day.day + 14).toUtc();
}

List<Interval> expandWindows(PlannerSnapshot input, DateTime now) {
  final today = tz.TZDateTime.from(now, jakarta);
  final start = ceilMinute(now);
  final end = horizonEnd(now);
  List<Interval> expand(List<TimeWindow> windows) {
    final result = <Interval>[];
    for (var offset = 0; offset < 14; offset++) {
      final day = tz.TZDateTime(
        jakarta,
        today.year,
        today.month,
        today.day + offset,
      );
      final date =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      for (final window in windows) {
        if (window.date != date && window.weekday != day.weekday) continue;
        final a = day.add(Duration(minutes: window.startMinute)).toUtc();
        final b = day.add(Duration(minutes: window.endMinute)).toUtc();
        final clippedStart = a.isBefore(start) ? start : a;
        final clippedEnd = b.isAfter(end) ? end : b;
        if (clippedEnd.isAfter(clippedStart)) {
          result.add(Interval(clippedStart, clippedEnd));
        }
      }
    }
    return result;
  }

  final busy = expand(input.activities);
  for (final session in input.sessions.where(
    (s) => s.status == SessionStatus.completed,
  )) {
    busy.add(Interval(session.startsAt, session.endsAt));
  }
  return subtractIntervals(expand(input.timeWindows), busy);
}

SchedulePreview buildPreview(PlannerSnapshot snapshot, DateTime now) {
  if (snapshot.sessions.any(
    (s) => s.status == SessionStatus.planned && !s.startsAt.isAfter(now),
  )) {
    throw StateError(
      'Tutup progres sesi yang sudah mulai sebelum menyusun ulang.',
    );
  }
  final start = ceilMinute(now);
  final end = horizonEnd(now);
  var available = expandWindows(snapshot, now);
  final tasks = snapshot.tasks.where((t) => t.remainingMinutes > 0).toList()
    ..sort((a, b) {
      var result = a.deadlineAt.compareTo(b.deadlineAt);
      if (result == 0) result = a.createdAt.compareTo(b.createdAt);
      if (result == 0) result = a.id.compareTo(b.id);
      return result;
    });
  final sessions = <ProposedSession>[];
  final unallocated = <Unallocated>[];
  for (final task in tasks) {
    var remaining = task.remainingMinutes;
    final unused = <Interval>[];
    for (final slot in available) {
      final limit = slot.end.isBefore(task.deadlineAt)
          ? slot.end
          : task.deadlineAt;
      final minutes = math.min(
        remaining,
        limit.difference(slot.start).inMinutes,
      );
      if (minutes <= 0) {
        unused.add(slot);
        continue;
      }
      final finish = slot.start.add(Duration(minutes: minutes));
      sessions.add(
        ProposedSession(taskId: task.id, startsAt: slot.start, endsAt: finish),
      );
      remaining -= minutes;
      if (finish.isBefore(slot.end)) unused.add(Interval(finish, slot.end));
    }
    available = unused;
    if (remaining > 0) {
      unallocated.add(
        Unallocated(
          taskId: task.id,
          minutes: remaining,
          reason: !task.deadlineAt.isAfter(now)
              ? UnallocatedReason.pastDeadline
              : task.deadlineAt.isAfter(end)
              ? UnallocatedReason.outsideHorizon
              : UnallocatedReason.insufficientCapacity,
        ),
      );
    }
  }
  return SchedulePreview(
    inputRevision: snapshot.revision,
    generatedAt: now,
    windowStart: start,
    windowEnd: end,
    sessions: sessions,
    unallocated: unallocated,
  );
}
