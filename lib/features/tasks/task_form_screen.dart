import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
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

  Future<void> pickDeadline({bool timeOnly = false}) async {
    final local = tz.TZDateTime.from(deadline, jakarta);
    DateTime? date;
    TimeOfDay? time;
    if (timeOnly) {
      time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
      );
      if (time == null || !mounted) return;
    } else {
      date = await showDatePicker(
        context: context,
        initialDate: DateTime(local.year, local.month, local.day),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      );
      if (date == null || !mounted) return;
    }
    setState(
      () => deadline = tz.TZDateTime(
        jakarta,
        date?.year ?? local.year,
        date?.month ?? local.month,
        date?.day ?? local.day,
        time?.hour ?? local.hour,
        time?.minute ?? local.minute,
      ).toUtc(),
    );
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final ok = await widget.planner.saveTask(
      id: widget.taskId,
      title: title.text,
      course: course.text.trim().isEmpty ? null : course.text.trim(),
      deadline: deadline,
      remaining: int.parse(remaining.text),
      expectedRevision: revision,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.taskId == null ? 'Tambah tugas' : 'Ubah tugas'),
    ),
    body: ListenableBuilder(
      listenable: widget.planner,
      builder: (context, _) {
        final p = widget.planner, locked = p.isPending || p.isOfflineSnapshot;
        final unknown =
            p.errorCode == 'TIMEOUT' || p.errorCode == 'UNKNOWN_ERROR';
        if (widget.taskId != null && p.taskById(widget.taskId!) == null) {
          return const Center(child: Text('Tugas tidak ditemukan.'));
        }
        return Form(
          key: form,
          child: PageContent(
            actions: FormActions(
              label: p.isPending ? 'Menyimpan…' : 'Simpan tugas',
              onSave: locked || unknown ? null : save,
              onCancel: p.isPending ? null : () => Navigator.pop(context),
            ),
            children: [
              const Text('Tentukan tenggat dan pekerjaan yang masih tersisa.'),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('title'),
                controller: title,
                enabled: !locked,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Nama tugas *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama wajib diisi.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: course,
                enabled: !locked,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Mata kuliah (opsional)',
                ),
              ),
              const SizedBox(height: 16),
              ResponsiveFields(
                first: PickerField(
                  label: 'Tanggal tenggat *',
                  value: DateFormat(
                    'd MMM yyyy',
                    'id_ID',
                  ).format(tz.TZDateTime.from(deadline, jakarta)),
                  icon: 'imgCalendar',
                  onTap: locked ? null : () => pickDeadline(),
                ),
                second: PickerField(
                  label: 'Waktu · WIB *',
                  value: clockLabel(deadline),
                  icon: 'imgClock',
                  onTap: locked ? null : () => pickDeadline(timeOnly: true),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('remaining'),
                controller: remaining,
                enabled: !locked,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sisa pekerjaan (menit) *',
                  helperText: widget.taskId == null
                      ? 'Bilangan bulat ≥ 1. Bukan durasi yang sudah dikerjakan.'
                      : 'Bilangan bulat ≥ 0. Isi 0 jika tugas selesai.',
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
              if (p.isPending)
                const Notice(
                  title: 'Sedang menyimpan',
                  message:
                      'Jangan kirim ulang. Keberhasilan belum dikonfirmasi.',
                )
              else if (unknown) ...[
                const Notice(
                  title: 'Hasil simpan belum pasti',
                  message:
                      'Isian tetap ada. Periksa daftar tugas terbaru sebelum mengirim ulang agar tidak membuat tugas ganda.',
                ),
                AppButton(
                  label: 'Periksa daftar tugas',
                  secondary: true,
                  onPressed: locked
                      ? null
                      : () async {
                          final ok = await p.fetchSnapshot();
                          if (ok && !p.isOfflineSnapshot && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                ),
              ] else if (p.error != null)
                ErrorNotice(p.error)
              else
                const Notice(
                  title: 'Jadwal tidak berubah otomatis',
                  message:
                      'Setelah mengubah tugas, hitung pratinjau dan konfirmasi untuk mengganti sesi rencana.',
                ),
              const Text(
                '* Wajib diisi · semua waktu menggunakan WIB.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    ),
  );
}
