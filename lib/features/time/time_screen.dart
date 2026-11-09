import 'package:flutter/material.dart';
import '../../app/theme.dart';
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
      final locked = planner.isPending || planner.isOfflineSnapshot;
      Widget row(TimeWindow w, bool activity) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: locked
                  ? null
                  : () => edit(context, window: w, activity: activity),
              child: Text(
                w is Activity
                    ? '${w.kind == ActivityKind.blocked
                          ? 'Penutupan'
                          : w.kind == ActivityKind.routine
                          ? 'Rutin'
                          : 'Kegiatan sekali'}: ${w.label}'
                    : w.weekday == null
                    ? 'Rentang tambahan'
                    : 'Rentang mingguan',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    windowLabel(w),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Ubah ${w.id}',
                  icon: const DesignIcon('imgEdit', size: 20),
                  onPressed: locked
                      ? null
                      : () => edit(context, window: w, activity: activity),
                ),
                IconButton(
                  tooltip: 'Hapus ${w.id}',
                  icon: const DesignIcon('imgTrash', size: 20),
                  onPressed: locked
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
              ],
            ),
          ],
        ),
      );
      return PageContent(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Waktu yang diizinkan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Tambah rentang',
            icon: 'imgPlus',
            onPressed: locked ? null : () => edit(context),
          ),
          const SizedBox(height: 12),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (planner.snapshot.timeWindows.isEmpty)
                  const Text(
                    'Belum ada rentang. Waktu kosong tidak otomatis menjadi waktu pengerjaan.',
                  ),
                for (final w in planner.snapshot.timeWindows) row(w, false),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aktivitas & penutupan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Tambah kegiatan',
            secondary: true,
            icon: 'imgPlus',
            onPressed: locked ? null : () => edit(context, activity: true),
          ),
          const SizedBox(height: 12),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (planner.snapshot.activities.isEmpty)
                  const Text('Tidak ada kegiatan atau penutupan.'),
                for (final w in planner.snapshot.activities) row(w, true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Waktu bersih', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          PaperCard(
            color: AppColors.lilac,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${available.fold(0, (int n, w) => n + w.minutes)} menit',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${dateTimeLabel(ceilMinute(planner.now))} – ${dateTimeLabel(horizonEnd(planner.now))}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (final w in available)
                  Text(
                    '${dateLabel(w.start)} · ${clockLabel(w.start)}–${clockLabel(w.end)} (${w.minutes})',
                    style: const TextStyle(fontSize: 13),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Izin digabung sekali, lalu dikurangi aktivitas dan penutupan. Waktu kosong bukan izin.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ErrorNotice(planner.error),
        ],
      );
    },
  );
}
