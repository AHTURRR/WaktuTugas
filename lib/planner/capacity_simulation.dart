import 'models.dart';
import 'schedule.dart';

/// Dampak penambahan slot belajar terhadap tugas lain
class TaskImpact {
  final Task task;
  final int beforeMinutes;
  final int afterMinutes;
  final bool timingsShifted;

  const TaskImpact({
    required this.task,
    required this.beforeMinutes,
    required this.afterMinutes,
    required this.timingsShifted,
  });

  int get minuteDelta => afterMinutes - beforeMinutes;
  bool get hasChange => minuteDelta != 0 || timingsShifted;
}

/// Hasil simulasi penambahan kapasitas slot belajar
class CapacitySimulationResult {
  final TimeWindow candidateWindow;
  final int candidateDurationMinutes;
  final int effectiveCapacityAddedMinutes;
  final bool isCollidingWithBusy;
  final int collidingMinutes;
  final bool isPastDeadline;
  final int beforeUnallocatedMinutes;
  final int afterUnallocatedMinutes;
  final SchedulePreview simulatedPreview;
  final List<TaskImpact> otherTasksImpact;

  const CapacitySimulationResult({
    required this.candidateWindow,
    required this.candidateDurationMinutes,
    required this.effectiveCapacityAddedMinutes,
    required this.isCollidingWithBusy,
    required this.collidingMinutes,
    required this.isPastDeadline,
    required this.beforeUnallocatedMinutes,
    required this.afterUnallocatedMinutes,
    required this.simulatedPreview,
    required this.otherTasksImpact,
  });

  bool get isFullyResolved => afterUnallocatedMinutes == 0;
  bool get isPartiallyResolved =>
      afterUnallocatedMinutes > 0 && afterUnallocatedMinutes < beforeUnallocatedMinutes;
  bool get hasNoEffectOnShortfall =>
      afterUnallocatedMinutes >= beforeUnallocatedMinutes;
  int get shortfallReduction => beforeUnallocatedMinutes - afterUnallocatedMinutes;
}

/// Engine simulasi penambahan waktu untuk menyelesaikan kekurangan kapasitas (insufficientCapacity)
class CapacitySimulator {
  const CapacitySimulator();

  CapacitySimulationResult simulate({
    required PlannerSnapshot snapshot,
    required DateTime now,
    required Task targetTask,
    required TimeWindow candidateWindow,
    SchedulePreview? baselinePreview,
  }) {
    // 1. Pratinjau acuan (baseline)
    final basePreview = baselinePreview ?? buildPreview(snapshot, now);

    // 2. Buat snapshot salinan simulasi dengan kandidat window baru
    final simulatedSnapshot = PlannerSnapshot(
      revision: snapshot.revision,
      tasks: snapshot.tasks,
      timeWindows: [...snapshot.timeWindows, candidateWindow],
      activities: snapshot.activities,
      sessions: snapshot.sessions,
    );

    // 3. Evaluasi kapasitas efektif dan tabrakan dengan penutupan/kegiatan lain
    final candidateDuration = candidateWindow.endMinute - candidateWindow.startMinute;
    final baseWindows = expandWindows(snapshot, now);
    final simulatedWindows = expandWindows(simulatedSnapshot, now);

    final baseAvailableMinutes = baseWindows.fold<int>(
      0,
      (sum, i) => sum + i.end.difference(i.start).inMinutes,
    );
    final simulatedAvailableMinutes = simulatedWindows.fold<int>(
      0,
      (sum, i) => sum + i.end.difference(i.start).inMinutes,
    );

    final effectiveAddedMinutes = (simulatedAvailableMinutes - baseAvailableMinutes).clamp(
      0,
      candidateDuration,
    );
    final collidingMinutes = candidateDuration - effectiveAddedMinutes;
    final isCollidingWithBusy = collidingMinutes > 0;

    // 4. Hitung ulang jadwal pada salinan data
    final simulatedPreview = buildPreview(simulatedSnapshot, now);

    // 5. Cek apakah slot berada setelah tenggat tugas target
    bool isPastDeadline = false;
    if (candidateWindow.date != null) {
      final slotDay = DateTime.parse(candidateWindow.date!);
      final slotStartUtc = DateTime.utc(
        slotDay.year,
        slotDay.month,
        slotDay.day,
      ).add(Duration(minutes: candidateWindow.startMinute - 420)); // WIB ke UTC (-7 jam)
      if (slotStartUtc.isAfter(targetTask.deadlineAt) ||
          slotStartUtc.isAtSameMomentAs(targetTask.deadlineAt)) {
        isPastDeadline = true;
      }
    }

    // 6. Bandingkan kekurangan sebelum dan sesudah
    final beforeItem = basePreview.unallocated
        .where((u) => u.taskId == targetTask.id && u.reason == UnallocatedReason.insufficientCapacity)
        .firstOrNull;
    final beforeUnallocated = beforeItem?.minutes ?? 0;

    final afterItem = simulatedPreview.unallocated
        .where((u) => u.taskId == targetTask.id && u.reason == UnallocatedReason.insufficientCapacity)
        .firstOrNull;
    final afterUnallocated = afterItem?.minutes ?? 0;

    // 7. Evaluasi dampak pada tugas-tugas lain
    final otherImpacts = <TaskImpact>[];
    for (final task in snapshot.tasks) {
      if (task.id == targetTask.id) continue;

      final beforeSessions = basePreview.sessions
          .where((s) => s.taskId == task.id)
          .toList();
      final afterSessions = simulatedPreview.sessions
          .where((s) => s.taskId == task.id)
          .toList();

      final beforeMinutes = beforeSessions.fold<int>(
        0,
        (sum, s) => sum + s.endsAt.difference(s.startsAt).inMinutes,
      );
      final afterMinutes = afterSessions.fold<int>(
        0,
        (sum, s) => sum + s.endsAt.difference(s.startsAt).inMinutes,
      );

      bool timingsShifted = false;
      if (beforeSessions.length != afterSessions.length) {
        timingsShifted = true;
      } else {
        for (var i = 0; i < beforeSessions.length; i++) {
          if (beforeSessions[i].startsAt != afterSessions[i].startsAt ||
              beforeSessions[i].endsAt != afterSessions[i].endsAt) {
            timingsShifted = true;
            break;
          }
        }
      }

      final impact = TaskImpact(
        task: task,
        beforeMinutes: beforeMinutes,
        afterMinutes: afterMinutes,
        timingsShifted: timingsShifted,
      );

      if (impact.hasChange) {
        otherImpacts.add(impact);
      }
    }

    return CapacitySimulationResult(
      candidateWindow: candidateWindow,
      candidateDurationMinutes: candidateDuration,
      effectiveCapacityAddedMinutes: effectiveAddedMinutes,
      isCollidingWithBusy: isCollidingWithBusy,
      collidingMinutes: collidingMinutes,
      isPastDeadline: isPastDeadline,
      beforeUnallocatedMinutes: beforeUnallocated,
      afterUnallocatedMinutes: afterUnallocated,
      simulatedPreview: simulatedPreview,
      otherTasksImpact: otherImpacts,
    );
  }
}
