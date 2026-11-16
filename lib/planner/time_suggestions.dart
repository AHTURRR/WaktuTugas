import 'package:timezone/timezone.dart' as tz;
import 'capacity_simulation.dart';
import 'intervals.dart';
import 'models.dart';
import 'schedule.dart';

/// Satu kandidat saran penambahan slot waktu belajar beserta hasil simulasinya.
class TimeSuggestion {
  final TimeWindow candidateWindow;
  final DateTime startsAt;
  final DateTime endsAt;
  final int addedMinutes;
  final CapacitySimulationResult simulation;

  const TimeSuggestion({
    required this.candidateWindow,
    required this.startsAt,
    required this.endsAt,
    required this.addedMinutes,
    required this.simulation,
  });

  /// Total menit pengurangan alokasi yang merugikan tugas lain.
  int get harmMinutes => simulation.otherTasksImpact
      .where((impact) => impact.minuteDelta < 0)
      .fold(0, (sum, impact) => sum + (-impact.minuteDelta));

  /// Jumlah tugas lain yang alokasinya berubah.
  int get impactedTaskCount => simulation.otherTasksImpact.length;
}

enum EmptySuggestionReason {
  pastOrNearDeadline,
  blockedOrAlreadyAllocated,
  noShortfallReduction,
}

class TimeSuggestionSearchResult {
  final List<TimeSuggestion> suggestions;
  final EmptySuggestionReason? emptyReason;
  final String? emptyExplanation;

  const TimeSuggestionSearchResult({
    required this.suggestions,
    this.emptyReason,
    this.emptyExplanation,
  });

  bool get isEmpty => suggestions.isEmpty;
}

/// Pencari saran slot waktu tambahan untuk tugas dengan kekurangan kapasitas.
class TimeSuggester {
  const TimeSuggester();

  TimeSuggestionSearchResult suggest({
    required PlannerSnapshot snapshot,
    required DateTime now,
    required Task targetTask,
    required int preferredStartMinute,
    required int preferredEndMinute,
    SchedulePreview? baselinePreview,
    int maxSuggestions = 3,
  }) {
    if (preferredStartMinute < 0 ||
        preferredEndMinute > 1440 ||
        preferredStartMinute >= preferredEndMinute) {
      return const TimeSuggestionSearchResult(
        suggestions: [],
        emptyReason: EmptySuggestionReason.blockedOrAlreadyAllocated,
        emptyExplanation: 'Rentang jam belajar yang dipilih tidak valid.',
      );
    }

    final basePreview = baselinePreview ?? buildPreview(snapshot, now);
    final beforeItem = basePreview.unallocated
        .where(
          (u) =>
              u.taskId == targetTask.id &&
              u.reason == UnallocatedReason.insufficientCapacity,
        )
        .firstOrNull;
    final beforeShortfall = beforeItem?.minutes ?? 0;

    final startFloor = ceilMinute(now);
    final horizon = horizonEnd(now);
    final effectiveDeadline = targetTask.deadlineAt.isBefore(horizon)
        ? targetTask.deadlineAt
        : horizon;

    if (beforeShortfall <= 0 || !effectiveDeadline.isAfter(startFloor)) {
      return const TimeSuggestionSearchResult(
        suggestions: [],
        emptyReason: EmptySuggestionReason.pastOrNearDeadline,
        emptyExplanation:
            'Tidak ada ruang waktu sebelum tenggat tugas dalam jendela perencanaan 14 hari.',
      );
    }

    final today = tz.TZDateTime.from(now, jakarta);
    final busyIntervals = <Interval>[
      ..._expandAllWindows(snapshot.activities, today, startFloor, horizon),
      ..._expandAllWindows(snapshot.timeWindows, today, startFloor, horizon),
      for (final session in snapshot.sessions.where(
        (s) => s.status == SessionStatus.completed,
      ))
        Interval(session.startsAt, session.endsAt),
    ];

    const simulator = CapacitySimulator();
    var hadCandidateWindowBeforeDeadline = false;
    var hadFreeInterval = false;
    final rawCandidates = <TimeSuggestion>[];

    for (var offset = 0; offset < 14; offset++) {
      final day = tz.TZDateTime(
        jakarta,
        today.year,
        today.month,
        today.day + offset,
      );
      final dateStr =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      final rawStart = day.add(Duration(minutes: preferredStartMinute)).toUtc();
      final rawEnd = day.add(Duration(minutes: preferredEndMinute)).toUtc();
      final clippedStart = rawStart.isBefore(startFloor) ? startFloor : rawStart;
      final clippedEnd = rawEnd.isAfter(effectiveDeadline)
          ? effectiveDeadline
          : rawEnd;

      if (!clippedEnd.isAfter(clippedStart)) continue;
      hadCandidateWindowBeforeDeadline = true;

      final freeSlots = subtractIntervals(
        [Interval(clippedStart, clippedEnd)],
        busyIntervals,
      );
      if (freeSlots.isEmpty) continue;
      hadFreeInterval = true;

      for (final free in freeSlots) {
        final freeStartMin = tz.TZDateTime.from(free.start, jakarta)
            .difference(day)
            .inMinutes;
        final freeEndMin = tz.TZDateTime.from(free.end, jakarta)
            .difference(day)
            .inMinutes;
        final freeDuration = freeEndMin - freeStartMin;
        if (freeDuration <= 0) continue;

        final lengthsToTry = <int>[
          freeDuration,
          if (freeDuration > beforeShortfall) beforeShortfall,
        ];

        TimeSuggestion? bestForInterval;
        for (final dur in lengthsToTry) {
          final candEndMin = freeStartMin + dur;
          final candWindow = TimeWindow(
            id: 'suggest-$dateStr-$freeStartMin-$candEndMin',
            date: dateStr,
            startMinute: freeStartMin,
            endMinute: candEndMin,
          );
          final sim = simulator.simulate(
            snapshot: snapshot,
            now: now,
            targetTask: targetTask,
            candidateWindow: candWindow,
            baselinePreview: basePreview,
          );
          if (sim.shortfallReduction <= 0) continue;

          final suggestion = TimeSuggestion(
            candidateWindow: candWindow,
            startsAt: free.start,
            endsAt: free.start.add(Duration(minutes: dur)),
            addedMinutes: dur,
            simulation: sim,
          );

          if (bestForInterval == null ||
              _compareSuggestions(suggestion, bestForInterval) < 0) {
            bestForInterval = suggestion;
          }
        }

        if (bestForInterval != null) {
          rawCandidates.add(bestForInterval);
        }
      }
    }

    if (rawCandidates.isEmpty) {
      if (!hadCandidateWindowBeforeDeadline) {
        return const TimeSuggestionSearchResult(
          suggestions: [],
          emptyReason: EmptySuggestionReason.pastOrNearDeadline,
          emptyExplanation:
              'Rentang jam yang dipilih berada setelah tenggat tugas atau sudah terlewat.',
        );
      }
      if (!hadFreeInterval) {
        return const TimeSuggestionSearchResult(
          suggestions: [],
          emptyReason: EmptySuggestionReason.blockedOrAlreadyAllocated,
          emptyExplanation:
              'Seluruh rentang jam yang dipilih sebelum tenggat sudah terisi waktu belajar atau terblokir kegiatan tetap dan penutupan.',
        );
      }
      return const TimeSuggestionSearchResult(
        suggestions: [],
        emptyReason: EmptySuggestionReason.noShortfallReduction,
        emptyExplanation:
            'Slot luang yang ditemukan belum mengurangi kekurangan tugas ini karena prioritas tugas lain atau kapasitas yang belum mencukupi.',
      );
    }

    rawCandidates.sort(_compareSuggestions);
    return TimeSuggestionSearchResult(
      suggestions: rawCandidates.take(maxSuggestions).toList(),
    );
  }

  static int _compareSuggestions(TimeSuggestion a, TimeSuggestion b) {
    // 1. Pengurangan kekurangan tugas yang dipilih (lebih besar lebih baik)
    final reductionCmp = b.simulation.shortfallReduction.compareTo(
      a.simulation.shortfallReduction,
    );
    if (reductionCmp != 0) return reductionCmp;

    // 2. Dampak merugikan terhadap tugas lain (lebih kecil lebih baik)
    final harmCmp = a.harmMinutes.compareTo(b.harmMinutes);
    if (harmCmp != 0) return harmCmp;

    final countCmp = a.impactedTaskCount.compareTo(b.impactedTaskCount);
    if (countCmp != 0) return countCmp;

    // 3. Durasi tambahan yang diperlukan (lebih singkat lebih baik)
    final durationCmp = a.addedMinutes.compareTo(b.addedMinutes);
    if (durationCmp != 0) return durationCmp;

    // 4. Penentu urutan deterministik: waktu mulai lebih awal
    return a.startsAt.compareTo(b.startsAt);
  }

  static List<Interval> _expandAllWindows(
    List<TimeWindow> windows,
    tz.TZDateTime today,
    DateTime startFloor,
    DateTime horizon,
  ) {
    final result = <Interval>[];
    for (var offset = 0; offset < 14; offset++) {
      final day = tz.TZDateTime(
        jakarta,
        today.year,
        today.month,
        today.day + offset,
      );
      final dateStr =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      for (final window in windows) {
        if (window.date != dateStr && window.weekday != day.weekday) continue;
        final a = day.add(Duration(minutes: window.startMinute)).toUtc();
        final b = day.add(Duration(minutes: window.endMinute)).toUtc();
        final clippedStart = a.isBefore(startFloor) ? startFloor : a;
        final clippedEnd = b.isAfter(horizon) ? horizon : b;
        if (clippedEnd.isAfter(clippedStart)) {
          result.add(Interval(clippedStart, clippedEnd));
        }
      }
    }
    return result;
  }
}
