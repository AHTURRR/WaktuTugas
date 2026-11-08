import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../planner/models.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class HomeScreen extends StatelessWidget {
  final PlannerController planner;
  const HomeScreen({super.key, required this.planner});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) {
      final tasks = planner.snapshot.tasks;
      final today = planner.snapshot.sessions.where(
        (s) =>
            s.status != SessionStatus.cancelled &&
            dateLabel(s.startsAt) == dateLabel(planner.now),
      );
      final late = tasks.where(
        (t) => t.remainingMinutes > 0 && !t.deadlineAt.isAfter(planner.now),
      );
      return PageContent(
        children: [
          PageHeading('Ruang untuk fokus', dateLabel(planner.now)),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tasks.where((t) => t.remainingMinutes > 0).length} tugas aktif',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tasks.fold(0, (int n, t) => n + t.remainingMinutes)} menit sisa pengerjaan',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/schedule'),
                    child: const Text('Tinjau jadwal'),
                  ),
                ],
              ),
            ),
          ),
          if (tasks.isEmpty)
            const Text('Mulai dengan menambahkan tugas dan waktu pengerjaan.'),
          if (planner.hasStartedPlanned)
            const ErrorNotice(
              'Ada sesi yang sudah mulai. Catat progres sebelum menyusun ulang.',
            ),
          if (planner.needsReschedule)
            const ErrorNotice(
              'Data berubah. Jadwal perlu ditinjau dan disusun ulang.',
            ),
          const SizedBox(height: 24),
          Text('Sesi hari ini', style: Theme.of(context).textTheme.titleLarge),
          if (today.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Belum ada sesi terkonfirmasi hari ini.'),
            ),
          for (final s in today)
            ListTile(
              title: Text(planner.taskById(s.taskId)!.title),
              subtitle: Text(
                '${dateTimeLabel(s.startsAt)} • ${statusLabel(s.status)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/session/${s.id}'),
            ),
          if (late.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Tugas terlambat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final t in late)
              ListTile(
                title: Text(t.title),
                subtitle: Text('${t.remainingMinutes} menit tersisa'),
              ),
          ],
          if (planner.preview != null) ...[
            const SizedBox(height: 16),
            const Text('Kekurangan pada pratinjau terakhir (belum disimpan)'),
            for (final u in planner.preview!.unallocated)
              Text(
                '${planner.taskById(u.taskId)?.title ?? u.taskId}: ${u.minutes} menit • ${u.reason.label}',
              ),
          ],
        ],
      );
    },
  );
}
