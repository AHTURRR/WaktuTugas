import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class ScheduleScreen extends StatelessWidget {
  final PlannerController planner;
  final bool missingPreview;
  const ScheduleScreen({
    super.key,
    required this.planner,
    this.missingPreview = false,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) {
      final sessions = [...planner.snapshot.sessions]
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final invalid = planner.invalidPlannedIds;
      String? lastDate;

      return PageContent(
        children: [
          FocusPanel(
            eyebrow: 'AGENDA FOKUS',
            title: 'Rencana Anda.',
            description:
                'Rencana yang realistis dimulai dari waktu yang benar-benar tersedia.',
            icon: 'imgCalendar',
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      sessions.isEmpty
                          ? 'Belum ada jadwal'
                          : planner.needsReschedule
                          ? 'Perlu ditinjau'
                          : 'Terkonfirmasi',
                      icon: sessions.isEmpty
                          ? 'imgClock'
                          : planner.needsReschedule
                          ? 'imgAlertCircle'
                          : 'imgCheckCircle',
                    ),
                    const Text(
                      'Semua jam WIB',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onForest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 14),
                AppButton(
                  label: planner.isPending ? 'Menghitung…' : 'Hitung pratinjau',
                  icon: 'imgRefreshCw',
                  highlighted: true,
                  onPressed:
                      planner.isPending ||
                          planner.hasStartedPlanned ||
                          planner.isOfflineSnapshot
                      ? null
                      : () async {
                          final ok = await planner.generatePreview();
                          if (ok && context.mounted) {
                            context.push('/schedule/preview');
                          }
                        },
                ),
              ],
            ),
          ),
          if (missingPreview)
            const ErrorNotice('Hitung pratinjau terlebih dahulu.'),
          if (planner.hasStartedPlanned)
            const Notice(
              title: 'Catat progres dahulu',
              message:
                  'Tutup progres sesi yang sudah mulai sebelum menyusun ulang.',
              color: AppColors.warning,
              icon: 'imgAlertCircle',
            ),
          if (planner.needsReschedule)
            Notice(
              title: 'Jadwal perlu ditinjau',
              message:
                  'Data berubah. ${invalid.length} sesi mendatang tidak sesuai data terbaru.',
              color: AppColors.warning,
              icon: 'imgAlertCircle',
            ),
          ErrorNotice(planner.error),
          if (sessions.isEmpty)
            const EmptyState(
              title: 'Belum ada jadwal terkonfirmasi',
              message:
                  'Hitung pratinjau dari tugas dan waktu yang diizinkan, lalu konfirmasi. Hasil pratinjau belum menjadi jadwal tersimpan.',
            ),
          for (final s in sessions) ...[
            if (lastDate != dateLabel(s.startsAt))
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastDate = dateLabel(s.startsAt),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            SessionCard(
              key: Key('session-${s.id}'),
              session: s,
              title: planner.taskById(s.taskId)?.title ?? s.taskId,
              invalid: invalid.contains(s.id),
              onTap: () => context.push('/session/${s.id}'),
            ),
          ],
          if (!planner.isApiBacked) ...[
            PaperCard(
              color: AppColors.surfaceMuted,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const DesignIcon(
                        'imgClock',
                        size: 16,
                        color: AppColors.inkSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demo lokal · ${dateTimeLabel(planner.now)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Waktu contoh tidak mengikuti jam perangkat.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Majukan jam demo ke sesi berikutnya',
                    secondary: true,
                    icon: 'imgSkipForward',
                    onPressed: planner.isPending
                        ? null
                        : planner.advanceDemoClock,
                  ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Konfirmasi baru hanya mengganti sesi rencana mendatang. Riwayat selesai dan terlewat tetap ada.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ),
        ],
      );
    },
  );
}
