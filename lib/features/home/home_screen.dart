import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
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
      Widget metric(String value, String label, Color color) => PaperCard(
        color: color,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
      return PageContent(
        children: [
          Text(dateLabel(planner.now), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 14),
          Text(
            'Ruang untuk fokus',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Container(
            height: 128,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.cyan,
              border: Border.all(width: 2, color: AppColors.ink),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StudyIllustration(),
                SizedBox(width: 32),
                DesignIcon('imgWaktuTugasIllustrationSparkle', size: 28),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: metric(
                  '${tasks.where((t) => t.remainingMinutes > 0).length}',
                  'tugas aktif',
                  AppColors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: metric(
                  '${tasks.fold(0, (int n, t) => n + t.remainingMinutes)}',
                  'menit tersisa',
                  AppColors.lilac,
                ),
              ),
            ],
          ),
          if (tasks.isEmpty)
            EmptyState(
              title: 'Mulai dari satu tugas',
              message:
                  'Tambahkan tugas dan waktu yang boleh digunakan. Waktu kosong tidak otomatis menjadi waktu belajar.',
              action: AppButton(
                label: 'Tambah tugas',
                icon: 'imgPlus',
                onPressed: planner.isOfflineSnapshot
                    ? null
                    : () => context.push('/task/new'),
              ),
            )
          else
            AppButton(
              label: 'Tinjau jadwal',
              icon: 'imgCalendarAction',
              onPressed: () => context.go('/schedule'),
            ),
          if (tasks.isEmpty)
            TextButton(
              onPressed: () => context.go('/time'),
              child: const Text('Atur waktu yang diizinkan'),
            ),
          const SizedBox(height: 14),
          if (planner.hasStartedPlanned) ...[
            const Notice(
              title: 'Jadwal perlu diperbarui',
              message:
                  'Ada sesi yang sudah mulai. Catat progres sebelum menyusun ulang.',
              color: AppColors.warning,
              icon: 'imgAlertCircle',
            ),
            AppButton(
              label: 'Catat progres sesi',
              onPressed: () => context.push(
                '/session/${planner.snapshot.sessions.firstWhere((s) => s.status == SessionStatus.planned && !s.startsAt.isAfter(planner.now)).id}',
              ),
            ),
          ] else if (planner.needsReschedule)
            const Notice(
              title: 'Jadwal perlu diperbarui',
              message: 'Data berubah. Jadwal perlu ditinjau dan disusun ulang.',
              color: AppColors.warning,
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sesi hari ini',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/schedule'),
                child: const Text('Lihat semua'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (today.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada sesi terkonfirmasi hari ini.'),
            ),
          for (final s in today)
            SessionCard(
              session: s,
              title: planner.taskById(s.taskId)?.title ?? s.taskId,
              onTap: () => context.push('/session/${s.id}'),
            ),
          if (late.isNotEmpty) ...[
            Text(
              'Tugas terlambat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final t in late)
              ListTile(
                title: Text(t.title),
                subtitle: Text('${t.remainingMinutes} menit tersisa'),
                onTap: () => context.push('/task/${t.id}'),
              ),
          ],
          if (planner.preview != null &&
              planner.preview!.unallocated.isNotEmpty)
            Notice(
              title: 'Pratinjau terakhir · belum disimpan',
              color: AppColors.warning,
              icon: 'imgAlertCircle',
              message: planner.preview!.unallocated
                  .map(
                    (u) =>
                        '${planner.taskById(u.taskId)?.title ?? u.taskId}: ${u.minutes} menit belum tertampung · ${u.reason.label}',
                  )
                  .join('\n'),
            ),
        ],
      );
    },
  );
}
