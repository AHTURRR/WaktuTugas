import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class TasksScreen extends StatelessWidget {
  final PlannerController planner;
  const TasksScreen({super.key, required this.planner});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) => PageContent(
      children: [
        Text(
          '${planner.snapshot.tasks.where((t) => t.remainingMinutes > 0).length} tugas aktif · ${planner.snapshot.tasks.fold(0, (int n, t) => n + t.remainingMinutes)} menit tersisa',
        ),
        const SizedBox(height: 12),
        Tooltip(
          message: 'Tambah tugas',
          child: AppButton(
            label: 'Tambah tugas',
            icon: 'imgPlus',
            onPressed: planner.isPending || planner.isOfflineSnapshot
                ? null
                : () => context.push('/task/new'),
          ),
        ),
        const SizedBox(height: 12),
        ErrorNotice(planner.error),
        if (planner.snapshot.tasks.isEmpty)
          const EmptyState(
            title: 'Belum ada tugas',
            message:
                'Tambahkan nama, tenggat, dan sisa menit untuk mulai merencanakan.',
          ),
        for (final task in planner.snapshot.tasks)
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: Theme.of(context).textTheme.titleLarge),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
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
                    IconButton(
                      tooltip: 'Ubah ${task.title}',
                      icon: const DesignIcon('imgEdit', size: 20),
                      onPressed: planner.isPending || planner.isOfflineSnapshot
                          ? null
                          : () => context.push('/task/${task.id}'),
                    ),
                    IconButton(
                      tooltip: 'Hapus ${task.title}',
                      icon: const DesignIcon('imgTrash', size: 20),
                      onPressed: planner.isPending || planner.isOfflineSnapshot
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
                if (task.course != null) ...[
                  const SizedBox(height: 12),
                  Text(task.course!),
                ],
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DesignIcon('imgCalendar', size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateTimeLabel(task.deadlineAt),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${task.remainingMinutes} menit tersisa'),
              ],
            ),
          ),
        const Text(
          'Perubahan tugas tidak mengganti jadwal tersimpan secara otomatis.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
