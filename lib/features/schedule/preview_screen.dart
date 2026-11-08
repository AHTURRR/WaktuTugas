import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

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
        final stale = p.inputRevision != planner.snapshot.revision;
        return PageContent(
          children: [
            const PageHeading(
              'Periksa rencana Anda',
              'Belum tersimpan. Konfirmasi akan mengganti sesi mendatang; riwayat tetap ada.',
            ),
            Text(
              'Jendela 14 tanggal\n${dateTimeLabel(p.windowStart)} – ${dateTimeLabel(p.windowEnd)}',
            ),
            Text(
              'Revisi data ${p.inputRevision} • dibuat ${dateTimeLabel(p.generatedAt)}',
            ),
            const SizedBox(height: 16),
            if (stale)
              const ErrorNotice('Data berubah. Hitung ulang pratinjau.'),
            if (p.unallocated.isEmpty)
              const Text(
                'Seluruh sisa pekerjaan tertampung dalam jendela ini.',
              ),
            for (final u in p.unallocated)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planner.taskById(u.taskId)?.title ?? u.taskId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('${u.minutes} menit belum tertampung'),
                      Text(u.reason.label),
                      const Text(
                        'Tambah rentang atau perbarui estimasi. Tenggat tidak diubah otomatis.',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '${p.sessions.length} sesi diusulkan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final s in p.sessions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(planner.taskById(s.taskId)?.title ?? s.taskId),
                subtitle: Text(
                  '${dateTimeLabel(s.startsAt)}\nSampai ${dateTimeLabel(s.endsAt)} • ${s.endsAt.difference(s.startsAt).inMinutes} menit',
                ),
              ),
            ErrorNotice(planner.error),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: planner.isPending || stale
                  ? null
                  : () async {
                      final ok = await planner.confirmSchedule();
                      if (ok && context.mounted) context.go('/schedule');
                    },
              child: Text(
                planner.isPending ? 'Menyimpan…' : 'Konfirmasi jadwal',
              ),
            ),
            TextButton(
              onPressed: planner.isPending
                  ? null
                  : () async {
                      await planner.generatePreview();
                    },
              child: const Text('Hitung ulang'),
            ),
            TextButton(
              onPressed: planner.isPending
                  ? null
                  : () => context.go('/schedule'),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    ),
  );
}
