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
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        final available = expandWindows(planner.snapshot, planner.now);
        final locked = planner.isPending || planner.isOfflineSnapshot;
        final totalMinutes = available.fold(0, (int n, w) => n + w.minutes);

        Widget row(TimeWindow w, bool activity, {required bool isLast}) {
          final durationMinutes = w.endMinute - w.startMinute;
          final isBlocked = w is Activity && w.kind == ActivityKind.blocked;
          final isWeekly = w.weekday != null;
          final tone = activity
              ? (isBlocked ? StatusTone.danger : StatusTone.warning)
              : (isWeekly ? StatusTone.info : StatusTone.success);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: KeyboardFocusOutline(
                            child: InkWell(
                              hoverDuration: AppMotion.durationOf(context),
                              onTap: locked
                                  ? null
                                  : () => edit(
                                      context,
                                      window: w,
                                      activity: activity,
                                    ),
                              borderRadius: BorderRadius.circular(
                                AppLayout.radius,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: AppLayout.control,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.ink,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppLayout.space8),
                        const SizedBox(width: AppLayout.space8),
                        StatusBadge(
                          '$durationMinutes mnt',
                          tone: tone,
                          icon: 'imgClock',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.space4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DesignIcon(
                          'imgClock',
                          size: 15,
                          color: colors.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            windowLabel(w),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colors.inkSecondary,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ubah ${w.id}',
                          visualDensity: VisualDensity.standard,
                          icon: DesignIcon(
                            'imgEdit',
                            size: 18,
                            color: colors.inkSecondary,
                          ),
                          onPressed: locked
                              ? null
                              : () => edit(
                                  context,
                                  window: w,
                                  activity: activity,
                                ),
                        ),
                        IconButton(
                          tooltip: 'Hapus ${w.id}',
                          visualDensity: VisualDensity.standard,
                          icon: DesignIcon(
                            'imgTrash',
                            size: 18,
                            color: colors.dangerInk,
                          ),
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
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }

        return PageContent(
          children: [
            FocusPanel(
              eyebrow: 'WAKTU ANDA',
              title: '$totalMinutes menit',
              description:
                  'Ruang bersih untuk mengerjakan tugas dalam 14 tanggal kalender.',
              icon: 'imgClock1',
              footer: Text(
                'Izin kerja \u2212 kegiatan \u2212 penutupan',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppLayout.space16),
            const SectionHeader(
              title: 'Waktu yang diizinkan',
              subtitle:
                  'Pola mingguan dan tanggal khusus tempat jadwal boleh ditempatkan.',
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Tambah rentang',
              icon: 'imgPlus',
              onPressed: locked ? null : () => edit(context),
            ),
            const SizedBox(height: AppLayout.space12),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (planner.snapshot.timeWindows.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Belum ada rentang. Waktu kosong tidak otomatis menjadi waktu pengerjaan.',
                        style: TextStyle(color: colors.inkSecondary),
                      ),
                    ),
                  for (var i = 0; i < planner.snapshot.timeWindows.length; i++)
                    row(
                      planner.snapshot.timeWindows[i],
                      false,
                      isLast: i == planner.snapshot.timeWindows.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppLayout.space8),
            const SectionHeader(
              title: 'Aktivitas & penutupan',
              subtitle:
                  'Kegiatan rutin, agenda sekali, dan penutupan yang memotong waktu kerja.',
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Tambah kegiatan',
              secondary: true,
              icon: 'imgPlus',
              onPressed: locked ? null : () => edit(context, activity: true),
            ),
            const SizedBox(height: AppLayout.space12),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (planner.snapshot.activities.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Tidak ada kegiatan atau penutupan.',
                        style: TextStyle(color: colors.inkSecondary),
                      ),
                    ),
                  for (var i = 0; i < planner.snapshot.activities.length; i++)
                    row(
                      planner.snapshot.activities[i],
                      true,
                      isLast: i == planner.snapshot.activities.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppLayout.space8),
            const SectionHeader(
              title: 'Waktu bersih',
              subtitle: 'Kapasitas efektif selama jendela perencanaan 14 hari.',
            ),
            const SizedBox(height: 10),
            PaperCard(
              color: colors.surface,
              borderColor: colors.border,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: DesignIcon(
                            'imgClock1',
                            size: 20,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: AppLayout.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalMinutes menit',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: colors.onPrimarySoft),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dateTimeLabel(ceilMinute(planner.now))} – ${dateTimeLabel(horizonEnd(planner.now))}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppLayout.space12),
                  for (final w in available)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: DesignIcon(
                              'imgCheckCircle',
                              size: 14,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: AppLayout.space8),
                          Expanded(
                            child: Text(
                              '${dateLabel(w.start)} · ${clockLabel(w.start)}–${clockLabel(w.end)} (${w.minutes} menit)',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  Text(
                    'Izin digabung sekali, lalu dikurangi aktivitas dan penutupan. Waktu kosong bukan izin.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.inkSecondary,
                    ),
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
}
