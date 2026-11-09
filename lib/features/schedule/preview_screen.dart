import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
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
            Text(
              p.sessions.isEmpty
                  ? 'Belum ada kandidat'
                  : 'Periksa rencana Anda',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Notice(
              title: stale
                  ? 'Pratinjau kedaluwarsa · belum tersimpan'
                  : 'Belum tersimpan',
              message: stale
                  ? 'Data berubah atau waktu sesi sudah lewat. Hitung ulang sebelum konfirmasi.'
                  : null,
              color: p.unallocated.isEmpty && !stale
                  ? AppColors.cyan
                  : AppColors.warning,
              icon: 'imgAlertCircle',
            ),
            Text(
              '${dateTimeLabel(p.windowStart)} – ${dateTimeLabel(p.windowEnd)}',
              style: const TextStyle(fontSize: 12),
            ),
            const Text(
              '14 tanggal kalender · semua jam WIB',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              'Dibuat ${dateTimeLabel(p.generatedAt)} · revisi data ${p.inputRevision}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (p.sessions.isEmpty)
              const EmptyState(
                title: 'Tidak ada sesi usulan',
                message:
                    'Periksa tugas aktif, tenggat, serta waktu bersih yang diizinkan. Jadwal tersimpan tidak berubah.',
              )
            else
              PaperCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      children: [
                        const Text(
                          'Sesi usulan',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${p.sessions.fold(0, (int n, s) => n + s.endsAt.difference(s.startsAt).inMinutes)} menit',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final s in p.sessions)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xffd4d9d0)),
                          ),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              DateFormat(
                                'd MMM',
                                'id_ID',
                              ).format(tz.TZDateTime.from(s.startsAt, jakarta)),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              s.taskId,
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${clockLabel(s.startsAt)}–${clockLabel(s.endsAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${s.endsAt.difference(s.startsAt).inMinutes} mnt',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Semua jam WIB · usulan, bukan agenda tersimpan',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            PaperCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alokasi / sisa kebutuhan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
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
                        return Text(
                          '${task.id}   $allocated / ${task.remainingMinutes} mnt · kurang ${task.remainingMinutes - allocated}',
                        );
                      },
                    ),
                ],
              ),
            ),
            for (final u in p.unallocated)
              Text('${u.minutes} menit belum tertampung'),
            if (p.unallocated.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReasonsScreen(planner: planner),
                  ),
                ),
                child: const Text('Mengapa masih kurang?'),
              ),
            if (p.unallocated.isEmpty)
              const Text(
                'Seluruh sisa pekerjaan tertampung dalam jendela ini.',
              ),
            const Text(
              'Kandidat valid boleh dikonfirmasi meski ada kekurangan. Konfirmasi mengganti sesi mendatang; riwayat tetap ada.',
              style: TextStyle(fontSize: 12),
            ),
            ErrorNotice(planner.error),
          ],
        );
      },
    ),
  );
}
