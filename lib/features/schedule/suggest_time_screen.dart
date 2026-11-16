import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../planner/models.dart';
import '../../planner/time_suggestions.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';
import 'try_add_time_screen.dart';

class SuggestTimeScreen extends StatefulWidget {
  final PlannerController planner;
  final Task task;
  final int unallocatedMinutes;

  const SuggestTimeScreen({
    super.key,
    required this.planner,
    required this.task,
    required this.unallocatedMinutes,
  });

  @override
  State<SuggestTimeScreen> createState() => _SuggestTimeScreenState();
}

class _SuggestTimeScreenState extends State<SuggestTimeScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController startController;
  late final TextEditingController endController;

  late int baselineRevision;
  bool revisionChangedNotice = false;
  TimeSuggestionSearchResult? searchResult;

  @override
  void initState() {
    super.initState();
    baselineRevision = widget.planner.snapshot.revision;
    startController = TextEditingController(text: '19:00');
    endController = TextEditingController(text: '22:00');
    widget.planner.addListener(_onPlannerChanged);
    _runSearch();
  }

  @override
  void dispose() {
    widget.planner.removeListener(_onPlannerChanged);
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  void _onPlannerChanged() {
    if (!mounted) return;
    if (widget.planner.snapshot.revision != baselineRevision) {
      baselineRevision = widget.planner.snapshot.revision;
      revisionChangedNotice = true;
      _runSearch();
    }
  }

  int? _parseTime(String text, {bool allowEnd = false}) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) return null;
    final parts = text.split(':').map(int.parse).toList();
    if (allowEnd && parts[0] == 24 && parts[1] == 0) return 1440;
    if (parts[0] > 23 || parts[1] > 59) return null;
    return parts[0] * 60 + parts[1];
  }

  void _runSearch() {
    final startMin = _parseTime(startController.text);
    final endMin = _parseTime(endController.text, allowEnd: true);
    if (startMin == null || endMin == null || startMin >= endMin) {
      setState(() => searchResult = null);
      return;
    }

    final currentTask = widget.planner.taskById(widget.task.id) ?? widget.task;
    final baselinePreview =
        widget.planner.preview?.inputRevision == widget.planner.snapshot.revision
        ? widget.planner.preview
        : null;

    const suggester = TimeSuggester();
    final result = suggester.suggest(
      snapshot: widget.planner.snapshot,
      now: widget.planner.now,
      targetTask: currentTask,
      preferredStartMinute: startMin,
      preferredEndMinute: endMin,
      baselinePreview: baselinePreview,
    );

    setState(() {
      searchResult = result;
    });
  }

  Future<void> _pickTime(
    TextEditingController controller, {
    bool allowEnd = false,
  }) async {
    final current = _parseTime(controller.text, allowEnd: allowEnd) ?? 1140;
    final initial = TimeOfDay(
      hour: (current ~/ 60) % 24,
      minute: current % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null && mounted) {
      setState(() {
        controller.text = timeLabel(picked.hour * 60 + picked.minute);
      });
      _runSearch();
    }
  }

  void _openManualInput({DateTime? date, int? startMinute, int? endMinute}) {
    final currentTask = widget.planner.taskById(widget.task.id) ?? widget.task;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TryAddTimeScreen(
          planner: widget.planner,
          task: currentTask,
          unallocatedMinutes: widget.unallocatedMinutes,
          initialDate: date,
          initialStartMinute: startMinute,
          initialEndMinute: endMinute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final res = searchResult;

    return Scaffold(
      appBar: AppBar(title: const Text('Cari saran waktu')),
      body: Form(
        key: formKey,
        child: PageContent(
          actions: AppButton(
            label: 'Kembali',
            secondary: true,
            onPressed: () => Navigator.pop(context),
          ),
          children: [
            PageHeading(
              'Cari saran waktu\n${widget.task.title}',
              'Pilih rentang jam belajar yang bersedia Anda pakai. Sistem mencari hingga 3 slot terbaik sebelum tenggat.',
            ),
            const SizedBox(height: AppLayout.space16),

            if (revisionChangedNotice) ...[
              Notice(
                title: 'Data jadwal diperbarui',
                message:
                    'Data jadwal berubah selama peninjauan. Daftar saran telah dihitung ulang pada revisi terbaru.',
                color: colors.infoBg,
              ),
              const SizedBox(height: AppLayout.space16),
            ],

            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    title: 'Rentang jam bersedia belajar',
                    subtitle: 'Berlaku untuk pencarian di seluruh tanggal sebelum tenggat.',
                  ),
                  const SizedBox(height: AppLayout.space12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(startController),
                          borderRadius: BorderRadius.circular(10),
                          child: TextFormField(
                            controller: startController,
                            keyboardType: TextInputType.datetime,
                            decoration: const InputDecoration(
                              labelText: 'Jam mulai',
                              hintText: '19:00',
                              suffixIcon: DesignIcon('imgClock', size: 18),
                            ),
                            validator: (val) {
                              if (_parseTime(val ?? '') == null) {
                                return 'Format HH:mm';
                              }
                              return null;
                            },
                            onChanged: (_) => _runSearch(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppLayout.space12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(endController, allowEnd: true),
                          borderRadius: BorderRadius.circular(10),
                          child: TextFormField(
                            controller: endController,
                            keyboardType: TextInputType.datetime,
                            decoration: const InputDecoration(
                              labelText: 'Jam selesai',
                              hintText: '22:00',
                              suffixIcon: DesignIcon('imgClock', size: 18),
                            ),
                            validator: (val) {
                              final parsedEnd = _parseTime(
                                val ?? '',
                                allowEnd: true,
                              );
                              final parsedStart = _parseTime(
                                startController.text,
                              );
                              if (parsedEnd == null) return 'Format HH:mm';
                              if (parsedStart != null &&
                                  parsedEnd <= parsedStart) {
                                return 'Harus setelah mulai';
                              }
                              return null;
                            },
                            onChanged: (_) => _runSearch(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppLayout.space16),

            if (res == null)
              const Notice(
                title: 'Rentang jam belum valid',
                message:
                    'Masukkan jam mulai lebih awal daripada jam selesai dengan format HH:mm.',
              )
            else if (res.isEmpty) ...[
              Notice(
                title: 'Belum ada saran slot yang membantu',
                message:
                    res.emptyExplanation ??
                    'Tidak ditemukan slot waktu luang yang dapat mengurangi kekurangan tugas.',
                color: colors.warningBg,
              ),
              const SizedBox(height: AppLayout.space12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Buka input manual',
                  icon: 'imgPlus',
                  onPressed: () => _openManualInput(),
                ),
              ),
            ] else ...[
              SectionHeader(
                title: 'Saran slot terbaik (${res.suggestions.length})',
                subtitle:
                    'Diurutkan dari pengurangan kekurangan terbesar, dampak paling kecil ke tugas lain, dan durasi tersingkat.',
              ),
              const SizedBox(height: AppLayout.space8),
              for (var i = 0; i < res.suggestions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppLayout.space12),
                  child: _SuggestionCard(
                    rank: i + 1,
                    suggestion: res.suggestions[i],
                    onReview: () {
                      final s = res.suggestions[i];
                      final dateParts = s.candidateWindow.date!.split('-');
                      final date = DateTime(
                        int.parse(dateParts[0]),
                        int.parse(dateParts[1]),
                        int.parse(dateParts[2]),
                      );
                      _openManualInput(
                        date: date,
                        startMinute: s.candidateWindow.startMinute,
                        endMinute: s.candidateWindow.endMinute,
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final int rank;
  final TimeSuggestion suggestion;
  final VoidCallback onReview;

  const _SuggestionCard({
    required this.rank,
    required this.suggestion,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sim = suggestion.simulation;
    final dateParts = suggestion.candidateWindow.date!.split('-');
    final slotDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    final dateText = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(slotDate);

    return PaperCard(
      borderColor: rank == 1 ? colors.primary.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppLayout.space8,
            runSpacing: AppLayout.space4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                'Saran #$rank · +${suggestion.addedMinutes} mnt',
                tone: sim.isFullyResolved
                    ? StatusTone.success
                    : StatusTone.info,
              ),
              Text(
                '${timeLabel(suggestion.candidateWindow.startMinute)}–${timeLabel(suggestion.candidateWindow.endMinute)} WIB',
                style: AppTypography.time.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.space8),
          Text(
            dateText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: AppLayout.space8),
          Container(
            padding: const EdgeInsets.all(AppLayout.space12),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sebelum: kurang ${sim.beforeUnallocatedMinutes} mnt → Sesudah: ${sim.afterUnallocatedMinutes == 0 ? 'kekurangan 0 mnt' : 'kurang ${sim.afterUnallocatedMinutes} mnt'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: sim.afterUnallocatedMinutes == 0
                        ? colors.successInk
                        : colors.ink,
                  ),
                ),
                const SizedBox(height: AppLayout.space4),
                if (sim.otherTasksImpact.isEmpty)
                  Text(
                    'Tidak mengubah alokasi tugas lain.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.inkSecondary,
                    ),
                  )
                else
                  Text(
                    'Dampak tugas lain: ${sim.otherTasksImpact.map((imp) => '${imp.task.title} (${imp.minuteDelta >= 0 ? '+${imp.minuteDelta}' : imp.minuteDelta} mnt)').join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: suggestion.harmMinutes > 0
                          ? colors.warningInk
                          : colors.inkSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.space12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Tinjau saran',
              icon: 'imgArrowRight',
              onPressed: onReview,
            ),
          ),
        ],
      ),
    );
  }
}
