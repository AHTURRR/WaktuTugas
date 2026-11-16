import 'capacity_simulation.dart';
import 'models.dart';
import 'schedule.dart';

/// Hasil perbandingan jadwal biasa dengan skenario prioritas sementara satu tugas.
class PrioritySimulationResult {
  final Task targetTask;
  final DateTime referenceNow;
  final int snapshotRevision;
  final SchedulePreview baselinePreview;
  final SchedulePreview prioritizedPreview;
  final int beforeAllocatedMinutes;
  final int afterAllocatedMinutes;
  final int beforeUnallocatedMinutes;
  final int afterUnallocatedMinutes;
  final List<TaskImpact> otherTasksImpact;

  const PrioritySimulationResult({
    required this.targetTask,
    required this.referenceNow,
    required this.snapshotRevision,
    required this.baselinePreview,
    required this.prioritizedPreview,
    required this.beforeAllocatedMinutes,
    required this.afterAllocatedMinutes,
    required this.beforeUnallocatedMinutes,
    required this.afterUnallocatedMinutes,
    required this.otherTasksImpact,
  });

  int get gainedMinutes => afterAllocatedMinutes - beforeAllocatedMinutes;
  bool get hasImprovement => gainedMinutes > 0;
  bool get isFullyResolved =>
      beforeUnallocatedMinutes > 0 && afterUnallocatedMinutes == 0;
  List<TaskImpact> get lostTasks =>
      otherTasksImpact.where((item) => item.minuteDelta < 0).toList();
  int get totalOtherLostMinutes =>
      lostTasks.fold<int>(0, (sum, item) => sum + (-item.minuteDelta));
}

/// Engine simulasi prioritas sementara untuk satu tugas tanpa mengubah data tersimpan.
class PrioritySimulator {
  const PrioritySimulator();

  PrioritySimulationResult simulate({
    required PlannerSnapshot snapshot,
    required DateTime now,
    required Task targetTask,
    SchedulePreview? baselinePreview,
  }) {
    final basePreview = baselinePreview ?? buildPreview(snapshot, now);
    final prioritizedPreview = buildPreview(
      snapshot,
      now,
      prioritizedTaskId: targetTask.id,
    );

    final beforeAllocated = _allocatedMinutesFor(basePreview, targetTask.id);
    final afterAllocated = _allocatedMinutesFor(
      prioritizedPreview,
      targetTask.id,
    );

    final beforeUnallocated = _unallocatedMinutesFor(
      basePreview,
      targetTask.id,
    );
    final afterUnallocated = _unallocatedMinutesFor(
      prioritizedPreview,
      targetTask.id,
    );

    final otherImpacts = <TaskImpact>[];
    for (final task in snapshot.tasks) {
      if (task.id == targetTask.id) continue;

      final beforeSessions = basePreview.sessions
          .where((s) => s.taskId == task.id)
          .toList();
      final afterSessions = prioritizedPreview.sessions
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

      var timingsShifted = beforeSessions.length != afterSessions.length;
      if (!timingsShifted) {
        for (var i = 0; i < beforeSessions.length; i++) {
          if (beforeSessions[i].startsAt != afterSessions[i].startsAt ||
              beforeSessions[i].endsAt != afterSessions[i].endsAt) {
            timingsShifted = true;
            break;
          }
        }
      }

      if (beforeMinutes != afterMinutes || timingsShifted) {
        otherImpacts.add(
          TaskImpact(
            task: task,
            beforeMinutes: beforeMinutes,
            afterMinutes: afterMinutes,
            timingsShifted: timingsShifted,
          ),
        );
      }
    }

    return PrioritySimulationResult(
      targetTask: targetTask,
      referenceNow: now,
      snapshotRevision: snapshot.revision,
      baselinePreview: basePreview,
      prioritizedPreview: prioritizedPreview,
      beforeAllocatedMinutes: beforeAllocated,
      afterAllocatedMinutes: afterAllocated,
      beforeUnallocatedMinutes: beforeUnallocated,
      afterUnallocatedMinutes: afterUnallocated,
      otherTasksImpact: otherImpacts,
    );
  }

  static int _allocatedMinutesFor(SchedulePreview preview, String taskId) {
    return preview.sessions
        .where((s) => s.taskId == taskId)
        .fold<int>(
          0,
          (sum, s) => sum + s.endsAt.difference(s.startsAt).inMinutes,
        );
  }

  static int _unallocatedMinutesFor(SchedulePreview preview, String taskId) {
    return preview.unallocated
        .where((u) => u.taskId == taskId)
        .fold<int>(0, (sum, u) => sum + u.minutes);
  }
}
