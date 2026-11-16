import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'schedule.dart';

/// Satu segmen waktu terblokir hasil konversi acara .ics ke zona waktu WIB.
class IcsImportedSegment {
  final String date;
  final int startMinute;
  final int endMinute;
  final String label;

  const IcsImportedSegment({
    required this.date,
    required this.startMinute,
    required this.endMinute,
    required this.label,
  });

  Activity toBlockedActivity({required String id}) {
    return Activity(
      id: id,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      kind: ActivityKind.blocked,
      label: label,
    );
  }
}

/// Acara .ics yang valid dan siap ditinjau untuk disimpan sebagai waktu terblokir.
class IcsImportCandidate {
  final String uid;
  final String summary;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
  final String sourceTimeZone;
  final List<IcsImportedSegment> segments;
  final bool isDuplicate;

  const IcsImportCandidate({
    required this.uid,
    required this.summary,
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.sourceTimeZone,
    required this.segments,
    this.isDuplicate = false,
  });

  IcsImportCandidate copyWith({bool? isDuplicate}) {
    return IcsImportCandidate(
      uid: uid,
      summary: summary,
      startsAtUtc: startsAtUtc,
      endsAtUtc: endsAtUtc,
      sourceTimeZone: sourceTimeZone,
      segments: segments,
      isDuplicate: isDuplicate ?? this.isDuplicate,
    );
  }
}

/// Acara .ics yang dilewati beserta alasannya.
class IcsSkippedEvent {
  final String summary;
  final String reason;

  const IcsSkippedEvent({required this.summary, required this.reason});
}

/// Hasil pembacaan file .ics.
class IcsParseResult {
  final List<IcsImportCandidate> candidates;
  final List<IcsSkippedEvent> skipped;

  const IcsParseResult({required this.candidates, required this.skipped});
}

/// Parser file iCalendar (.ics) satu arah ke kegiatan waktu terblokir (WIB).
class IcsCalendarParser {
  const IcsCalendarParser();

  static const Map<String, String> _tzAliases = {
    'UTC': 'UTC',
    'GMT': 'UTC',
    'Z': 'UTC',
    'WIB': 'Asia/Jakarta',
    'SE ASIA STANDARD TIME': 'Asia/Jakarta',
    'WITA': 'Asia/Makassar',
    'WIT': 'Asia/Jayapura',
    'SINGAPORE STANDARD TIME': 'Asia/Singapore',
    'TOKYO STANDARD TIME': 'Asia/Tokyo',
    'EASTERN STANDARD TIME': 'America/New_York',
    'PACIFIC STANDARD TIME': 'America/Los_Angeles',
    'GMT STANDARD TIME': 'Europe/London',
  };

  IcsParseResult parse(
    String rawContent, {
    List<Activity> existingActivities = const [],
  }) {
    final normalized = rawContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) {
      throw const FormatException('File .ics kosong.');
    }

    // RFC 5545 line unfolding: baris lanjutan diawali spasi atau tab.
    final unfoldedLines = <String>[];
    for (final line in normalized.split('\n')) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfoldedLines.isNotEmpty) {
        unfoldedLines[unfoldedLines.length - 1] += line.substring(1);
      } else if (line.trim().isNotEmpty) {
        unfoldedLines.add(line);
      }
    }

    final hasBeginCal = unfoldedLines.any(
      (l) => l.trim().toUpperCase() == 'BEGIN:VCALENDAR',
    );
    final hasEndCal = unfoldedLines.any(
      (l) => l.trim().toUpperCase() == 'END:VCALENDAR',
    );
    if (!hasBeginCal || !hasEndCal) {
      throw const FormatException(
        'File .ics tidak valid atau rusak (struktur VCALENDAR tidak lengkap).',
      );
    }

    final candidates = <IcsImportCandidate>[];
    final skipped = <IcsSkippedEvent>[];

    List<String>? currentEventLines;
    var inCalendar = false;
    var eventIndex = 0;

    for (final line in unfoldedLines) {
      final upper = line.trim().toUpperCase();
      if (upper == 'BEGIN:VCALENDAR') {
        inCalendar = true;
        continue;
      }
      if (upper == 'END:VCALENDAR') {
        if (currentEventLines != null) {
          throw const FormatException(
            'File .ics rusak (terdapat VEVENT yang tidak ditutup).',
          );
        }
        inCalendar = false;
        continue;
      }
      if (!inCalendar) continue;

      if (upper == 'BEGIN:VEVENT') {
        if (currentEventLines != null) {
          throw const FormatException(
            'File .ics rusak (VEVENT bersarang tidak valid).',
          );
        }
        currentEventLines = <String>[];
        continue;
      }
      if (upper == 'END:VEVENT') {
        if (currentEventLines == null) {
          throw const FormatException(
            'File .ics rusak (END:VEVENT tanpa BEGIN:VEVENT).',
          );
        }
        eventIndex++;
        _processEvent(
          lines: currentEventLines,
          eventIndex: eventIndex,
          existingActivities: existingActivities,
          candidates: candidates,
          skipped: skipped,
        );
        currentEventLines = null;
        continue;
      }
      if (currentEventLines != null) {
        currentEventLines.add(line);
      }
    }

    if (currentEventLines != null) {
      throw const FormatException(
        'File .ics rusak (BEGIN:VEVENT tidak ditutup dengan END:VEVENT).',
      );
    }

    return IcsParseResult(candidates: candidates, skipped: skipped);
  }

  void _processEvent({
    required List<String> lines,
    required int eventIndex,
    required List<Activity> existingActivities,
    required List<IcsImportCandidate> candidates,
    required List<IcsSkippedEvent> skipped,
  }) {
    String? uid;
    String? summary;
    _IcsProp? dtStart;
    _IcsProp? dtEnd;
    var hasRecurrence = false;

    for (final line in lines) {
      final prop = _parseProperty(line);
      if (prop == null) continue;
      switch (prop.name) {
        case 'UID':
          uid = prop.value.trim();
        case 'SUMMARY':
          summary = _unescapeText(prop.value.trim());
        case 'DTSTART':
          dtStart = prop;
        case 'DTEND':
          dtEnd = prop;
        case 'RRULE':
        case 'RDATE':
          hasRecurrence = true;
      }
    }

    final displaySummary = (summary == null || summary.isEmpty)
        ? 'Kegiatan kalender'
        : summary;
    final clippedLabel = displaySummary.length > 120
        ? displaySummary.substring(0, 120)
        : displaySummary;

    if (hasRecurrence) {
      skipped.add(
        IcsSkippedEvent(
          summary: displaySummary,
          reason: 'Aturan pengulangan (RRULE/RDATE) belum didukung.',
        ),
      );
      return;
    }

    if (dtStart == null || dtEnd == null) {
      skipped.add(
        IcsSkippedEvent(
          summary: displaySummary,
          reason: 'Acara harus memiliki jam mulai dan jam selesai.',
        ),
      );
      return;
    }

    if (_isAllDay(dtStart) || _isAllDay(dtEnd)) {
      skipped.add(
        IcsSkippedEvent(
          summary: displaySummary,
          reason: 'Acara sepanjang hari belum didukung pada versi pertama.',
        ),
      );
      return;
    }

    final startParsed = _parseDateTimeToUtc(dtStart);
    if (startParsed.error != null) {
      skipped.add(
        IcsSkippedEvent(summary: displaySummary, reason: startParsed.error!),
      );
      return;
    }

    final endParsed = _parseDateTimeToUtc(dtEnd);
    if (endParsed.error != null) {
      skipped.add(
        IcsSkippedEvent(summary: displaySummary, reason: endParsed.error!),
      );
      return;
    }

    final startUtc = startParsed.utc!;
    final endUtc = endParsed.utc!;
    if (!endUtc.isAfter(startUtc)) {
      skipped.add(
        IcsSkippedEvent(
          summary: displaySummary,
          reason: 'Jam selesai acara harus setelah jam mulai.',
        ),
      );
      return;
    }

    final segments = _splitToWibSegments(startUtc, endUtc, clippedLabel);
    if (segments.isEmpty) {
      skipped.add(
        IcsSkippedEvent(
          summary: displaySummary,
          reason: 'Durasi efektif acara terlalu singkat (< 1 menit).',
        ),
      );
      return;
    }

    final isDup = _isAlreadyImported(
      segments: segments,
      existingActivities: existingActivities,
      alreadyParsedCandidates: candidates,
    );

    candidates.add(
      IcsImportCandidate(
        uid: (uid == null || uid.isEmpty) ? 'ics-ev-$eventIndex' : uid,
        summary: displaySummary,
        startsAtUtc: startUtc,
        endsAtUtc: endUtc,
        sourceTimeZone: startParsed.sourceTzLabel!,
        segments: segments,
        isDuplicate: isDup,
      ),
    );
  }

  static bool _isAllDay(_IcsProp prop) {
    final valueType = prop.params['VALUE']?.toUpperCase();
    if (valueType == 'DATE') return true;
    return RegExp(r'^\d{8}$').hasMatch(prop.value.trim());
  }

  static ({DateTime? utc, String? sourceTzLabel, String? error})
  _parseDateTimeToUtc(_IcsProp prop) {
    final raw = prop.value.trim();
    final tzid = prop.params['TZID']?.trim();

    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$',
    ).firstMatch(raw);
    if (match == null) {
      return (
        utc: null,
        sourceTzLabel: null,
        error: 'Format tanggal atau jam acara tidak dapat ditafsirkan.',
      );
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final isUtcZ = match.group(7) == 'Z';

    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return (
        utc: null,
        sourceTzLabel: null,
        error: 'Nilai tanggal atau jam acara di luar rentang valid.',
      );
    }

    if (isUtcZ) {
      final utc = DateTime.utc(year, month, day, hour, minute, second);
      if (utc.year != year || utc.month != month || utc.day != day) {
        return (
          utc: null,
          sourceTzLabel: null,
          error: 'Tanggal kalender tidak valid.',
        );
      }
      return (utc: utc, sourceTzLabel: 'UTC', error: null);
    }

    if (tzid != null && tzid.isNotEmpty) {
      final location = _resolveLocation(tzid);
      if (location == null) {
        return (
          utc: null,
          sourceTzLabel: null,
          error: 'Zona waktu "$tzid" tidak dapat ditafsirkan.',
        );
      }
      final zoned = tz.TZDateTime(
        location,
        year,
        month,
        day,
        hour,
        minute,
        second,
      );
      if (zoned.year != year || zoned.month != month || zoned.day != day) {
        return (
          utc: null,
          sourceTzLabel: null,
          error: 'Tanggal kalender tidak valid.',
        );
      }
      return (utc: zoned.toUtc(), sourceTzLabel: tzid, error: null);
    }

    // Floating time tanpa Z maupun TZID: ditafsirkan sebagai waktu lokal WIB.
    final wib = tz.TZDateTime(jakarta, year, month, day, hour, minute, second);
    if (wib.year != year || wib.month != month || wib.day != day) {
      return (
        utc: null,
        sourceTzLabel: null,
        error: 'Tanggal kalender tidak valid.',
      );
    }
    return (utc: wib.toUtc(), sourceTzLabel: 'WIB (lokal)', error: null);
  }

  static tz.Location? _resolveLocation(String tzid) {
    final cleaned = tzid.replaceAll('"', '').trim();
    final alias = _tzAliases[cleaned.toUpperCase()];
    final target = alias ?? cleaned;
    try {
      return tz.getLocation(target);
    } catch (_) {
      return null;
    }
  }

  static List<IcsImportedSegment> _splitToWibSegments(
    DateTime startUtc,
    DateTime endUtc,
    String label,
  ) {
    final segments = <IcsImportedSegment>[];
    var cursor = tz.TZDateTime.from(startUtc, jakarta);
    final endWib = tz.TZDateTime.from(endUtc, jakarta);

    while (cursor.isBefore(endWib)) {
      final nextMidnight = tz.TZDateTime(
        jakarta,
        cursor.year,
        cursor.month,
        cursor.day + 1,
      );
      final segmentEnd = endWib.isBefore(nextMidnight) ? endWib : nextMidnight;
      final startMin = cursor.hour * 60 + cursor.minute;
      final endMin = segmentEnd.isAtSameMomentAs(nextMidnight)
          ? 1440
          : segmentEnd.hour * 60 + segmentEnd.minute;

      if (endMin > startMin) {
        final dateStr =
            '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
        segments.add(
          IcsImportedSegment(
            date: dateStr,
            startMinute: startMin,
            endMinute: endMin,
            label: label,
          ),
        );
      }
      cursor = nextMidnight;
    }
    return segments;
  }

  static bool _isAlreadyImported({
    required List<IcsImportedSegment> segments,
    required List<Activity> existingActivities,
    required List<IcsImportCandidate> alreadyParsedCandidates,
  }) {
    if (segments.isEmpty) return false;
    final existingKeys = {
      for (final a in existingActivities)
        if (a.kind == ActivityKind.blocked && a.date != null)
          _segmentKey(a.date!, a.startMinute, a.endMinute, a.label),
      for (final c in alreadyParsedCandidates)
        for (final s in c.segments)
          _segmentKey(s.date, s.startMinute, s.endMinute, s.label),
    };
    return segments.every(
      (s) => existingKeys.contains(
        _segmentKey(s.date, s.startMinute, s.endMinute, s.label),
      ),
    );
  }

  static String _segmentKey(
    String date,
    int startMinute,
    int endMinute,
    String label,
  ) {
    return '$date|$startMinute|$endMinute|${label.trim().toLowerCase()}';
  }

  static _IcsProp? _parseProperty(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex <= 0) return null;
    final left = line.substring(0, colonIndex);
    final value = line.substring(colonIndex + 1);
    final parts = left.split(';');
    final name = parts.first.trim().toUpperCase();
    final params = <String, String>{};
    for (var i = 1; i < parts.length; i++) {
      final eq = parts[i].indexOf('=');
      if (eq > 0) {
        final k = parts[i].substring(0, eq).trim().toUpperCase();
        final v = parts[i].substring(eq + 1).trim();
        params[k] = v;
      }
    }
    return _IcsProp(name: name, params: params, value: value);
  }

  static String _unescapeText(String input) {
    return input
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\N', ' ')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\')
        .trim();
  }
}

class _IcsProp {
  final String name;
  final Map<String, String> params;
  final String value;

  const _IcsProp({
    required this.name,
    required this.params,
    required this.value,
  });
}
