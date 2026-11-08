import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../planner/models.dart';
import '../../planner/schedule.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class TimeFormScreen extends StatefulWidget {
  final PlannerController planner;
  final TimeWindow? window;
  final bool activity;
  const TimeFormScreen({
    super.key,
    required this.planner,
    this.window,
    this.activity = false,
  });
  @override
  State<TimeFormScreen> createState() => _TimeFormScreenState();
}

class _TimeFormScreenState extends State<TimeFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController start, end, label;
  late final int revision;
  late bool weekly;
  late int weekday;
  late DateTime date;
  ActivityKind kind = ActivityKind.event;
  String? localError;
  @override
  void initState() {
    super.initState();
    final w = widget.window;
    start = TextEditingController(text: timeLabel(w?.startMinute ?? 1140));
    end = TextEditingController(text: timeLabel(w?.endMinute ?? 1260));
    label = TextEditingController(text: w is Activity ? w.label : '');
    if (w is Activity) kind = w.kind;
    weekly = w?.weekday != null;
    weekday = w?.weekday ?? 1;
    final today = tz.TZDateTime.from(widget.planner.now, jakarta);
    date = w?.date == null
        ? DateTime(today.year, today.month, today.day)
        : DateTime.parse(w!.date!);
    revision = widget.planner.snapshot.revision;
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    label.dispose();
    super.dispose();
  }

  int? parseTime(String text, {bool allowEnd = false}) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) return null;
    final parts = text.split(':').map(int.parse).toList();
    if (allowEnd && parts[0] == 24 && parts[1] == 0) return 1440;
    if (parts[0] > 23 || parts[1] > 59) return null;
    return parts[0] * 60 + parts[1];
  }

  Future<void> pickTime(TextEditingController field) async {
    final n = parseTime(field.text) ?? 0;
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
    );
    if (value != null && mounted) {
      setState(() => field.text = timeLabel(value.hour * 60 + value.minute));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.activity ? 'Kegiatan & penutupan' : 'Rentang pengerjaan',
      ),
    ),
    body: ListenableBuilder(
      listenable: widget.planner,
      builder: (context, _) {
        final p = widget.planner;
        return Form(
          key: form,
          child: PageContent(
            children: [
              const Text(
                'WIB • satu rentang untuk satu hari. Untuk melewati tengah malam, buat dua rentang. Gunakan 24:00 sebagai akhir hari.',
              ),
              const SizedBox(height: 20),
              if (widget.activity) ...[
                DropdownButtonFormField<ActivityKind>(
                  initialValue: kind,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kegiatan',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ActivityKind.routine,
                      child: Text('Rutin mingguan'),
                    ),
                    DropdownMenuItem(
                      value: ActivityKind.event,
                      child: Text('Kegiatan sekali'),
                    ),
                    DropdownMenuItem(
                      value: ActivityKind.blocked,
                      child: Text('Penutupan waktu'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    kind = v!;
                    weekly = kind == ActivityKind.routine;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: label,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Label kegiatan (opsional)',
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                DropdownButtonFormField<bool>(
                  key: const Key('scope'),
                  initialValue: weekly,
                  decoration: const InputDecoration(labelText: 'Pola rentang'),
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('Tanggal tertentu'),
                    ),
                    DropdownMenuItem(value: true, child: Text('Mingguan')),
                  ],
                  onChanged: (v) => setState(() => weekly = v!),
                ),
                const SizedBox(height: 16),
              ],
              if (weekly)
                DropdownButtonFormField<int>(
                  initialValue: weekday,
                  decoration: const InputDecoration(labelText: 'Hari'),
                  items: [
                    for (var i = 0; i < 7; i++)
                      DropdownMenuItem(value: i + 1, child: Text(weekdays[i])),
                  ],
                  onChanged: (v) => setState(() => weekday = v!),
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(
                    'Tanggal: ${date.toIso8601String().substring(0, 10)}',
                  ),
                  onPressed: p.isPending
                      ? null
                      : () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (value != null && mounted) {
                            setState(() => date = value);
                          }
                        },
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('start-time'),
                controller: start,
                decoration: InputDecoration(
                  labelText: 'Mulai (HH:mm)',
                  suffixIcon: IconButton(
                    tooltip: 'Pilih jam mulai',
                    icon: const Icon(Icons.schedule),
                    onPressed: () => pickTime(start),
                  ),
                ),
                validator: (v) => parseTime(v ?? '') == null
                    ? 'Jam mulai harus 00:00–23:59.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('end-time'),
                controller: end,
                decoration: InputDecoration(
                  labelText: 'Selesai (HH:mm)',
                  suffixIcon: IconButton(
                    tooltip: 'Pilih jam selesai',
                    icon: const Icon(Icons.schedule),
                    onPressed: () => pickTime(end),
                  ),
                ),
                validator: (v) {
                  final a = parseTime(start.text),
                      b = parseTime(v ?? '', allowEnd: true);
                  if (b == null) return 'Jam selesai harus 00:01–24:00.';
                  return a != null && b <= a
                      ? 'Jam selesai harus setelah mulai.'
                      : null;
                },
              ),
              ErrorNotice(localError ?? p.error),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: p.isPending
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        try {
                          final id =
                              widget.window?.id ??
                              '${widget.activity ? 'activity' : 'window'}-${revision + 1}';
                          final day = weekly
                              ? null
                              : date.toIso8601String().substring(0, 10);
                          final a = parseTime(start.text)!,
                              b = parseTime(end.text, allowEnd: true)!;
                          final ok = widget.activity
                              ? await p.saveActivity(
                                  Activity(
                                    id: id,
                                    weekday: weekly ? weekday : null,
                                    date: day,
                                    startMinute: a,
                                    endMinute: b,
                                    kind: kind,
                                    label: label.text.trim(),
                                  ),
                                  expectedRevision: revision,
                                )
                              : await p.saveWindow(
                                  TimeWindow(
                                    id: id,
                                    weekday: weekly ? weekday : null,
                                    date: day,
                                    startMinute: a,
                                    endMinute: b,
                                  ),
                                  expectedRevision: revision,
                                );
                          if (ok && context.mounted) Navigator.pop(context);
                        } on FormatException catch (e) {
                          setState(() => localError = e.message);
                        }
                      },
                child: Text(p.isPending ? 'Menyimpan…' : 'Simpan waktu'),
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
