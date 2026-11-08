import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../planner/schedule.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class TaskFormScreen extends StatefulWidget {
  final PlannerController planner;
  final String? taskId;
  const TaskFormScreen({super.key, required this.planner, this.taskId});
  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, course, remaining;
  late DateTime deadline;
  late final int revision;
  @override
  void initState() {
    super.initState();
    final task = widget.taskId == null
        ? null
        : widget.planner.taskById(widget.taskId!);
    title = TextEditingController(text: task?.title);
    course = TextEditingController(text: task?.course);
    remaining = TextEditingController(
      text: task?.remainingMinutes.toString() ?? '60',
    );
    deadline =
        task?.deadlineAt ?? widget.planner.now.add(const Duration(days: 1));
    revision = widget.planner.snapshot.revision;
  }

  @override
  void dispose() {
    title.dispose();
    course.dispose();
    remaining.dispose();
    super.dispose();
  }

  Future<void> pickDeadline() async {
    final local = tz.TZDateTime.from(deadline, jakarta);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(local.year, local.month, local.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
    );
    if (time != null && mounted) {
      setState(
        () => deadline = tz.TZDateTime(
          jakarta,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).toUtc(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.taskId == null ? 'Tambah tugas' : 'Ubah tugas'),
    ),
    body: ListenableBuilder(
      listenable: widget.planner,
      builder: (context, _) {
        final p = widget.planner;
        if (widget.taskId != null && p.taskById(widget.taskId!) == null) {
          return const Center(child: Text('Tugas tidak ditemukan.'));
        }
        return Form(
          key: form,
          child: PageContent(
            children: [
              const Text(
                'Semua tanggal dan jam memakai WIB. Perubahan tidak memindahkan jadwal yang sudah dikonfirmasi.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('title'),
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Nama tugas'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama wajib diisi.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: course,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Mata kuliah (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('remaining'),
                controller: remaining,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sisa pengerjaan (menit)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < (widget.taskId == null ? 1 : 0)
                      ? (widget.taskId == null
                            ? 'Masukkan menit bulat positif.'
                            : 'Masukkan menit bulat nonnegatif.')
                      : null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: p.isPending ? null : pickDeadline,
                icon: const Icon(Icons.event),
                label: Text('Tenggat: ${dateTimeLabel(deadline)}'),
              ),
              ErrorNotice(p.error),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: p.isPending
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        final ok = await p.saveTask(
                          id: widget.taskId,
                          title: title.text,
                          course: course.text.trim().isEmpty
                              ? null
                              : course.text.trim(),
                          deadline: deadline,
                          remaining: int.parse(remaining.text),
                          expectedRevision: revision,
                        );
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                child: Text(p.isPending ? 'Menyimpan…' : 'Simpan tugas'),
              ),
              TextButton(
                onPressed: p.isPending ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
