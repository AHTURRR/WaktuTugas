import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../app/theme.dart';
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
  late int revision;
  late final String newId;
  late bool weekly;
  late int weekday;
  late DateTime date, endDate;
  ActivityKind kind = ActivityKind.event;
  String? localError;
  bool saving = false;
  int savedDays = 0;
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
    endDate = date;
    revision = widget.planner.snapshot.revision;
    newId = '${widget.activity ? 'activity' : 'window'}-${revision + 1}';
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
    final value = await showAppDialog<TimeOfDay>(
      context,
      (_) => TimePickerDialog(
        initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
      ),
    );
    if (value != null && mounted) {
      setState(() => field.text = timeLabel(value.hour * 60 + value.minute));
    }
  }

  Future<void> pickDate({bool last = false}) async {
    final value = await showAppDialog<DateTime>(
      context,
      (_) => DatePickerDialog(
        initialDate: last ? endDate : date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        if (last) {
          endDate = value;
        } else {
          date = value;
          if (endDate.isBefore(date)) endDate = date;
        }
      });
    }
  }

  bool get dateRange =>
      widget.activity &&
      kind == ActivityKind.blocked &&
      !weekly &&
      widget.window == null;
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (dateRange && endDate.isBefore(date)) {
      setState(
        () =>
            localError = 'Tanggal akhir harus sama atau setelah tanggal mulai.',
      );
      return;
    }
    final p = widget.planner;
    final total = dateRange ? endDate.difference(date).inDays + 1 : 1;
    setState(() {
      saving = true;
      localError = null;
    });
    try {
      // shortcut: closures use one entry per date, use a bulk RPC when atomic multi-date saves are required.
      for (var i = savedDays; i < total; i++) {
        final day = weekly
            ? null
            : DateTime(
                date.year,
                date.month,
                date.day + i,
              ).toIso8601String().substring(0, 10);
        final id = widget.window?.id ?? (dateRange ? '$newId-$day' : newId);
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
        if (!ok) {
          if (mounted) {
            setState(
              () => localError =
                  '${savedDays > 0 ? '$savedDays tanggal telah disimpan. ' : ''}${p.error ?? 'Belum tersimpan.'} Isian tetap tersedia.',
            );
          }
          return;
        }
        revision = p.snapshot.revision;
        savedDays = i + 1;
      }
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      if (mounted) setState(() => localError = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final heading = widget.activity
        ? kind == ActivityKind.blocked
              ? 'Penutupan bertanggal'
              : weekly
              ? 'Aktivitas mingguan'
              : 'Aktivitas sekali'
        : weekly
        ? 'Rentang mingguan'
        : 'Rentang tambahan';
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: Text(heading)),
        body: ListenableBuilder(
          listenable: widget.planner,
          builder: (context, _) {
            final p = widget.planner;
            final locked = saving || p.isPending || p.isOfflineSnapshot;
            final fieldsLocked = locked || savedDays > 0;
            return Form(
              key: form,
              child: PageContent(
                actions: FormActions(
                  label: saving ? 'Menyimpan…' : 'Simpan waktu',
                  onSave: locked ? null : save,
                  onCancel: locked ? null : () => Navigator.pop(context),
                ),
                children: [
                  PageHeading(
                    widget.activity
                        ? 'Jaga ruang\nuntuk hidup.'
                        : 'Sediakan waktu\nuntuk maju.',
                    widget.activity
                        ? 'Kegiatan dan penutupan mengurangi waktu pengerjaan.'
                        : 'Tentukan kapan tugas boleh dikerjakan.',
                  ),
                  PaperCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.activity) ...[
                          DropdownButtonFormField<ActivityKind>(
                            isExpanded: true,
                            isDense: false,
                            itemHeight: null,
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
                            onChanged: fieldsLocked
                                ? null
                                : (v) => setState(() {
                                    kind = v!;
                                    weekly = kind == ActivityKind.routine;
                                  }),
                          ),
                          const SizedBox(height: AppLayout.space16),
                          TextFormField(
                            controller: label,
                            enabled: !fieldsLocked,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              labelText: 'Label kegiatan (opsional)',
                              hintText: 'Contoh: Kuliah Sistem Operasi',
                            ),
                          ),
                          const SizedBox(height: AppLayout.space12),
                        ] else ...[
                          DropdownButtonFormField<bool>(
                            isExpanded: true,
                            isDense: false,
                            itemHeight: null,
                            key: const Key('scope'),
                            initialValue: weekly,
                            decoration: const InputDecoration(
                              labelText: 'Pola rentang',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: false,
                                child: Text('Tanggal tertentu'),
                              ),
                              DropdownMenuItem(
                                value: true,
                                child: Text('Mingguan'),
                              ),
                            ],
                            onChanged: fieldsLocked
                                ? null
                                : (v) => setState(() => weekly = v!),
                          ),
                          const SizedBox(height: AppLayout.space16),
                        ],
                        if (weekly)
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            isDense: false,
                            itemHeight: null,
                            initialValue: weekday,
                            decoration: const InputDecoration(
                              labelText: 'Hari setiap minggu *',
                            ),
                            items: [
                              for (var i = 0; i < 7; i++)
                                DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(weekdays[i]),
                                ),
                            ],
                            onChanged: fieldsLocked
                                ? null
                                : (v) => setState(() => weekday = v!),
                          )
                        else ...[
                          PickerField(
                            label: dateRange ? 'Tanggal mulai *' : 'Tanggal *',
                            value: DateFormat(
                              'd MMM yyyy',
                              'id_ID',
                            ).format(date),
                            icon: 'imgCalendar',
                            onTap: fieldsLocked ? null : () => pickDate(),
                          ),
                          if (dateRange) ...[
                            const SizedBox(height: AppLayout.space16),
                            PickerField(
                              label: 'Tanggal akhir *',
                              value: DateFormat(
                                'd MMM yyyy',
                                'id_ID',
                              ).format(endDate),
                              icon: 'imgCalendar',
                              onTap: fieldsLocked
                                  ? null
                                  : () => pickDate(last: true),
                            ),
                          ],
                        ],
                        const SizedBox(height: AppLayout.space16),
                        SectionHeader(
                          title: widget.activity
                              ? 'Jam kegiatan'
                              : 'Jam pengerjaan',
                          subtitle: 'Gunakan format 24 jam dalam WIB.',
                        ),
                        ResponsiveFields(
                          first: TextFormField(
                            key: const Key('start-time'),
                            controller: start,
                            enabled: !fieldsLocked,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: 'Mulai · WIB *',
                              suffixIcon: IconButton(
                                tooltip: 'Pilih jam mulai',
                                icon: DesignIcon(
                                  'imgClock',
                                  size: 20,
                                  color: colors.inkSecondary,
                                ),
                                onPressed: fieldsLocked
                                    ? null
                                    : () => pickTime(start),
                              ),
                            ),
                            validator: (v) => parseTime(v ?? '') == null
                                ? 'Jam mulai harus 00:00–23:59.'
                                : null,
                          ),
                          second: TextFormField(
                            key: const Key('end-time'),
                            controller: end,
                            enabled: !fieldsLocked,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: 'Selesai · WIB *',
                              suffixIcon: IconButton(
                                tooltip: 'Pilih jam selesai',
                                icon: DesignIcon(
                                  'imgClock',
                                  size: 20,
                                  color: colors.inkSecondary,
                                ),
                                onPressed: fieldsLocked
                                    ? null
                                    : () => pickTime(end),
                              ),
                            ),
                            validator: (v) {
                              final a = parseTime(start.text),
                                  b = parseTime(v ?? '', allowEnd: true);
                              if (b == null) {
                                return 'Jam selesai harus 00:01–24:00.';
                              }
                              return a != null && b <= a
                                  ? 'Jam selesai harus setelah mulai.'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(height: AppLayout.space12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: DesignIcon(
                                'imgInfo',
                                size: 15,
                                color: colors.inkMuted,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Batas waktu yang jelas: jika melewati tengah malam, buat dua rentang pada dua hari. 24:00 hanya boleh sebagai waktu selesai.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.inkSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Notice(
                    title: widget.activity
                        ? kind == ActivityKind.blocked
                              ? 'Penutupan tidak dapat ditimpa'
                              : 'Aktivitas mengurangi waktu kerja'
                        : 'Hanya rentang ini yang diizinkan',
                    message: widget.activity
                        ? 'Kegiatan dan penutupan memotong waktu yang diizinkan. Tambahan waktu tidak membuka rentang yang ditutup.'
                        : 'Waktu di luar rentang kerja tidak otomatis tersedia, meskipun kalender kosong. Rentang bertumpuk dihitung sekali.',
                  ),
                  if (dateRange)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Disimpan sebagai satu penutupan per tanggal. ${savedDays > 0 ? '$savedDays tanggal sudah tersimpan; melanjutkan tidak mengulang tanggal tersebut.' : 'Jika sebagian gagal, tanggal yang berhasil tetap tersimpan.'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                    ),
                  ErrorNotice(localError ?? p.error),
                  Text(
                    '* Wajib diisi · simpan tidak otomatis mengganti jadwal terkonfirmasi.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
