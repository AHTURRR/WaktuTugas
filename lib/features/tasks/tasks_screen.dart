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
        const PageHeading(
          'Tugas',
          'Catat sisa pekerjaan, bukan hanya tenggatnya.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: 'Tambah tugas',
            child: FilledButton.icon(
              onPressed: planner.isPending
                  ? null
                  : () => context.push('/task/new'),
              icon: const Icon(Icons.add),
              label: const Text('Tambah tugas'),
            ),
          ),
        ),
        ErrorNotice(planner.error),
        if (planner.snapshot.tasks.isEmpty)
          const Text('Belum ada tugas. Tambahkan tugas pertama Anda.'),
        for (final task in planner.snapshot.tasks)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(task.title),
              subtitle: Text(
                '${task.course == null ? '' : '${task.course}\n'}${dateTimeLabel(task.deadlineAt)}\n${task.remainingMinutes == 0 ? 'Selesai' : '${task.remainingMinutes} menit tersisa'}${task.remainingMinutes > 0 && !task.deadlineAt.isAfter(planner.now) ? ' • Terlambat' : ''}',
              ),
              onTap: () => context.push('/task/${task.id}'),
              trailing: IconButton(
                tooltip: 'Hapus ${task.title}',
                icon: const Icon(Icons.delete_outline),
                onPressed: planner.isPending
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
            ),
          ),
      ],
    ),
  );
}
