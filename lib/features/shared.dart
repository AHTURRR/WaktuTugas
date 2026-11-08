import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../planner/models.dart';
import '../planner/schedule.dart';

String dateTimeLabel(DateTime value) =>
    '${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(tz.TZDateTime.from(value, jakarta))} WIB';
String dateLabel(DateTime value) => DateFormat(
  'EEEE, d MMM yyyy',
  'id_ID',
).format(tz.TZDateTime.from(value, jakarta));
String timeLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
const weekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
String windowLabel(TimeWindow w) =>
    '${w.weekday == null ? w.date : weekdays[w.weekday! - 1]} • ${timeLabel(w.startMinute)}–${timeLabel(w.endMinute)} WIB';
String statusLabel(SessionStatus s) => switch (s) {
  SessionStatus.planned => 'Direncanakan',
  SessionStatus.completed => 'Selesai',
  SessionStatus.missed => 'Terlewat',
  SessionStatus.cancelled => 'Dibatalkan',
};

class PageContent extends StatelessWidget {
  final List<Widget> children;
  const PageContent({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle),
      ],
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  final String? message;
  const ErrorNotice(this.message, {super.key});
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}

Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
