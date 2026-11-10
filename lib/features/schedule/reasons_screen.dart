import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../planner/models.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class ReasonsScreen extends StatelessWidget {
  final PlannerController planner;
  const ReasonsScreen({super.key, required this.planner});

  @override
  Widget build(BuildContext context) => Scaffold(
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
        const SizedBox(height: 16),
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
                    StatusBadge(reason.label, icon: 'imgInfo'),
                    const SizedBox(height: 12),
                    for (final item in items)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warningBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: DesignIcon(
                                'imgAlertCircle',
                                size: 16,
                                color: AppColors.warningInk,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${planner.taskById(item.taskId)?.title ?? item.taskId} · kurang ${item.minutes} menit',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      switch (reason) {
                        UnallocatedReason.pastDeadline =>
                          'Tenggat sudah berlalu pada awal perencanaan. Tidak dibuat sesi melewati tenggat.',
                        UnallocatedReason.insufficientCapacity =>
                          'Waktu bersih sebelum tenggat belum cukup untuk seluruh sisa pekerjaan. Tambahkan izin waktu atau tinjau tugas.',
                        UnallocatedReason.outsideHorizon =>
                          'Belum mendapat alokasi di jendela 14 tanggal. Tinjau lagi pada jendela berikutnya.',
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const Text(
          'Aplikasi tidak otomatis menambah waktu atau mengubah tenggat Anda.',
          style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ],
    ),
  );
}
