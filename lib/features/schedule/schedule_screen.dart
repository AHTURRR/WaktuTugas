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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                sessions.isEmpty
                    ? 'Belum ada jadwal'
                    : planner.needsReschedule
                    ? 'Perlu ditinjau'
                    : 'Terkonfirmasi',
                icon: 'imgCheckCircle',
              ),
              const Text('Semua jam WIB'),
            ],
          ),
          const SizedBox(height: 16),
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
            ),
          AppButton(
            label: planner.isPending ? 'Menghitung…' : 'Hitung pratinjau',
            icon: 'imgRefreshCw',
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
          ErrorNotice(planner.error),
          if (!planner.isApiBacked) ...[
            const SizedBox(height: 12),
            Notice(
              title: 'Demo lokal · ${dateTimeLabel(planner.now)}',
              message: 'Waktu contoh tidak mengikuti jam perangkat.',
              color: AppColors.warning,
            ),
            AppButton(
              label: 'Majukan jam demo ke sesi berikutnya',
              secondary: true,
              onPressed: planner.isPending ? null : planner.advanceDemoClock,
            ),
          ],
          const SizedBox(height: 16),
          if (sessions.isEmpty)
            const EmptyState(
              title: 'Belum ada jadwal terkonfirmasi',
              message:
                  'Hitung pratinjau dari tugas dan waktu yang diizinkan, lalu konfirmasi. Hasil pratinjau belum menjadi jadwal tersimpan.',
            ),
          for (final s in sessions) ...[
            if (lastDate != dateLabel(s.startsAt))
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  lastDate = dateLabel(s.startsAt),
                  style: Theme.of(context).textTheme.titleMedium,
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
          const Text(
            'Konfirmasi baru hanya mengganti sesi rencana mendatang. Riwayat selesai dan terlewat tetap ada.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    },
  );
}
