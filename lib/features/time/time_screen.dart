import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../planner/models.dart';
import '../../planner/schedule.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';
import 'time_form_screen.dart';

class TimeScreen extends StatelessWidget {
  final PlannerController planner;
  const TimeScreen({super.key, required this.planner});
  void edit(BuildContext context, {TimeWindow? window, bool activity = false}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => TimeFormScreen(
          planner: planner,
          window: window,
          activity: activity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) {
      final available = expandWindows(planner.snapshot, planner.now);
      Widget row(TimeWindow w, bool activity) => Card(
        child: ListTile(
          title: Text(
            w is Activity
                ? '${w.kind == ActivityKind.blocked
                      ? 'Penutupan'
                      : w.kind == ActivityKind.routine
                      ? 'Rutin'
                      : 'Kegiatan sekali'}: ${w.label}'
                : 'Waktu diizinkan',
          ),
          subtitle: Text(windowLabel(w)),
          onTap: () => edit(context, window: w, activity: activity),
          trailing: IconButton(
            tooltip: 'Hapus ${w.id}',
            icon: const Icon(Icons.delete_outline),
            onPressed: planner.isPending
                ? null
                : () async {
                    final revision = planner.snapshot.revision;
                    if (await confirmDelete(
                      context,
                      'Hapus rentang?',
                      'Jadwal tersimpan tetap ada dan perlu ditinjau ulang.',
                      'Hapus rentang',
                    )) {
                      await planner.deleteWindow(
                        w.id,
                        activity: activity,
                        expectedRevision: revision,
                      );
                    }
                  },
          ),
        ),
      );
      return PageContent(
        children: [
          const PageHeading(
            'Waktu Anda',
            'Gabungkan waktu pengerjaan, lalu kurangi kegiatan dan penutupan.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: planner.isPending ? null : () => edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Tambah rentang'),
              ),
              OutlinedButton.icon(
                onPressed: planner.isPending
                    ? null
                    : () => edit(context, activity: true),
                icon: const Icon(Icons.event_busy),
                label: const Text('Tambah kegiatan'),
              ),
            ],
          ),
          ErrorNotice(planner.error),
          const SizedBox(height: 16),
          Text(
            'Waktu diizinkan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (planner.snapshot.timeWindows.isEmpty)
            const Text(
              'Belum ada rentang. Waktu kosong tidak otomatis menjadi waktu pengerjaan.',
            ),
          ...planner.snapshot.timeWindows.map((w) => row(w, false)),
          const SizedBox(height: 16),
          Text(
            'Kegiatan & penutupan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (planner.snapshot.activities.isEmpty)
            const Text('Tidak ada kegiatan atau penutupan.'),
          ...planner.snapshot.activities.map((w) => row(w, true)),
          const SizedBox(height: 24),
          Text(
            'Waktu bersih • ${available.fold(0, (int n, w) => n + w.minutes)} menit',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${dateTimeLabel(ceilMinute(planner.now))} – ${dateTimeLabel(horizonEnd(planner.now))}',
          ),
          const Text(
            'Rentang bertumpuk dihitung sekali. Penutupan selalu mengurangi rentang tambahan.',
          ),
          for (final w in available)
            ListTile(
              dense: true,
              leading: const Icon(Icons.access_time),
              title: Text(dateLabel(w.start)),
              subtitle: Text(
                '${timeLabel(tz.TZDateTime.from(w.start, jakarta).hour * 60 + tz.TZDateTime.from(w.start, jakarta).minute)} – ${dateTimeLabel(w.end)} • ${w.minutes} menit',
              ),
            ),
        ],
      );
    },
  );
}
