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
      final active = tasks.where((t) => t.remainingMinutes > 0).toList()
        ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
      final late = active.where((t) => !t.deadlineAt.isAfter(planner.now));
      final sessions =
          planner.snapshot.sessions
              .where((s) => s.status == SessionStatus.planned)
              .toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final next = sessions.firstOrNull;
      final started = next != null && !next.startsAt.isAfter(planner.now);
      final today =
          planner.snapshot.sessions
              .where(
                (s) =>
                    s.status != SessionStatus.cancelled &&
                    dateLabel(s.startsAt) == dateLabel(planner.now),
              )
              .toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final locked = planner.isPending || planner.isOfflineSnapshot;
      return PageContent(
        children: [
          FocusPanel(
            eyebrow: dateLabel(planner.now),
            title: started
                ? 'Saatnya catat\nlangkah Anda.'
                : 'Beri ruang\nuntuk fokus.',
            description:
                '${active.length} tugas aktif \u00b7 ${active.fold(0, (int n, t) => n + t.remainingMinutes)} menit tersisa',
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (next != null) ...[
                  const Divider(color: AppColors.onForest, height: 1),
                  const SizedBox(height: 16),
                  Text(
                    started ? 'SESI PERLU DICATAT' : 'SESI BERIKUTNYA',
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    planner.taskById(next.taskId)?.title ?? next.taskId,
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${dateLabel(next.startsAt)}\n${clockLabel(next.startsAt)} \u2013 ${clockLabel(next.endsAt)} WIB',
                    style: const TextStyle(
                      color: AppColors.onForest,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: started
                        ? 'Catat progres sesi'
                        : 'Buka sesi berikutnya',
                    highlighted: true,
                    icon: started ? 'imgCheckCircle' : 'imgArrowRight',
                    onPressed: started && locked
                        ? null
                        : () => context.push('/session/${next.id}'),
                  ),
                ] else if (tasks.isEmpty)
                  AppButton(
                    label: 'Tambah tugas',
                    highlighted: true,
                    icon: 'imgPlus',
                    onPressed: locked ? null : () => context.push('/task/new'),
                  )
                else
                  AppButton(
                    label: 'Tinjau jadwal',
                    highlighted: true,
                    icon: 'imgArrowRight',
                    onPressed: () => context.go('/schedule'),
                  ),
              ],
            ),
          ),
          if (planner.needsReschedule) ...[
            const SizedBox(height: 16),
            const Notice(
              title: 'Jadwal perlu diperbarui',
              message:
                  'Data berubah. Tinjau jadwal sebelum mulai sesi berikutnya.',
              color: AppColors.warning,
              icon: 'imgAlertCircle',
            ),
          ],
          if (tasks.isEmpty)
            TextButton(
              onPressed: () => context.go('/time'),
              child: const Text('Atur waktu yang diizinkan'),
            ),
          ErrorNotice(planner.error),
          if (late.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Tugas terlambat',
              subtitle: 'Perbarui tenggat dan estimasi pengerjaan.',
            ),
            for (final task in late)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const DesignIcon(
                  'imgAlertCircle',
                  color: AppColors.error,
                ),
                title: Text(task.title),
                subtitle: Text(
                  'Terlambat \u00b7 ${task.remainingMinutes} menit tersisa',
                ),
                trailing: const DesignIcon('imgChevronRight'),
                onTap: () => context.push('/task/${task.id}'),
              ),
          ],
          const SizedBox(height: 8),
          SectionHeader(
            title: 'Agenda hari ini',
            trailing: TextButton(
              onPressed: () => context.go('/schedule'),
              child: const Text('Lihat semua'),
            ),
          ),
          if (today.isEmpty)
            const PaperCard(
              color: AppColors.primarySoft,
              child: Row(
                children: [
                  DesignIcon('imgCalendar', color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Belum ada sesi terkonfirmasi hari ini.',
                      style: TextStyle(color: AppColors.inkSecondary),
                    ),
                  ),
                ],
              ),
            ),
          for (final session in today)
            SessionCard(
              session: session,
              title: planner.taskById(session.taskId)?.title ?? session.taskId,
              onTap: () => context.push('/session/${session.id}'),
            ),
          if (active.any((t) => t.deadlineAt.isAfter(planner.now))) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Jangan lewatkan tenggat'),
            for (final task
                in active
                    .where((t) => t.deadlineAt.isAfter(planner.now))
                    .take(3)) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${dateTimeLabel(task.deadlineAt)}\n${task.remainingMinutes} menit tersisa',
                  ),
                ),
                trailing: const DesignIcon('imgChevronRight', size: 20),
                onTap: () => context.push('/task/${task.id}'),
              ),
              const Divider(height: 16),
            ],
          ],
          if (planner.preview != null &&
              planner.preview!.unallocated.isNotEmpty)
            Notice(
              title: 'Pratinjau terakhir \u00b7 belum disimpan',
              color: AppColors.warning,
              icon: 'imgAlertCircle',
              message: planner.preview!.unallocated
                  .map(
                    (u) =>
                        '${planner.taskById(u.taskId)?.title ?? u.taskId}: ${u.minutes} menit belum tertampung',
                  )
                  .join('\n'),
            ),
        ],
      );
    },
  );
}
