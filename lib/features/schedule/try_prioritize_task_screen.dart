import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../planner/models.dart';
import '../../planner/priority_simulation.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class TryPrioritizeTaskScreen extends StatefulWidget {
  final PlannerController planner;
  final Task task;

  const TryPrioritizeTaskScreen({
    super.key,
    required this.planner,
    required this.task,
  });

  @override
  State<TryPrioritizeTaskScreen> createState() =>
      _TryPrioritizeTaskScreenState();
}

class _TryPrioritizeTaskScreenState extends State<TryPrioritizeTaskScreen> {
  late int baselineRevision;
  bool revisionChangedNotice = false;
  PrioritySimulationResult? result;
  String? localError;

  @override
  void initState() {
    super.initState();
    baselineRevision = widget.planner.snapshot.revision;
    widget.planner.addListener(_onPlannerChanged);
    _runSimulation();
  }

  @override
  void dispose() {
    widget.planner.removeListener(_onPlannerChanged);
    super.dispose();
  }

  void _onPlannerChanged() {
    if (!mounted) return;
    if (widget.planner.snapshot.revision != baselineRevision) {
      baselineRevision = widget.planner.snapshot.revision;
      revisionChangedNotice = true;
      _runSimulation();
    }
  }

  void _runSimulation() {
    final currentTask = widget.planner.taskById(widget.task.id) ?? widget.task;
    final baselinePreview =
        widget.planner.preview?.inputRevision == widget.planner.snapshot.revision
        ? widget.planner.preview
        : null;

    try {
      const simulator = PrioritySimulator();
      final simResult = simulator.simulate(
        snapshot: widget.planner.snapshot,
        now: widget.planner.now,
        targetTask: currentTask,
        baselinePreview: baselinePreview,
      );
      setState(() {
        result = simResult;
        localError = null;
      });
    } on StateError catch (error) {
      setState(() {
        result = null;
        localError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentTask = widget.planner.taskById(widget.task.id) ?? widget.task;
    final sim = result;

    return Scaffold(
      appBar: AppBar(title: const Text('Coba prioritaskan tugas ini')),
      body: PageContent(
        actions: AppButton(
          label: 'Batal',
          secondary: true,
          onPressed: () => Navigator.pop(context),
        ),
        children: [
          PageHeading(
            'Coba prioritaskan\n${currentTask.title}',
            'Bandingkan jadwal biasa dengan skenario prioritas sementara. Jadwal kuliah, blok waktu, dan tenggat setiap tugas tetap dipertahankan.',
          ),
          const SizedBox(height: AppLayout.space16),
          if (revisionChangedNotice) ...[
            Notice(
              title: 'Data berubah selama simulasi',
              message:
                  'Data jadwal berubah saat simulasi terbuka. Perbandingan telah dihitung ulang menggunakan data dan revisi terbaru.',
              color: colors.warningBg,
            ),
            const SizedBox(height: AppLayout.space16),
          ],
          if (localError != null) ...[
            Notice(
              title: 'Simulasi tidak dapat dijalankan',
              message: localError!,
              color: colors.dangerBg,
            ),
            const SizedBox(height: AppLayout.space16),
          ],
          if (sim != null) ...[
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: SectionHeader(
                          title: 'Perbandingan tugas pilihan',
                          subtitle:
                              'Menggunakan data, batas waktu 14 hari, dan waktu acuan yang sama.',
                        ),
                      ),
                      const SizedBox(width: AppLayout.space8),
                      StatusBadge(
                        sim.hasImprovement
                            ? '+${sim.gainedMinutes} menit diperoleh'
                            : 'Tidak ada perbaikan',
                        tone: sim.hasImprovement
                            ? (sim.isFullyResolved
                                  ? StatusTone.success
                                  : StatusTone.info)
                            : StatusTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.space12),
                  Row(
                    children: [
                      Expanded(
                        child: _PriorityMetricTile(
                          label: 'Jadwal biasa',
                          value: '${sim.beforeAllocatedMinutes} menit',
                          color: colors.ink,
                          bgColor: colors.surfaceMuted,
                        ),
                      ),
                      const SizedBox(width: AppLayout.space8),
                      Expanded(
                        child: _PriorityMetricTile(
                          label: 'Prioritas sementara',
                          value: '${sim.afterAllocatedMinutes} menit',
                          color: sim.hasImprovement
                              ? colors.successInk
                              : colors.warningInk,
                          bgColor: sim.hasImprovement
                              ? colors.primarySoft
                              : colors.warningBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.space8),
                  Row(
                    children: [
                      Expanded(
                        child: _PriorityMetricTile(
                          label: 'Diperoleh',
                          value: '+${sim.gainedMinutes} menit',
                          color: sim.hasImprovement
                              ? colors.successInk
                              : colors.inkSecondary,
                          bgColor: colors.surfaceMuted,
                        ),
                      ),
                      const SizedBox(width: AppLayout.space8),
                      Expanded(
                        child: _PriorityMetricTile(
                          label: 'Sisa kekurangan',
                          value:
                              '${sim.beforeUnallocatedMinutes} → ${sim.afterUnallocatedMinutes} menit',
                          color: sim.afterUnallocatedMinutes == 0
                              ? colors.successInk
                              : colors.warningInk,
                          bgColor: colors.surfaceMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.space12),
                  Notice(
                    title: sim.hasImprovement
                        ? 'Prioritas sementara menambah ${sim.gainedMinutes} menit'
                        : 'Tidak ada perbaikan alokasi',
                    message: sim.hasImprovement
                        ? (sim.isFullyResolved
                              ? 'Tugas ini mendapatkan seluruh waktu yang dibutuhkan sebelum tenggat, namun memeriksa dampak ke tugas lain di bawah tetap disarankan.'
                              : 'Alokasi bertambah ${sim.gainedMinutes} menit, tetapi masih kurang ${sim.afterUnallocatedMinutes} menit karena keterbatasan slot sebelum tenggat.')
                        : 'Memprioritaskan tugas ini menghasilkan +0 menit tambahan. Jadwal kuliah, blok waktu belajar, atau tenggat tugas tidak menyisakan kapasitas tambahan yang bisa dialihkan.',
                    color: sim.hasImprovement
                        ? colors.infoBg
                        : colors.warningBg,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppLayout.space16),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    title: 'Dampak pada tugas lain',
                    subtitle:
                        'Menit yang hilang atau jadwal sesi yang bergeser pada tugas lain.',
                  ),
                  const SizedBox(height: AppLayout.space12),
                  if (sim.otherTasksImpact.isEmpty)
                    Text(
                      'Tidak ada tugas lain yang kehilangan menit atau bergeser jadwalnya.',
                      style: TextStyle(fontSize: 13, color: colors.inkMuted),
                    )
                  else
                    Column(
                      children: [
                        for (final impact in sim.otherTasksImpact)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: impact.minuteDelta < 0
                                  ? colors.dangerBg
                                  : colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        impact.task.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: colors.ink,
                                        ),
                                      ),
                                      Text(
                                        'Biasa: ${impact.beforeMinutes} mnt → Prioritas: ${impact.afterMinutes} mnt',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.inkSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppLayout.space8),
                                if (impact.minuteDelta < 0)
                                  Text(
                                    'Hilang ${-impact.minuteDelta} menit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.dangerInk,
                                    ),
                                  )
                                else if (impact.minuteDelta > 0)
                                  Text(
                                    '+${impact.minuteDelta} menit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.successInk,
                                    ),
                                  )
                                else
                                  Text(
                                    'Jadwal bergeser',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.inkSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppLayout.space16),
            Notice(
              title: 'Mode perbandingan saja',
              message:
                  'Versi ini hanya menampilkan perbandingan sementara yang dapat dibatalkan. Menutup layar ini menjaga preferensi tugas dan jadwal tersimpan tetap sama.',
              color: colors.surfaceMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _PriorityMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _PriorityMetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
