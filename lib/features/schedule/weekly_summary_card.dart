import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../app/theme.dart';
import '../../planner/schedule.dart';
import '../../planner/weekly_summary.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

/// Ringkasan ringan "Minggu ini" (Senin–Minggu, WIB) dari sesi tersimpan.
class WeeklySummaryCard extends StatelessWidget {
  final PlannerController planner;
  const WeeklySummaryCard({super.key, required this.planner});

  String _rangeLabel(WeeklySummary s) {
    final fmt = DateFormat('d MMM', 'id_ID');
    final a = tz.TZDateTime.from(s.weekStart, jakarta);
    final b = tz.TZDateTime.from(s.lastDayInclusive, jakarta);
    return 'Sen ${fmt.format(a)} – Min ${fmt.format(b)} ${b.year} (WIB)';
  }

  String _duration(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return '$m menit';
    if (m == 0) return '$h jam';
    return '$h jam $m menit';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final summary = buildWeeklySummary(planner.snapshot, planner.now);
    final text = Theme.of(context).textTheme;

    Widget stat(String label, String value, Key key) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            key: key,
            style: text.titleLarge?.copyWith(color: colors.ink),
          ),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: colors.inkSecondary),
          ),
        ],
      ),
    );

    return PaperCard(
      key: const Key('weekly-summary'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Minggu ini', subtitle: _rangeLabel(summary)),
          if (planner.isOfflineSnapshot) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                planner.fetchedAt == null
                    ? 'Dari cache luring'
                    : 'Dari cache luring · ${dateTimeLabel(planner.fetchedAt!)}',
                tone: StatusTone.warning,
                icon: 'imgAlertCircle',
              ),
            ),
            const SizedBox(height: AppLayout.space8),
          ],
          if (summary.isEmpty)
            Text(
              'Belum ada sesi minggu ini. Konfirmasi jadwal untuk mulai melihat ringkasan.',
              key: const Key('weekly-summary-empty'),
              style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
            )
          else ...[
            Text(
              _duration(summary.scheduledMinutes),
              key: const Key('weekly-scheduled-minutes'),
              style: text.headlineSmall?.copyWith(color: colors.ink),
            ),
            Text(
              'durasi sesi terjadwal',
              style: text.bodySmall?.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: AppLayout.space12),
            Row(
              children: [
                stat(
                  'Selesai',
                  '${summary.completedCount}',
                  const Key('weekly-completed'),
                ),
                stat(
                  'Terlewat',
                  '${summary.missedCount}',
                  const Key('weekly-missed'),
                ),
                stat(
                  'Belum dicatat',
                  '${summary.plannedCount}',
                  const Key('weekly-planned'),
                ),
              ],
            ),
            if (summary.cancelledCount > 0) ...[
              const SizedBox(height: AppLayout.space8),
              Text(
                '${summary.cancelledCount} sesi dibatalkan karena rencana diganti (tidak dihitung sebagai terlewat atau durasi).',
                key: const Key('weekly-cancelled'),
                style: text.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
            if (summary.measuredFocusMinutes != null) ...[
              const SizedBox(height: AppLayout.space8),
              Text(
                'Fokus terukur · ${_duration(summary.measuredFocusMinutes!)}',
                style: text.bodyMedium?.copyWith(color: colors.ink),
              ),
            ],
          ],
          const SizedBox(height: AppLayout.space12),
          Text(
            'Sumber: sesi tersimpan yang berada di rentang ini. Durasi memakai jam rencana sesi (rencana, selesai, terlewat); sesi yang melewati batas minggu hanya dihitung bagiannya di minggu ini. Menit fokus aktual tidak ditampilkan karena timer belum menyimpannya ke sesi.',
            key: const Key('weekly-source-note'),
            style: text.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}
