import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../planner/models.dart';
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
          const PageHeading(
            'Jadwal pengerjaan',
            'Pratinjau dahulu. Konfirmasi jika sudah sesuai.',
          ),
          if (missingPreview)
            const ErrorNotice('Hitung pratinjau terlebih dahulu.'),
          if (planner.hasStartedPlanned)
            const ErrorNotice(
              'Tutup progres sesi yang sudah mulai sebelum menyusun ulang.',
            ),
          if (planner.needsReschedule)
            ErrorNotice(
              'Data berubah. Jadwal perlu disusun ulang. ${invalid.length} sesi mendatang tidak sesuai data terbaru.',
            ),
          FilledButton.icon(
            onPressed: planner.isPending || planner.hasStartedPlanned
                ? null
                : () async {
                    final ok = await planner.generatePreview();
                    if (ok && context.mounted) {
                      context.push('/schedule/preview');
                    }
                  },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(planner.isPending ? 'Menghitung…' : 'Hitung pratinjau'),
          ),
          ErrorNotice(planner.error),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: planner.isPending ? null : planner.advanceDemoClock,
            child: const Text('Majukan jam demo ke sesi berikutnya'),
          ),
          const Text(
            'Kontrol demo lokal untuk mencoba progres. Waktu tidak mengikuti jam perangkat.',
          ),
          const SizedBox(height: 20),
          if (sessions.isEmpty)
            const Text(
              'Belum ada jadwal terkonfirmasi. Hasil pratinjau belum menjadi jadwal tersimpan.',
            ),
          for (final s in sessions) ...[
            if (lastDate != dateLabel(s.startsAt))
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  lastDate = dateLabel(s.startsAt),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Card(
              child: ListTile(
                key: Key('session-${s.id}'),
                title: Text(planner.taskById(s.taskId)!.title),
                subtitle: Text(
                  '${dateTimeLabel(s.startsAt)}\nSampai ${dateTimeLabel(s.endsAt)}\n${statusLabel(s.status)}${invalid.contains(s.id) ? ' • Perlu disusun ulang' : ''}',
                ),
                leading: Icon(
                  s.status == SessionStatus.completed
                      ? Icons.check_circle_outline
                      : s.status == SessionStatus.missed
                      ? Icons.event_busy
                      : s.status == SessionStatus.cancelled
                      ? Icons.cancel_outlined
                      : Icons.schedule,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/session/${s.id}'),
              ),
            ),
          ],
        ],
      );
    },
  );
}
