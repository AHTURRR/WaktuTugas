import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'schedule.dart';

/// Ringkasan aktivitas sesi untuk satu minggu kalender Senin–Minggu (WIB).
class WeeklySummary {
  /// Senin 00:00 WIB (dalam UTC).
  final DateTime weekStart;

  /// Senin berikutnya 00:00 WIB (dalam UTC), batas eksklusif.
  final DateTime weekEnd;

  /// Menit terjadwal (rencana, selesai, terlewat) yang jatuh di dalam minggu.
  /// Sesi yang melewati batas minggu hanya dihitung bagian yang berada di dalamnya.
  final int scheduledMinutes;
  final int plannedCount;
  final int completedCount;
  final int missedCount;

  /// Sesi dibatalkan karena rencana diganti; dipisahkan dari terlewat dan
  /// tidak dihitung dalam menit terjadwal.
  final int cancelledCount;

  /// Menit fokus aktual terukur. `null` bila belum ada data terukur yang
  /// tersimpan pada sesi (timer saat ini tidak menyimpan durasi ke sesi).
  final int? measuredFocusMinutes;

  const WeeklySummary({
    required this.weekStart,
    required this.weekEnd,
    required this.scheduledMinutes,
    required this.plannedCount,
    required this.completedCount,
    required this.missedCount,
    required this.cancelledCount,
    this.measuredFocusMinutes,
  });

  bool get isEmpty =>
      plannedCount + completedCount + missedCount + cancelledCount == 0;

  /// Tanggal Minggu terakhir (inklusif) dalam WIB, untuk label rentang.
  DateTime get lastDayInclusive => weekEnd.subtract(const Duration(days: 1));
}

/// Batas minggu Senin 00:00 – Senin berikutnya 00:00 dalam WIB.
({DateTime start, DateTime end}) wibWeekBounds(DateTime now) {
  final local = tz.TZDateTime.from(now, jakarta);
  final monday = tz.TZDateTime(
    jakarta,
    local.year,
    local.month,
    local.day - (local.weekday - DateTime.monday),
  );
  final nextMonday = tz.TZDateTime(
    jakarta,
    monday.year,
    monday.month,
    monday.day + 7,
  );
  return (start: monday.toUtc(), end: nextMonday.toUtc());
}

WeeklySummary buildWeeklySummary(PlannerSnapshot snapshot, DateTime now) {
  final bounds = wibWeekBounds(now);
  final start = bounds.start;
  final end = bounds.end;

  var minutes = 0;
  var planned = 0, completed = 0, missed = 0, cancelled = 0;

  for (final s in snapshot.sessions) {
    final a = s.startsAt.toUtc();
    final b = s.endsAt.toUtc();
    final overlaps = a.isBefore(end) && b.isAfter(start);
    if (!overlaps) continue;

    switch (s.status) {
      case SessionStatus.planned:
        planned++;
      case SessionStatus.completed:
        completed++;
      case SessionStatus.missed:
        missed++;
      case SessionStatus.cancelled:
        cancelled++;
        continue;
    }
    final clipStart = a.isBefore(start) ? start : a;
    final clipEnd = b.isAfter(end) ? end : b;
    minutes += clipEnd.difference(clipStart).inMinutes;
  }

  return WeeklySummary(
    weekStart: start,
    weekEnd: end,
    scheduledMinutes: minutes,
    plannedCount: planned,
    completedCount: completed,
    missedCount: missed,
    cancelledCount: cancelled,
    measuredFocusMinutes: null,
  );
}
