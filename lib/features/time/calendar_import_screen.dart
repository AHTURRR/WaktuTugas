import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../planner/ics_import.dart';
import '../../state/planner_controller.dart';
import '../shared.dart';

class PickedIcsFile {
  final String name;
  final String content;

  const PickedIcsFile({required this.name, required this.content});
}

class _ImportSaveOutcome {
  final String summary;
  final bool succeeded;
  final String detail;

  const _ImportSaveOutcome({
    required this.summary,
    required this.succeeded,
    required this.detail,
  });
}

class CalendarImportScreen extends StatefulWidget {
  final PlannerController planner;
  final Future<PickedIcsFile?> Function()? pickIcsFile;

  const CalendarImportScreen({
    super.key,
    required this.planner,
    this.pickIcsFile,
  });

  @override
  State<CalendarImportScreen> createState() => _CalendarImportScreenState();
}

class _CalendarImportScreenState extends State<CalendarImportScreen> {
  String? fileName;
  String? parseError;
  IcsParseResult? parseResult;
  final Set<int> selectedIndices = <int>{};
  List<_ImportSaveOutcome> saveOutcomes = const [];
  bool isSaving = false;

  Future<PickedIcsFile?> _defaultPickIcsFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ics'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final content = await file.xFile.readAsString();
    return PickedIcsFile(name: file.name, content: content);
  }

  Future<void> _pickAndParse() async {
    try {
      final picked = await (widget.pickIcsFile ?? _defaultPickIcsFile)();
      if (picked == null || !mounted) return;

      const parser = IcsCalendarParser();
      final parsed = parser.parse(
        picked.content,
        existingActivities: widget.planner.snapshot.activities,
      );

      setState(() {
        fileName = picked.name;
        parseError = null;
        parseResult = parsed;
        saveOutcomes = const [];
        selectedIndices
          ..clear()
          ..addAll([
            for (var i = 0; i < parsed.candidates.length; i++)
              if (!parsed.candidates[i].isDuplicate) i,
          ]);
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        parseError = e.message;
        parseResult = null;
        selectedIndices.clear();
        saveOutcomes = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        parseError = 'File .ics tidak valid atau gagal dibaca.';
        parseResult = null;
        selectedIndices.clear();
        saveOutcomes = const [];
      });
    }
  }

  Future<void> _saveSelected() async {
    final parsed = parseResult;
    if (parsed == null || isSaving) return;

    setState(() {
      isSaving = true;
      saveOutcomes = const [];
    });

    final outcomes = <_ImportSaveOutcome>[];
    final sortedIndices = selectedIndices.toList()..sort();
    var counter = 0;

    for (final index in sortedIndices) {
      final candidate = parsed.candidates[index];
      if (candidate.isDuplicate) {
        outcomes.add(
          _ImportSaveOutcome(
            summary: candidate.summary,
            succeeded: false,
            detail: 'Dilewati karena sudah pernah diimpor.',
          ),
        );
        continue;
      }

      var allSaved = true;
      String? failReason;
      for (var s = 0; s < candidate.segments.length; s++) {
        final segment = candidate.segments[s];
        counter++;
        final id =
            'ics-${DateTime.now().microsecondsSinceEpoch}-$counter-$index-$s';
        final activity = segment.toBlockedActivity(id: id);
        final ok = await widget.planner.saveActivity(activity);
        if (!ok) {
          allSaved = false;
          failReason =
              widget.planner.error ?? 'Gagal menyimpan waktu terblokir.';
          break;
        }
      }

      outcomes.add(
        _ImportSaveOutcome(
          summary: candidate.summary,
          succeeded: allSaved,
          detail: allSaved
              ? 'Tersimpan sebagai waktu terblokir (${candidate.segments.length} segmen).'
              : failReason!,
        ),
      );
    }

    if (!mounted) return;
    // Tandai kandidat yang kini sudah ada di snapshot agar tidak diimpor ulang.
    final updatedCandidates = [
      for (var i = 0; i < parsed.candidates.length; i++)
        parsed.candidates[i].copyWith(
          isDuplicate:
              parsed.candidates[i].isDuplicate ||
              (sortedIndices.contains(i) &&
                  outcomes.any(
                    (o) =>
                        o.summary == parsed.candidates[i].summary &&
                        o.succeeded,
                  )),
        ),
    ];

    setState(() {
      isSaving = false;
      saveOutcomes = outcomes;
      parseResult = IcsParseResult(
        candidates: updatedCandidates,
        skipped: parsed.skipped,
      );
      selectedIndices.removeWhere((i) => updatedCandidates[i].isDuplicate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final parsed = parseResult;
    final offline = widget.planner.isOfflineSnapshot;
    final canSave =
        !isSaving &&
        !offline &&
        parsed != null &&
        selectedIndices.any((i) => !parsed.candidates[i].isDuplicate);

    return Scaffold(
      appBar: AppBar(title: const Text('Impor kalender')),
      body: PageContent(
        actions: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Tutup',
                secondary: true,
                onPressed: isSaving ? null : () => Navigator.pop(context),
              ),
            ),
            if (parsed != null && parsed.candidates.isNotEmpty) ...[
              const SizedBox(width: AppLayout.space12),
              Expanded(
                child: AppButton(
                  label: isSaving ? 'Menyimpan...' : 'Simpan terblokir',
                  onPressed: canSave ? _saveSelected : null,
                ),
              ),
            ],
          ],
        ),
        children: [
          const PageHeading(
            'Impor kalender (.ics)',
            'Pilih file .ics dari perangkat Anda, tinjau acara dalam WIB, lalu simpan pilihan sebagai waktu terblokir.',
          ),
          const SizedBox(height: AppLayout.space16),
          if (offline) ...[
            Notice(
              title: 'Mode luring',
              message:
                  'Penyimpanan waktu terblokir membutuhkan koneksi aktif. Anda tetap dapat meninjau isi file .ics.',
              color: colors.warningBg,
            ),
            const SizedBox(height: AppLayout.space16),
          ],
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Pilih file kalender',
                  subtitle: 'Impor satu arah dari file .ics ke WaktuTugas.',
                ),
                const SizedBox(height: AppLayout.space12),
                AppButton(
                  label: fileName == null
                      ? 'Pilih file .ics'
                      : 'Ganti file ($fileName)',
                  icon: 'imgCalendar',
                  secondary: fileName != null,
                  onPressed: isSaving ? null : _pickAndParse,
                ),
              ],
            ),
          ),
          if (parseError != null) ...[
            const SizedBox(height: AppLayout.space16),
            Notice(
              title: 'Gagal membaca file .ics',
              message: parseError!,
              color: colors.dangerBg,
            ),
          ],
          if (saveOutcomes.isNotEmpty) ...[
            const SizedBox(height: AppLayout.space16),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Hasil impor',
                    subtitle:
                        '${saveOutcomes.where((o) => o.succeeded).length} berhasil, ${saveOutcomes.where((o) => !o.succeeded).length} gagal.',
                  ),
                  const SizedBox(height: AppLayout.space12),
                  for (final outcome in saveOutcomes)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: outcome.succeeded
                            ? colors.primarySoft
                            : colors.dangerBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outcome.summary,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            outcome.detail,
                            style: TextStyle(
                              fontSize: 12,
                              color: outcome.succeeded
                                  ? colors.successInk
                                  : colors.dangerInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (parsed != null) ...[
            const SizedBox(height: AppLayout.space16),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Acara terbaca (${parsed.candidates.length})',
                    subtitle:
                        'Waktu sudah dikonversi ke WIB. Centang acara yang ingin disimpan sebagai penutupan.',
                  ),
                  const SizedBox(height: AppLayout.space12),
                  if (parsed.candidates.isEmpty)
                    Text(
                      'Tidak ada acara bertanda jam yang siap diimpor dari file ini.',
                      style: TextStyle(fontSize: 13, color: colors.inkMuted),
                    )
                  else
                    for (var i = 0; i < parsed.candidates.length; i++)
                      _CandidateRow(
                        candidate: parsed.candidates[i],
                        selected: selectedIndices.contains(i),
                        onChanged: parsed.candidates[i].isDuplicate || isSaving
                            ? null
                            : (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedIndices.add(i);
                                  } else {
                                    selectedIndices.remove(i);
                                  }
                                });
                              },
                      ),
                ],
              ),
            ),
            if (parsed.skipped.isNotEmpty) ...[
              const SizedBox(height: AppLayout.space16),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Acara dilewati (${parsed.skipped.length})',
                      subtitle:
                          'Acara berikut tidak dapat diimpor pada versi pertama.',
                    ),
                    const SizedBox(height: AppLayout.space12),
                    for (final item in parsed.skipped)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.warningBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.summary,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.reason,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.warningInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final IcsImportCandidate candidate;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: candidate.isDuplicate ? colors.surfaceMuted : colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: selected, onChanged: onChanged),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        candidate.summary,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    if (candidate.isDuplicate)
                      const StatusBadge(
                        'Sudah pernah diimpor',
                        tone: StatusTone.neutral,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final seg in candidate.segments)
                  Text(
                    '${seg.date} · ${timeLabel(seg.startMinute)}–${timeLabel(seg.endMinute)} WIB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.inkSecondary,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'Zona sumber: ${candidate.sourceTimeZone}',
                  style: TextStyle(fontSize: 11, color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
