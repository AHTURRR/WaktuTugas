import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../../app/theme.dart';
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
  final titleFocus = FocusNode(), remainingFocus = FocusNode();
  late final TextEditingController title, course, remaining;
  late DateTime deadline;
  late final int revision;
  bool titleEdited = false, remainingEdited = false;

  bool get isNew => widget.taskId == null;
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
    titleFocus.dispose();
    remainingFocus.dispose();
    super.dispose();
  }

  Future<void> pickDeadline({bool timeOnly = false}) async {
    final local = tz.TZDateTime.from(deadline, jakarta);
    DateTime? date;
    TimeOfDay? time;
    if (timeOnly) {
      time = await showAppDialog<TimeOfDay>(
        context,
        (_) => TimePickerDialog(
          initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
        ),
      );
      if (time == null || !mounted) return;
    } else {
      date = await showAppDialog<DateTime>(
        context,
        (_) => DatePickerDialog(
          initialDate: DateTime(local.year, local.month, local.day),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100, 12, 31),
        ),
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

  String? titleError(String? value) =>
      value == null || value.trim().isEmpty ? 'Nama wajib diisi.' : null;

  String? remainingError(String? value) {
    final minutes = int.tryParse(value ?? '');
    if (minutes != null && minutes >= (isNew ? 1 : 0)) return null;
    return isNew
        ? 'Masukkan menit bulat positif.'
        : 'Masukkan menit bulat nonnegatif.';
  }

  Widget fieldError(BuildContext context, String message) {
    final color = AppColors.of(context).dangerInk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignIcon('imgAlertCircle', size: 16, color: color),
        const SizedBox(width: AppLayout.space4),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      final firstError = titleError(title.text) != null
          ? titleFocus
          : remainingFocus;
      firstError.requestFocus();
      if (firstError.context case final fieldContext?) {
        Scrollable.ensureVisible(fieldContext);
      }
      return;
    }
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
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final validIcon = Semantics(
      label: 'Isian valid',
      child: Padding(
        padding: const EdgeInsets.all(AppLayout.space12),
        child: DesignIcon('imgCheckCircle', size: 20, color: colors.successInk),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Tambah tugas' : 'Ubah tugas')),
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
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'Detail tugas'),
                      TextFormField(
                        key: const Key('title'),
                        controller: title,
                        focusNode: titleFocus,
                        enabled: !locked,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nama tugas *',
                          hintText: 'Contoh: Laporan praktikum',
                          suffixIcon:
                              !locked &&
                                  titleEdited &&
                                  titleError(title.text) == null
                              ? validIcon
                              : null,
                        ),
                        onChanged: (_) => setState(() => titleEdited = true),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: titleError,
                        errorBuilder: fieldError,
                      ),
                      const SizedBox(height: AppLayout.space12),
                      TextFormField(
                        controller: course,
                        enabled: !locked,
                        maxLength: 100,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Mata kuliah (opsional)',
                          hintText: 'Contoh: Basis Data',
                        ),
                      ),
                    ],
                  ),
                ),
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'Tenggat dan estimasi'),
                      ResponsiveFields(
                        first: PickerField(
                          label: 'Tanggal *',
                          value: DateFormat(
                            'd MMM yyyy',
                            'id_ID',
                          ).format(tz.TZDateTime.from(deadline, jakarta)),
                          icon: 'imgCalendar',
                          onTap: locked ? null : () => pickDeadline(),
                        ),
                        second: PickerField(
                          label: 'Jam (WIB) *',
                          value: clockLabel(deadline),
                          icon: 'imgClock',
                          onTap: locked
                              ? null
                              : () => pickDeadline(timeOnly: true),
                        ),
                      ),
                      const SizedBox(height: AppLayout.space16),
                      TextFormField(
                        key: const Key('remaining'),
                        controller: remaining,
                        focusNode: remainingFocus,
                        enabled: !locked,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Sisa waktu (menit) *',
                          helperText: isNew
                              ? 'Perkirakan waktu untuk menyelesaikan tugas, minimal 1 menit.'
                              : 'Isi 0 jika tugas sudah selesai.',
                          suffixIcon:
                              !locked &&
                                  remainingEdited &&
                                  remainingError(remaining.text) == null
                              ? validIcon
                              : null,
                        ),
                        onChanged: (_) =>
                            setState(() => remainingEdited = true),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: remainingError,
                        errorBuilder: fieldError,
                      ),
                    ],
                  ),
                ),
                if (p.isPending)
                  const Notice(
                    title: 'Sedang menyimpan',
                    message:
                        'Jangan kirim ulang. Keberhasilan belum dikonfirmasi.',
                  )
                else if (unknown) ...[
                  Notice(
                    title: 'Hasil simpan belum pasti',
                    color: colors.warningBg,
                    icon: 'imgAlertCircle',
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
                Text(
                  '* Wajib diisi',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
