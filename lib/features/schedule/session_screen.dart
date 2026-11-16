import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../planner/models.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class SessionScreen extends StatefulWidget {
  final PlannerController planner;
  final String sessionId;
  const SessionScreen({
    super.key,
    required this.planner,
    required this.sessionId,
  });
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final remaining = TextEditingController();
  bool recording = false;
  bool timerBusy = false;
  Duration? recordedFocusDuration;
  Timer? _ticker;
  late final int revision;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    revision = widget.planner.snapshot.revision;
    final session = widget.planner.sessionById(widget.sessionId);
    if (session != null) {
      remaining.text =
          widget.planner
              .taskById(session.taskId)
              ?.remainingMinutes
              .toString() ??
          '0';
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.planner.isTimerActiveForSession(widget.sessionId) &&
          (widget.planner.activeSessionTimer?.isRunning ?? false)) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    remaining.dispose();
    super.dispose();
  }

  String _formatClock(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  String _formatFocusDuration(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    if (minutes == 0) return '$seconds detik';
    if (seconds == 0) return '$minutes menit';
    return '$minutes menit $seconds detik';
  }

  Future<void> _startTimer() async {
    if (timerBusy) return;
    setState(() => timerBusy = true);
    await widget.planner.startSessionTimer(widget.sessionId);
    if (mounted) setState(() => timerBusy = false);
  }

  Future<void> _pauseTimer() async {
    if (timerBusy) return;
    setState(() => timerBusy = true);
    await widget.planner.pauseSessionTimer(widget.sessionId);
    if (mounted) setState(() => timerBusy = false);
  }

  Future<void> _resumeTimer() async {
    if (timerBusy) return;
    setState(() => timerBusy = true);
    await widget.planner.resumeSessionTimer(widget.sessionId);
    if (mounted) setState(() => timerBusy = false);
  }

  Future<void> _finishTimer() async {
    if (timerBusy) return;
    setState(() => timerBusy = true);
    final duration = await widget.planner.finishSessionTimer(widget.sessionId);
    if (mounted) {
      setState(() {
        timerBusy = false;
        recordedFocusDuration = duration;
        recording = true;
      });
    }
  }

  Future<void> save(SessionStatus status) async {
    if (status == SessionStatus.completed && !form.currentState!.validate()) {
      return;
    }
    final ok = await widget.planner.recordProgress(
      widget.sessionId,
      status,
      status == SessionStatus.completed ? int.parse(remaining.text) : null,
      expectedRevision: revision,
    );
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(recording ? 'Catat progres' : 'Detail sesi')),
      body: ListenableBuilder(
        listenable: widget.planner,
        builder: (context, _) {
          final p = widget.planner, s = p.sessionById(widget.sessionId);
          if (s == null) {
            return const Center(child: Text('Sesi tidak ditemukan.'));
          }
          final task = p.taskById(s.taskId);
          final canClose =
              s.status == SessionStatus.planned && !s.startsAt.isAfter(p.now);
          final locked = p.isPending || p.isOfflineSnapshot;
          return Form(
            key: form,
            child: PageContent(
              actions: recording && canClose
                  ? FormActions(
                      label: p.isPending ? 'Menyimpan…' : 'Simpan progres',
                      onSave: locked
                          ? null
                          : () => save(SessionStatus.completed),
                      onCancel: p.isPending
                          ? null
                          : () => setState(() => recording = false),
                    )
                  : s.status == SessionStatus.planned
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          label: 'Selesai dikerjakan',
                          icon: 'imgCheck',
                          onPressed: !canClose || locked
                              ? null
                              : () => setState(() => recording = true),
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Tandai terlewat',
                          icon: 'imgSkipForward',
                          secondary: true,
                          onPressed: !canClose || locked
                              ? null
                              : () => save(SessionStatus.missed),
                        ),
                        const SizedBox(height: AppLayout.space12),
                      ],
                    )
                  : null,
              children: [
                if (recording && canClose)
                  SectionHeader(
                    title: task?.title ?? s.taskId,
                    subtitle:
                        '${clockLabel(s.startsAt)} \u2013 ${clockLabel(s.endsAt)} WIB',
                  )
                else
                  FocusPanel(
                    eyebrow: recording ? 'PROGRES SESI' : 'SESI FOKUS',
                    icon: 'imgCheckSquare',
                    title: task?.title ?? s.taskId,
                    description: task?.course,
                  ),
                if (!recording)
                  PaperCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StatusBadge(
                              statusLabel(s.status),
                              tone: sessionTone(s.status),
                              icon: s.status == SessionStatus.completed
                                  ? 'imgCheckCircle'
                                  : s.status == SessionStatus.missed
                                  ? 'imgAlertCircle'
                                  : 'imgClock',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          dateLabel(s.startsAt),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.inkSecondary,
                              ),
                        ),
                        const SizedBox(height: AppLayout.space4),
                        Text(
                          '${clockLabel(s.startsAt)}–${clockLabel(s.endsAt)} WIB',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            DesignIcon(
                              'imgClock',
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: AppLayout.space8),
                            Expanded(
                              child: Text(
                                'Durasi rencana · ${s.endsAt.difference(s.startsAt).inMinutes} menit',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.ink,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (task != null) ...[
                          const SizedBox(height: AppLayout.space8),
                          Row(
                            children: [
                              DesignIcon(
                                'imgCalendar',
                                size: 16,
                                color: colors.inkMuted,
                              ),
                              const SizedBox(width: AppLayout.space8),
                              Expanded(
                                child: Text(
                                  'Tenggat tugas · ${dateTimeLabel(task.deadlineAt)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: colors.inkSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (!recording && s.status == SessionStatus.planned)
                  Builder(
                    builder: (context) {
                      final isThisActive = p.isTimerActiveForSession(
                        widget.sessionId,
                      );
                      final isRunning =
                          isThisActive &&
                          (p.activeSessionTimer?.isRunning ?? false);
                      final hasOther = p.hasOtherActiveTimer(widget.sessionId);
                      final elapsed = isThisActive
                          ? p.sessionTimerElapsed(widget.sessionId)
                          : Duration.zero;
                      return PaperCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: SectionHeader(title: 'Timer fokus'),
                                ),
                                const SizedBox(width: AppLayout.space8),
                                StatusBadge(
                                  isRunning
                                      ? 'Berjalan'
                                      : isThisActive
                                      ? 'Dijeda'
                                      : 'Siap',
                                  tone: isRunning
                                      ? StatusTone.success
                                      : isThisActive
                                      ? StatusTone.warning
                                      : StatusTone.neutral,
                                  icon: 'imgClock',
                                ),
                              ],
                            ),
                            const SizedBox(height: AppLayout.space8),
                            Text(
                              _formatClock(elapsed),
                              key: const Key('session-timer-display'),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (!canClose) ...[
                              const SizedBox(height: AppLayout.space8),
                              Text(
                                'Timer dapat dimulai saat sesi sudah masuk waktunya.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.inkSecondary),
                              ),
                            ],
                            if (hasOther) ...[
                              const SizedBox(height: AppLayout.space12),
                              Notice(
                                title: 'Timer aktif di sesi lain',
                                message:
                                    'Satu akun hanya dapat menjalankan satu timer aktif. Selesaikan timer pada sesi lain terlebih dahulu.',
                                color: colors.warningBg,
                              ),
                            ] else ...[
                              const SizedBox(height: AppLayout.space12),
                              Wrap(
                                spacing: AppLayout.space8,
                                runSpacing: AppLayout.space8,
                                children: [
                                  if (!isThisActive)
                                    AppButton(
                                      label: 'Mulai',
                                      icon: 'imgClock',
                                      onPressed:
                                          !canClose || locked || timerBusy
                                          ? null
                                          : _startTimer,
                                    )
                                  else if (isRunning) ...[
                                    AppButton(
                                      label: 'Jeda',
                                      secondary: true,
                                      onPressed: timerBusy ? null : _pauseTimer,
                                    ),
                                    AppButton(
                                      label: 'Selesai',
                                      icon: 'imgCheck',
                                      onPressed:
                                          !canClose || locked || timerBusy
                                          ? null
                                          : _finishTimer,
                                    ),
                                  ] else ...[
                                    AppButton(
                                      label: 'Lanjutkan',
                                      icon: 'imgClock',
                                      onPressed: timerBusy
                                          ? null
                                          : _resumeTimer,
                                    ),
                                    AppButton(
                                      label: 'Selesai',
                                      icon: 'imgCheck',
                                      onPressed:
                                          !canClose || locked || timerBusy
                                          ? null
                                          : _finishTimer,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                if (s.status != SessionStatus.planned) ...[
                  Notice(
                    title: 'Hanya baca · sesi sudah ditutup',
                    message: switch (s.status) {
                      SessionStatus.completed =>
                        'Progres tersimpan. Sisa saat penutupan: ${s.remainingAfter} menit.',
                      SessionStatus.missed =>
                        'Sesi terlewat. Sisa tugas tidak dikurangi otomatis.',
                      _ =>
                        'Sesi dibatalkan saat rencana diganti. Tidak ada progres yang dicatat.',
                    },
                  ),
                  PaperCard(
                    color: colors.surfaceMuted,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sisa pekerjaan saat ini',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.inkMuted,
                              ),
                        ),
                        const SizedBox(height: AppLayout.space4),
                        Text(
                          '${task?.remainingMinutes ?? 0} menit tersisa',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status akhir sesi tidak dapat diubah dari tampilan ini.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                ] else if (recording && canClose) ...[
                  PaperCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Sisa sebelum sesi · ${task?.remainingMinutes ?? 0} menit',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.ink,
                                ),
                          ),
                        ),
                        if (recordedFocusDuration != null) ...[
                          const SizedBox(height: AppLayout.space8),
                          Container(
                            key: const Key('recorded-focus-duration'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Durasi fokus · ${_formatFocusDuration(recordedFocusDuration!)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.onPrimarySoft,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppLayout.space16),
                        const SectionHeader(
                          title: 'Berapa menit yang masih dibutuhkan?',
                        ),
                        TextFormField(
                          key: const Key('remaining-after'),
                          controller: remaining,
                          enabled: !locked,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sisa aktual (menit) *',
                            helperText:
                                'Bilangan bulat ≥ 0. Boleh lebih besar dari sisa sebelumnya.',
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 0
                                ? 'Masukkan menit bulat nonnegatif.'
                                : null;
                          },
                        ),
                      ],
                    ),
                  ),
                  Notice(
                    title: 'Selesai sesi ≠ selesai tugas',
                    message:
                        'Tugas hanya selesai jika sisa aktual 0. Isi berdasarkan pekerjaan yang benar-benar masih tersisa.',
                    color: colors.warningBg,
                    icon: 'imgAlertCircle',
                  ),
                  Text(
                    'Jika sesi terlewat, sisa menit tidak berubah. Tidak ada pengurangan otomatis berdasarkan durasi sesi.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ] else ...[
                  Notice(
                    title: canClose
                        ? 'Sesi sudah dimulai'
                        : 'Sesi belum dimulai',
                    message:
                        '${dateTimeLabel(p.now)}. ${canClose ? 'Tutup sesi sebelum menyusun ulang jadwal.' : 'Progres hanya dapat dicatat setelah waktu mulai.'}',
                    color: canClose ? colors.warningBg : colors.primarySoft,
                    icon: canClose ? 'imgAlertCircle' : 'imgClock',
                  ),
                  Text(
                    'Selesai dikerjakan membuka isian sisa aktual. Terlewat mempertahankan sisa tugas.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ],
                ErrorNotice(p.error),
              ],
            ),
          );
        },
      ),
    );
  }
}
