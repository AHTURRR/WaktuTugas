import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../planner/models.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';
import 'suggest_time_screen.dart';
import 'try_add_time_screen.dart';
import 'try_prioritize_task_screen.dart';

class ReasonsScreen extends StatelessWidget {
  final PlannerController planner;
  const ReasonsScreen({super.key, required this.planner});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pratinjau jadwal')),
      body: PageContent(
        actions: AppButton(
          label: 'Kembali ke pratinjau',
          secondary: true,
          onPressed: () => Navigator.pop(context),
        ),
        children: [
          const PageHeading(
            'Mengapa masih kurang?',
            'Kekurangan tidak selalu berarti tugas mustahil diselesaikan.',
          ),
          const SizedBox(height: AppLayout.space16),
          for (final reason in UnallocatedReason.values)
            Builder(
              builder: (_) {
                final items =
                    planner.preview?.unallocated
                        .where((u) => u.reason == reason)
                        .toList() ??
                    const <Unallocated>[];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(
                        reason.label,
                        tone: reason == UnallocatedReason.pastDeadline
                            ? StatusTone.danger
                            : StatusTone.warning,
                      ),
                      const SizedBox(height: AppLayout.space12),
                      for (final item in items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.warningBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.warningInk),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: DesignIcon(
                                      'imgAlertCircle',
                                      size: 16,
                                      color: colors.warningInk,
                                    ),
                                  ),
                                  const SizedBox(width: AppLayout.space8),
                                  Expanded(
                                    child: Text(
                                      '${planner.taskById(item.taskId)?.title ?? item.taskId} · kurang ${item.minutes} menit',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colors.ink,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (reason ==
                                      UnallocatedReason.insufficientCapacity &&
                                  planner.taskById(item.taskId) != null) ...[
                                const SizedBox(height: AppLayout.space8),
                                Wrap(
                                  spacing: AppLayout.space8,
                                  runSpacing: AppLayout.space8,
                                  children: [
                                    AppButton(
                                      label: 'Cari saran waktu',
                                      icon: 'imgCalendar',
                                      onPressed: () {
                                        final task = planner.taskById(
                                          item.taskId,
                                        )!;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SuggestTimeScreen(
                                              planner: planner,
                                              task: task,
                                              unallocatedMinutes: item.minutes,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    AppButton(
                                      label: 'Coba tambah waktu',
                                      icon: 'imgPlus',
                                      secondary: true,
                                      onPressed: () {
                                        final task = planner.taskById(
                                          item.taskId,
                                        )!;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TryAddTimeScreen(
                                              planner: planner,
                                              task: task,
                                              unallocatedMinutes: item.minutes,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    AppButton(
                                      label: 'Coba prioritaskan tugas ini',
                                      icon: 'imgAlertCircle',
                                      secondary: true,
                                      onPressed: () {
                                        final task = planner.taskById(item.taskId)!;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TryPrioritizeTaskScreen(
                                              planner: planner,
                                              task: task,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      Text(switch (reason) {
                        UnallocatedReason.pastDeadline =>
                          'Tenggat sudah berlalu pada awal perencanaan. Tidak dibuat sesi melewati tenggat.',
                        UnallocatedReason.insufficientCapacity =>
                          'Waktu bersih sebelum tenggat belum cukup untuk seluruh sisa pekerjaan. Tambahkan izin waktu atau tinjau tugas.',
                        UnallocatedReason.outsideHorizon =>
                          'Belum mendapat alokasi di jendela 14 tanggal. Tinjau lagi pada jendela berikutnya.',
                      }, style: TextStyle(fontSize: 13, color: colors.inkSecondary)),
                    ],
                  ),
                );
              },
            ),
          Text(
            'Aplikasi tidak otomatis menambah waktu atau mengubah tenggat Anda.',
            style: TextStyle(fontSize: 12, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}
