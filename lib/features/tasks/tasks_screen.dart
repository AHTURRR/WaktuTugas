import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class TasksScreen extends StatelessWidget {
  final PlannerController planner;
  const TasksScreen({super.key, required this.planner});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) {
      final activeCount = planner.snapshot.tasks
          .where((t) => t.remainingMinutes > 0)
          .length;
      final remainingMinutes = planner.snapshot.tasks.fold(
        0,
        (int n, t) => n + t.remainingMinutes,
      );
      final locked = planner.isPending || planner.isOfflineSnapshot;

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
          PageHeading(
            'Tugas, tertata.',
            '$activeCount tugas aktif \u00b7 $remainingMinutes menit tersisa',
          ),
          ErrorNotice(planner.error),
          if (planner.snapshot.tasks.isEmpty)
            const EmptyState(
              title: 'Belum ada tugas',
              message:
                  'Tambahkan nama, tenggat, dan sisa menit untuk mulai merencanakan.',
            ),
          for (final task in planner.snapshot.tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radius),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppLayout.radius),
                  onTap: locked ? null : () => context.push('/task/${task.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(
                          task.remainingMinutes == 0
                              ? 'Selesai'
                              : !task.deadlineAt.isAfter(planner.now)
                              ? 'Terlambat'
                              : 'Aktif',
                          icon: task.remainingMinutes == 0
                              ? 'imgCheckCircle'
                              : !task.deadlineAt.isAfter(planner.now)
                              ? 'imgAlertCircle'
                              : 'imgClock',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (task.course != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            task.course!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const DesignIcon(
                              'imgCalendar',
                              size: 16,
                              color: AppColors.inkMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tenggat ${dateTimeLabel(task.deadlineAt)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const DesignIcon(
                              'imgClock',
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${task.remainingMinutes} menit tersisa',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ubah ${task.title}',
                              visualDensity: VisualDensity.standard,
                              icon: const DesignIcon(
                                'imgEdit',
                                size: 18,
                                color: AppColors.inkSecondary,
                              ),
                              onPressed: locked
                                  ? null
                                  : () => context.push('/task/${task.id}'),
                            ),
                            IconButton(
                              tooltip: 'Hapus ${task.title}',
                              visualDensity: VisualDensity.standard,
                              icon: const DesignIcon(
                                'imgTrash',
                                size: 18,
                                color: AppColors.error,
                              ),
                              onPressed: locked
                                  ? null
                                  : () async {
                                      final revision =
                                          planner.snapshot.revision;
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
                  ),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Perubahan tugas tidak mengganti jadwal tersimpan secara otomatis.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ),
        ],
      );
    },
  );
}
