import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../app/theme.dart';
import '../../planner/capacity_simulation.dart';
import '../../planner/models.dart';
import '../../planner/schedule.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';
import 'try_prioritize_task_screen.dart';

class TryAddTimeScreen extends StatefulWidget {
  final PlannerController planner;
  final Task task;
  final int unallocatedMinutes;
  final DateTime? initialDate;
  final int? initialStartMinute;
  final int? initialEndMinute;

  const TryAddTimeScreen({
    super.key,
    required this.planner,
    required this.task,
    required this.unallocatedMinutes,
    this.initialDate,
    this.initialStartMinute,
    this.initialEndMinute,
  });

  @override
  State<TryAddTimeScreen> createState() => _TryAddTimeScreenState();
}

class _TryAddTimeScreenState extends State<TryAddTimeScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController startController;
  late final TextEditingController endController;

  late DateTime selectedDate;
  late int baselineRevision;
  CapacitySimulationResult? simulationResult;
  String? localError;
  bool isSaving = false;
  bool saveSucceededButPreviewFailed = false;

  @override
  void initState() {
    super.initState();
    baselineRevision = widget.planner.snapshot.revision;

    // Tentukan tanggal awal: dari saran jika ada, atau hari ini dalam zona waktu Jakarta
    final todayJakarta = tz.TZDateTime.from(widget.planner.now, jakarta);
    selectedDate = widget.initialDate ??
        DateTime(todayJakarta.year, todayJakarta.month, todayJakarta.day);

    // Tentukan jam mulai & selesai awal
    final defaultStart = widget.initialStartMinute ?? 1140; // 19:00
    final defaultDuration = math.min(widget.unallocatedMinutes, 180);
    final defaultEnd =
        widget.initialEndMinute ?? math.min(defaultStart + defaultDuration, 1440);

    startController = TextEditingController(text: timeLabel(defaultStart));
    endController = TextEditingController(text: timeLabel(defaultEnd));

    _recalculateSimulation();
  }

  @override
  void dispose() {
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  int? _parseTime(String text, {bool allowEnd = false}) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) return null;
    final parts = text.split(':').map(int.parse).toList();
    if (allowEnd && parts[0] == 24 && parts[1] == 0) return 1440;
    if (parts[0] > 23 || parts[1] > 59) return null;
    return parts[0] * 60 + parts[1];
  }

  String get _dateString =>
      '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

  void _recalculateSimulation() {
    final startMin = _parseTime(startController.text);
    final endMin = _parseTime(endController.text, allowEnd: true);

    if (startMin == null || endMin == null || startMin >= endMin) {
      setState(() => simulationResult = null);
      return;
    }

    try {
      final candidateWindow = TimeWindow(
        id: 'candidate-sim-${baselineRevision + 1}',
        date: _dateString,
        startMinute: startMin,
        endMinute: endMin,
      );

      const simulator = CapacitySimulator();
      final res = simulator.simulate(
        snapshot: widget.planner.snapshot,
        now: widget.planner.now,
        targetTask: widget.task,
        candidateWindow: candidateWindow,
        baselinePreview: widget.planner.preview,
      );

      setState(() {
        simulationResult = res;
        localError = null;
      });
    } catch (_) {
      setState(() => simulationResult = null);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showAppDialog<DateTime>(
      context,
      (_) => DatePickerDialog(
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      ),
    );
    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
      _recalculateSimulation();
    }
  }

  Future<void> _pickTime(TextEditingController controller, {bool allowEnd = false}) async {
    final current = _parseTime(controller.text, allowEnd: allowEnd) ?? 1140;
    final picked = await showAppDialog<TimeOfDay>(
      context,
      (_) => TimePickerDialog(
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      ),
    );
    if (picked != null && mounted) {
      setState(() => controller.text = timeLabel(picked.hour * 60 + picked.minute));
      _recalculateSimulation();
    }
  }

  Future<void> _handleSave() async {
    // 1. Cek mode luring
    if (widget.planner.isOfflineSnapshot) {
      setState(() {
        localError = 'Mode luring hanya baca. Tidak dapat menyimpan slot baru.';
      });
      return;
    }

    // 2. Cek revisi basi (stale revision)
    if (widget.planner.snapshot.revision != baselineRevision) {
      setState(() {
        localError =
            'Data jadwal telah diperbarui di tempat lain. Silakan tinjau kembali hasil terbaru.';
      });
      return;
    }

    if (!formKey.currentState!.validate()) return;

    final startMin = _parseTime(startController.text)!;
    final endMin = _parseTime(endController.text, allowEnd: true)!;

    setState(() {
      isSaving = true;
      localError = null;
    });

    final newId = 'window-${baselineRevision + 1}-$_dateString';
    final newWindow = TimeWindow(
      id: newId,
      date: _dateString,
      startMinute: startMin,
      endMinute: endMin,
    );

    final ok = await widget.planner.saveWindow(
      newWindow,
      expectedRevision: baselineRevision,
    );

    if (!ok) {
      if (mounted) {
        setState(() {
          isSaving = false;
          localError = widget.planner.error ?? 'Gagal menyimpan slot waktu.';
        });
      }
      return;
    }

    // Slot berhasil disimpan! Buat pratinjau terbaru
    final previewOk = await widget.planner.generatePreview();
    if (!mounted) return;

    if (previewOk) {
      // Pop dialogs dan arahkan ke pratinjau terbaru untuk konfirmasi
      final router = GoRouter.of(context);
      final nav = Navigator.of(context);
      while (nav.canPop()) {
        nav.pop();
      }
      router.go('/schedule/preview');
    } else {
      // Slot tersimpan tapi pratinjau gagal
      setState(() {
        isSaving = false;
        saveSucceededButPreviewFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLocked = isSaving || widget.planner.isPending || saveSucceededButPreviewFailed;

    return PopScope(
      canPop: !isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Coba tambah waktu')),
        body: Form(
          key: formKey,
          child: PageContent(
            actions: saveSucceededButPreviewFailed
                ? AppButton(
                    label: 'Buka Jadwal',
                    icon: 'imgCheck',
                    onPressed: () {
                      final router = GoRouter.of(context);
                      final nav = Navigator.of(context);
                      while (nav.canPop()) {
                        nav.pop();
                      }
                      router.go('/schedule');
                    },
                  )
                : FormActions(
                    label: isSaving ? 'Menyimpan…' : 'Simpan slot',
                    onSave: isLocked ? null : _handleSave,
                    onCancel: isSaving ? null : () => Navigator.pop(context),
                  ),
            children: [
              PageHeading(
                'Coba tambah waktu\n${widget.task.title}',
                'Simulasikan dampak penambahan slot belajar sebelum menyimpannya ke jadwal.',
              ),
              const SizedBox(height: AppLayout.space16),

              if (localError != null) ...[
                Notice(
                  title: 'Perhatian',
                  message: localError!,
                  color: colors.dangerBg,
                ),
                const SizedBox(height: AppLayout.space16),
              ],

              if (saveSucceededButPreviewFailed) ...[
                Notice(
                  title: 'Slot belajar tersimpan',
                  message:
                      'Slot belajar berhasil disimpan ke data Anda. Namun pembuatan pratinjau jadwal otomatis belum berhasil diproses (${widget.planner.error ?? 'Kalkulasi pratinjau tertunda'}). Anda dapat membuka layar Jadwal lalu mengetuk tombol Hitung Ulang kapan saja.',
                  color: colors.warningBg,
                ),
                const SizedBox(height: AppLayout.space16),
              ],

              // Kartu Form Pemilihan Waktu
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Pilih slot belajar',
                      subtitle: 'Tentukan tanggal dan rentang jam pengerjaan.',
                    ),
                    const SizedBox(height: AppLayout.space12),

                    // Pemilihan Tanggal
                    InkWell(
                      onTap: isLocked ? null : _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal belajar',
                          suffixIcon: DesignIcon('imgCalendar', size: 20),
                        ),
                        child: Text(
                          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.space12),

                    // Pemilihan Jam Mulai dan Jam Selesai
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isLocked ? null : () => _pickTime(startController),
                            borderRadius: BorderRadius.circular(10),
                            child: TextFormField(
                              controller: startController,
                              enabled: !isLocked,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Jam mulai',
                                hintText: '19:00',
                                suffixIcon: DesignIcon('imgClock', size: 18),
                              ),
                              validator: (val) {
                                final parsed = _parseTime(val ?? '');
                                if (parsed == null) return 'Format HH:mm';
                                return null;
                              },
                              onChanged: (_) => _recalculateSimulation(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppLayout.space12),
                        Expanded(
                          child: InkWell(
                            onTap: isLocked ? null : () => _pickTime(endController, allowEnd: true),
                            borderRadius: BorderRadius.circular(10),
                            child: TextFormField(
                              controller: endController,
                              enabled: !isLocked,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Jam selesai',
                                hintText: '21:00',
                                suffixIcon: DesignIcon('imgClock', size: 18),
                              ),
                              validator: (val) {
                                final parsedEnd = _parseTime(val ?? '', allowEnd: true);
                                final parsedStart = _parseTime(startController.text);
                                if (parsedEnd == null) return 'Format HH:mm';
                                if (parsedStart != null && parsedEnd <= parsedStart) {
                                  return 'Harus setelah mulai';
                                }
                                return null;
                              },
                              onChanged: (_) => _recalculateSimulation(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppLayout.space16),

              // Kartu Hasil Simulasi Dampak
              if (simulationResult != null) ...[
                Builder(
                  builder: (_) {
                    final res = simulationResult!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Kartu Ringkasan Kekurangan
                        PaperCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SectionHeader(
                                title: 'Hasil simulasi',
                                subtitle: 'Kalkulasi jadwal ulang pada salinan data.',
                              ),
                              const SizedBox(height: AppLayout.space12),

                              // Metrik Sebelum dan Sesudah
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetricTile(
                                      label: 'Sebelum simulasi',
                                      value: 'Kurang ${res.beforeUnallocatedMinutes} mnt',
                                      color: colors.warningInk,
                                      bgColor: colors.warningBg,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const DesignIcon('imgArrowRight', size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _MetricTile(
                                      label: 'Sesudah slot ditambah',
                                      value: res.afterUnallocatedMinutes == 0
                                          ? 'Kekurangan 0 mnt'
                                          : 'Kurang ${res.afterUnallocatedMinutes} mnt',
                                      color: res.afterUnallocatedMinutes == 0
                                          ? colors.onPrimarySoft
                                          : colors.warningInk,
                                      bgColor: res.afterUnallocatedMinutes == 0
                                          ? colors.primarySoft
                                          : colors.warningBg,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppLayout.space12),

                              // Penjelasan Dampak pada Tugas Target
                              if (res.isFullyResolved)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      DesignIcon('imgCheck', size: 18, color: colors.onPrimarySoft),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Kekurangan kapasitas terpenuhi sepenuhnya! Seluruh sisa pekerjaan tugas dapat dijadwalkan sebelum tenggat.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colors.onPrimarySoft,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (res.isPartiallyResolved)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.warningBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.warningInk),
                                  ),
                                  child: Row(
                                    children: [
                                      DesignIcon('imgAlertCircle', size: 18, color: colors.warningInk),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Slot ini menambah waktu belajar (berkurang ${res.shortfallReduction} mnt), tetapi tugas masih kekurangan ${res.afterUnallocatedMinutes} menit sebelum tenggat.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (res.isPastDeadline)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.dangerBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.dangerInk),
                                  ),
                                  child: Row(
                                    children: [
                                      DesignIcon('imgAlertCircle', size: 18, color: colors.dangerInk),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Slot berada setelah tenggat tugas (${dateTimeLabel(widget.task.deadlineAt)}). Tidak dapat dipakai untuk tugas ini.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Slot ini belum mengurangi kekurangan kapasitas tugas.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.inkSecondary,
                                    ),
                                  ),
                                ),

                              // Peringatan Tabrakan Waktu / Penutupan
                              if (res.isCollidingWithBusy) ...[
                                const SizedBox(height: AppLayout.space12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colors.warningBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.warningInk),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: DesignIcon('imgAlertCircle', size: 18, color: colors.warningInk),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Slot ini (${res.candidateDurationMinutes} menit) bertabrakan dengan kegiatan atau penutupan lain sebesar ${res.collidingMinutes} menit. Hanya ${res.effectiveCapacityAddedMinutes} menit yang efektif digunakan.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: colors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: AppLayout.space16),

                        // Kartu Dampak pada Tugas Lain
                        PaperCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SectionHeader(
                                title: 'Dampak pada tugas lain',
                                subtitle: 'Perubahan alokasi sesi akibat prioritas tenggat.',
                              ),
                              const SizedBox(height: AppLayout.space12),

                              if (res.otherTasksImpact.isEmpty)
                                Text(
                                  'Tidak ada perubahan pada alokasi tugas lain.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colors.inkSecondary,
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (final impact in res.otherTasksImpact)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                impact.task.title,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: colors.ink,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (impact.minuteDelta > 0)
                                              Text(
                                                '+${impact.minuteDelta} mnt',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: colors.onPrimarySoft,
                                                ),
                                              )
                                            else if (impact.minuteDelta < 0)
                                              Text(
                                                '${impact.minuteDelta} mnt',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: colors.dangerInk,
                                                ),
                                              )
                                            else
                                              Text(
                                                'Sesi bergeser',
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
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: AppLayout.space16),
              AppButton(
                label: 'Coba prioritaskan tugas ini',
                icon: 'imgAlertCircle',
                secondary: true,
                onPressed: isSaving
                    ? null
                    : () {
                        final currentTask =
                            widget.planner.taskById(widget.task.id) ??
                            widget.task;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TryPrioritizeTaskScreen(
                              planner: widget.planner,
                              task: currentTask,
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _MetricTile({
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
