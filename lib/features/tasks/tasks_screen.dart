import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../app/theme.dart';
import '../../planner/models.dart';
import '../../planner/schedule.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

enum _TaskGroup {
  overdue('Terlambat', 'imgAlertCircle'),
  today('Hari ini', 'imgClock'),
  upcoming('Mendatang', 'imgCalendar'),
  completed('Tugas selesai', 'imgCheckCircle');

  const _TaskGroup(this.label, this.icon);
  final String label, icon;

  (Color, Color) palette(AppColors colors) => switch (this) {
    overdue => (colors.dangerBg, colors.dangerInk),
    today => (colors.warningBg, colors.warningInk),
    upcoming => (colors.infoBg, colors.infoInk),
    completed => (colors.successBg, colors.successInk),
  };
}

class TasksScreen extends StatelessWidget {
  final PlannerController planner;
  const TasksScreen({super.key, required this.planner});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        final snapshot = planner.snapshot;
        final now = planner.now;
        final today = tz.TZDateTime.from(now, jakarta);
        final tomorrow = tz.TZDateTime(
          jakarta,
          today.year,
          today.month,
          today.day + 1,
        );
        final groups = {for (final group in _TaskGroup.values) group: <Task>[]};
        final tasks = [...snapshot.tasks]
          ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
        var remainingMinutes = 0;
        for (final task in tasks) {
          final group = task.remainingMinutes == 0
              ? _TaskGroup.completed
              : !task.deadlineAt.isAfter(now)
              ? _TaskGroup.overdue
              : task.deadlineAt.isBefore(tomorrow)
              ? _TaskGroup.today
              : _TaskGroup.upcoming;
          groups[group]!.add(task);
          remainingMinutes += task.remainingMinutes;
        }
        final completedCount = groups[_TaskGroup.completed]!.length;
        final started = {
          for (final session in snapshot.sessions)
            if (session.status == SessionStatus.completed) session.taskId,
        };
        final pending = planner.isPending;
        final locked = pending || planner.isOfflineSnapshot;

        return PageContent(
          actions: Tooltip(
            message: 'Tambah tugas',
            child: AppButton(
              label: 'Tambah tugas',
              icon: 'imgPlus',
              onPressed: locked ? null : () => context.push('/task/new'),
            ),
          ),
          children: [
            Semantics(
              liveRegion: true,
              child: PageHeading(
                'Daftar tugas',
                pending && tasks.isEmpty
                    ? 'Menyiapkan daftar untuk akun Anda.'
                    : '${tasks.length - completedCount} aktif · $completedCount selesai · $remainingMinutes menit tersisa',
              ),
            ),
            if (pending)
              Semantics(
                liveRegion: true,
                child: PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tasks.isEmpty ? 'Memuat tugas…' : 'Memperbarui tugas…',
                      ),
                      const SizedBox(height: AppLayout.space8),
                      const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ErrorNotice(planner.error),
            if (tasks.isEmpty && !pending)
              const EmptyState(
                title: 'Belum ada tugas',
                message:
                    'Tambahkan tugas pertama untuk mulai merencanakan tenggat dan waktu belajarmu.',
              ),
            for (final MapEntry(key: group, value: items) in groups.entries)
              if (items.isNotEmpty) ...[
                _GroupHeading(group: group, count: items.length),
                for (final task in items)
                  _TaskCard(
                    key: ValueKey(task.id),
                    task: task,
                    started: started.contains(task.id),
                    locked: locked,
                    planner: planner,
                  ),
                const SizedBox(height: AppLayout.space12),
              ],
            if (tasks.isNotEmpty)
              Text(
                'Perubahan tugas tidak mengganti jadwal tersimpan secara otomatis.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        );
      },
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.group, required this.count});

  final _TaskGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = group.palette(AppColors.of(context));
    final type = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.space12),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppLayout.controlRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppLayout.space12),
          child: Semantics(
            header: true,
            label: '${group.label}, $count tugas',
            excludeSemantics: true,
            child: Row(
              children: [
                DesignIcon(group.icon, size: 18, color: ink),
                const SizedBox(width: AppLayout.space8),
                Expanded(
                  child: Text(
                    group.label,
                    style: type.titleMedium?.copyWith(color: ink),
                  ),
                ),
                const SizedBox(width: AppLayout.space8),
                Text('$count', style: AppTypography.time.copyWith(color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.started,
    required this.locked,
    required this.planner,
  });

  final Task task;
  final bool started, locked;
  final PlannerController planner;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = Theme.of(context).textTheme;
    final completed = task.remainingMinutes == 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final markLabel = completed
        ? '${task.title} selesai'
        : 'Tandai ${task.title} selesai';
    final actionStyle = ButtonStyle(
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: colors.focus, width: 2)
            : BorderSide.none,
      ),
    );

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: markLabel,
                excludeFromSemantics: true,
                child: Checkbox(
                  // Replace the native toggle only when its check animation must be skipped.
                  key: reduceMotion ? ValueKey(completed) : null,
                  value: completed,
                  semanticLabel: markLabel,
                  visualDensity: VisualDensity.standard,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  hoverColor: colors.primarySoft,
                  splashRadius: reduceMotion ? 0 : null,
                  checkColor: colors.successBg,
                  fillColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? colors.successInk
                        : null,
                  ),
                  focusColor: colors.focus.withValues(alpha: .18),
                  side: WidgetStateBorderSide.resolveWith(
                    (states) => states.contains(WidgetState.focused)
                        ? BorderSide(color: colors.focus, width: 2)
                        : states.contains(WidgetState.disabled)
                        ? BorderSide(color: colors.inkMuted)
                        : BorderSide(color: colors.outline),
                  ),
                  onChanged: locked || completed
                      ? null
                      : (_) => planner.saveTask(
                          id: task.id,
                          title: task.title,
                          course: task.course,
                          deadline: task.deadlineAt,
                          remaining: 0,
                          expectedRevision: planner.snapshot.revision,
                        ),
                ),
              ),
              const SizedBox(width: AppLayout.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: type.titleLarge),
                    if (task.course case final course?)
                      Text(
                        course,
                        style: type.bodySmall?.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                    const SizedBox(height: AppLayout.space4),
                    Text(
                      'Tenggat ${dateTimeLabel(task.deadlineAt)}',
                      style: type.bodySmall?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                    if (!completed) ...[
                      const SizedBox(height: AppLayout.space4),
                      Text(
                        '${task.remainingMinutes} menit tersisa',
                        style: AppTypography.time,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.space8),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: completed
                      ? const StatusBadge('Selesai', tone: StatusTone.success)
                      : started
                      ? const StatusBadge(
                          'Dalam proses',
                          tone: StatusTone.info,
                          icon: 'imgClock',
                        )
                      : const StatusBadge('Belum mulai', icon: 'imgCalendar'),
                ),
              ),
              IconButton(
                tooltip: 'Ubah ${task.title}',
                visualDensity: VisualDensity.standard,
                style: actionStyle,
                icon: const DesignIcon('imgEdit', size: 18),
                onPressed: locked
                    ? null
                    : () => context.push('/task/${task.id}'),
              ),
              IconButton(
                tooltip: 'Hapus ${task.title}',
                visualDensity: VisualDensity.standard,
                style: actionStyle,
                color: colors.dangerInk,
                icon: const DesignIcon('imgTrash', size: 18),
                onPressed: locked
                    ? null
                    : () async {
                        final revision = planner.snapshot.revision;
                        final confirmed = await confirmDelete(
                          context,
                          'Hapus tugas?',
                          '${task.title}\nSeluruh sesi terkait, termasuk riwayat, juga akan dihapus.',
                          'Hapus tugas dan sesi',
                        );
                        if (confirmed) {
                          await planner.deleteTask(
                            task.id,
                            confirmed: true,
                            expectedRevision: revision,
                          );
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
