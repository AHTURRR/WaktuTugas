import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../planner/schedule.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';
import 'reasons_screen.dart';

class PreviewScreen extends StatelessWidget {
  final PlannerController planner;
  const PreviewScreen({super.key, required this.planner});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pratinjau jadwal')),
    body: ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        final p = planner.preview;
        if (p == null) {
          return PageContent(
            children: [
              const Text('Hitung pratinjau terlebih dahulu.'),
              TextButton(
                onPressed: () => context.go('/schedule'),
                child: const Text('Kembali ke jadwal'),
              ),
            ],
          );
        }
        final stale =
            p.inputRevision != planner.snapshot.revision ||
            p.windowEnd != horizonEnd(planner.now) ||
            p.sessions.any((s) => !s.startsAt.isAfter(planner.now));
        final locked = planner.isPending || planner.isOfflineSnapshot;
        final totalCandidateMinutes = p.sessions.fold(
          0,
          (int n, s) => n + s.endsAt.difference(s.startsAt).inMinutes,
        );

        return PageContent(
          actions: p.sessions.isEmpty
              ? AppButton(
                  label: 'Kembali ke Jadwal',
                  onPressed: () => context.go('/schedule'),
                  secondary: true,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Mengganti sesi rencana mendatang. Riwayat tetap tersimpan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: planner.isPending
                          ? 'Menyimpan…'
                          : 'Konfirmasi jadwal',
                      icon: 'imgCheck',
                      onPressed: locked || stale || planner.hasStartedPlanned
                          ? null
                          : () async {
                              final ok = await planner.confirmSchedule();
                              if (ok && context.mounted) {
                                context.go('/schedule');
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Hitung ulang',
                            secondary: true,
                            onPressed: locked
                                ? null
                                : () async {
                                    await planner.generatePreview();
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Batal',
                            secondary: true,
                            onPressed: planner.isPending
                                ? null
                                : () => context.go('/schedule'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          children: [
            SectionHeader(
              title: p.sessions.isEmpty
                  ? 'Belum ada kandidat'
                  : 'Periksa rencana Anda',
              subtitle: 'Usulan ini belum menjadi jadwal tersimpan.',
            ),
            if (stale)
              Notice(
                title: stale
                    ? 'Pratinjau kedaluwarsa · belum tersimpan'
                    : 'Belum tersimpan',
                message: stale
                    ? 'Data berubah atau waktu sesi sudah lewat. Hitung ulang sebelum konfirmasi.'
                    : 'Kandidat di bawah ini belum menjadi jadwal tersimpan sampai Anda menekan Konfirmasi jadwal.',
                color: p.unallocated.isEmpty && !stale
                    ? AppColors.primarySoft
                    : AppColors.warning,
                icon: 'imgAlertCircle',
              ),
            FocusPanel(
              eyebrow: 'USULAN / 14 TANGGAL',
              title: '${p.sessions.length} sesi usulan',
              icon: 'imgCalendar',
              description:
                  '${dateTimeLabel(p.windowStart)}\n${dateTimeLabel(p.windowEnd)}',
              footer: Text(
                'Dibuat ${dateTimeLabel(p.generatedAt)} \u00b7 revisi ${p.inputRevision}',
                style: const TextStyle(
                  color: AppColors.onForest,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            if (p.unallocated.isNotEmpty)
              PaperCard(
                color: AppColors.warningSoft,
                borderColor: AppColors.warningBorder,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        DesignIcon(
                          'imgAlertCircle',
                          size: 18,
                          color: AppColors.warningInk,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pekerjaan belum tertampung',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final u in p.unallocated)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planner.taskById(u.taskId)?.title ?? u.taskId,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              '${u.minutes} menit belum tertampung',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warningInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReasonsScreen(planner: planner),
                          ),
                        ),
                        child: const Text('Mengapa masih kurang?'),
                      ),
                    ),
                  ],
                ),
              ),
            if (p.unallocated.isEmpty)
              const Notice(
                title: 'Kapasitas mencukupi',
                message: 'Seluruh sisa pekerjaan tertampung dalam jendela ini.',
                color: AppColors.successSoft,
                icon: 'imgCheckCircle',
              ),
            if (p.sessions.isEmpty)
              const EmptyState(
                title: 'Tidak ada sesi usulan',
                message:
                    'Periksa tugas aktif, tenggat, serta waktu bersih yang diizinkan. Jadwal tersimpan tidak berubah.',
              )
            else
              PaperCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Sesi usulan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$totalCandidateMinutes menit',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < p.sessions.length; i++) ...[
                      if (i == 0 ||
                          dateLabel(p.sessions[i - 1].startsAt) !=
                              dateLabel(p.sessions[i].startsAt))
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            dateLabel(p.sessions[i].startsAt),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${clockLabel(p.sessions[i].startsAt)} \u2013 ${clockLabel(p.sessions[i].endsAt)} WIB',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              planner.taskById(p.sessions[i].taskId)?.title ??
                                  p.sessions[i].taskId,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.sessions[i].taskId} \u00b7 ${p.sessions[i].endsAt.difference(p.sessions[i].startsAt).inMinutes} menit \u00b7 Usulan',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Semua jam WIB · usulan, bukan agenda tersimpan',
                      style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            PaperCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alokasi / sisa kebutuhan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final task in planner.snapshot.tasks.where(
                    (t) => t.remainingMinutes > 0,
                  ))
                    Builder(
                      builder: (_) {
                        final allocated = p.sessions
                            .where((s) => s.taskId == task.id)
                            .fold(
                              0,
                              (int n, s) =>
                                  n + s.endsAt.difference(s.startsAt).inMinutes,
                            );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Terjadwal $allocated dari ${task.remainingMinutes} menit · kurang ${task.remainingMinutes - allocated}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const Text(
              'Kandidat valid boleh dikonfirmasi meski ada kekurangan. Konfirmasi mengganti sesi mendatang; riwayat tetap ada.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            ErrorNotice(planner.error),
          ],
        );
      },
    ),
  );
}
