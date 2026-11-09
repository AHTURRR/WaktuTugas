import 'package:flutter/material.dart';
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
        for (final reason in UnallocatedReason.values)
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(reason.label, icon: 'imgInfo'),
                const SizedBox(height: 12),
                for (final item
                    in planner.preview?.unallocated.where(
                          (u) => u.reason == reason,
                        ) ??
                        <Unallocated>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${planner.taskById(item.taskId)?.title ?? item.taskId} · kurang ${item.minutes} menit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                Text(switch (reason) {
                  UnallocatedReason.pastDeadline =>
                    'Tenggat sudah berlalu pada awal perencanaan. Tidak dibuat sesi melewati tenggat.',
                  UnallocatedReason.insufficientCapacity =>
                    'Waktu bersih sebelum tenggat belum cukup untuk seluruh sisa pekerjaan. Tambahkan izin waktu atau tinjau tugas.',
                  UnallocatedReason.outsideHorizon =>
                    'Belum mendapat alokasi di jendela 14 tanggal. Tinjau lagi pada jendela berikutnya.',
                }),
              ],
            ),
          ),
        const Text(
          'Aplikasi tidak otomatis menambah waktu atau mengubah tenggat Anda.',
        ),
      ],
    ),
  );
}
