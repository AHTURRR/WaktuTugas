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

class _SessionScreenState extends State<SessionScreen> {
  final form = GlobalKey<FormState>();
  final remaining = TextEditingController();
  bool recording = false;
  late final int revision;
  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    remaining.dispose();
    super.dispose();
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
  Widget build(BuildContext context) => Scaffold(
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
                    onSave: locked ? null : () => save(SessionStatus.completed),
                    onCancel: p.isPending
                        ? null
                        : () => setState(() => recording = false),
                  )
                : null,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const DesignIcon('imgCheckSquare'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task?.title ?? s.taskId,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (task?.course != null) Text(task!.course!),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(
                      statusLabel(s.status),
                      icon: s.status == SessionStatus.completed
                          ? 'imgCheckCircle'
                          : s.status == SessionStatus.missed
                          ? 'imgAlertCircle'
                          : 'imgClock',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      dateLabel(s.startsAt),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${clockLabel(s.startsAt)}–${clockLabel(s.endsAt)} WIB',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Durasi rencana · ${s.endsAt.difference(s.startsAt).inMinutes} menit',
                    ),
                    if (task != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Tenggat tugas · ${dateTimeLabel(task.deadlineAt)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
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
                Text(
                  '${task?.remainingMinutes ?? 0} menit tersisa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Status akhir sesi tidak dapat diubah dari tampilan ini.',
                ),
              ] else if (recording && canClose) ...[
                Text(
                  'Sisa sebelum sesi · ${task?.remainingMinutes ?? 0} menit',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('remaining-after'),
                  controller: remaining,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sisa aktual setelah sesi (menit) *',
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
                const SizedBox(height: 16),
                const Notice(
                  title: 'Selesai sesi ≠ selesai tugas',
                  message:
                      'Tugas hanya selesai jika sisa aktual 0. Isi berdasarkan pekerjaan yang benar-benar masih tersisa.',
                ),
                const Text(
                  'Jika sesi terlewat, sisa menit tidak berubah. Tidak ada pengurangan otomatis berdasarkan durasi sesi.',
                ),
              ] else ...[
                Notice(
                  title: canClose ? 'Sesi sudah dimulai' : 'Sesi belum dimulai',
                  message:
                      '${dateTimeLabel(p.now)}. ${canClose ? 'Tutup sesi sebelum menyusun ulang jadwal.' : 'Progres hanya dapat dicatat setelah waktu mulai.'}',
                  color: canClose ? AppColors.warning : AppColors.cyan,
                ),
                AppButton(
                  label: 'Selesai dikerjakan',
                  icon: 'imgCheck',
                  onPressed: !canClose || locked
                      ? null
                      : () => setState(() => recording = true),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Tandai terlewat',
                  icon: 'imgSkipForward',
                  secondary: true,
                  onPressed: !canClose || locked
                      ? null
                      : () => save(SessionStatus.missed),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selesai dikerjakan membuka isian sisa aktual. Terlewat mempertahankan sisa tugas.',
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
