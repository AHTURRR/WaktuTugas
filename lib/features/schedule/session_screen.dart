import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  SessionStatus status = SessionStatus.completed;
  late final int revision;
  @override
  void initState() {
    super.initState();
    revision = widget.planner.snapshot.revision;
    final session = widget.planner.sessionById(widget.sessionId);
    if (session != null) {
      remaining.text = widget.planner
          .taskById(session.taskId)!
          .remainingMinutes
          .toString();
    }
  }

  @override
  void dispose() {
    remaining.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Progres sesi')),
    body: ListenableBuilder(
      listenable: widget.planner,
      builder: (context, _) {
        final p = widget.planner, s = p.sessionById(widget.sessionId);
        if (s == null) {
          return const Center(child: Text('Sesi tidak ditemukan.'));
        }
        final canClose =
            s.status == SessionStatus.planned && !s.startsAt.isAfter(p.now);
        return Form(
          key: form,
          child: PageContent(
            children: [
              PageHeading(
                p.taskById(s.taskId)!.title,
                '${dateTimeLabel(s.startsAt)} – ${dateTimeLabel(s.endsAt)}',
              ),
              Text('Status: ${statusLabel(s.status)}'),
              if (s.status != SessionStatus.planned)
                Text(
                  'Sesi sudah ditutup dan tidak dapat diedit.${s.remainingAfter == null ? '' : ' Sisa saat penutupan: ${s.remainingAfter} menit.'}',
                )
              else if (!canClose)
                const Text(
                  'Progres hanya dapat dicatat setelah sesi mulai. Gunakan kontrol jam demo di halaman Jadwal untuk mencoba.',
                ),
              if (canClose) ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<SessionStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Hasil sesi'),
                  items: const [
                    DropdownMenuItem(
                      value: SessionStatus.completed,
                      child: Text('Selesai dikerjakan'),
                    ),
                    DropdownMenuItem(
                      value: SessionStatus.missed,
                      child: Text('Terlewat'),
                    ),
                  ],
                  onChanged: p.isPending
                      ? null
                      : (v) => setState(() => status = v!),
                ),
                const SizedBox(height: 16),
                if (status == SessionStatus.completed)
                  TextFormField(
                    key: const Key('remaining-after'),
                    controller: remaining,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sisa pengerjaan sebenarnya (menit)',
                      helperText:
                          'Boleh meningkat jika estimasi sebelumnya terlalu kecil.',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0
                          ? 'Masukkan menit bulat nonnegatif.'
                          : null;
                    },
                  )
                else
                  const Text('Sisa pengerjaan tugas tidak berubah.'),
                ErrorNotice(p.error),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: p.isPending
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          final ok = await p.recordProgress(
                            s.id,
                            status,
                            status == SessionStatus.completed
                                ? int.parse(remaining.text)
                                : null,
                            expectedRevision: revision,
                          );
                          if (ok && context.mounted) context.pop();
                        },
                  child: Text(p.isPending ? 'Menyimpan…' : 'Simpan progres'),
                ),
              ],
              TextButton(
                onPressed: p.isPending ? null : () => context.pop(),
                child: const Text('Batal'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
