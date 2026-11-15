import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:waktu_tugas/data/planner_api.dart';
import 'package:waktu_tugas/data/supabase_client.dart';
import 'package:waktu_tugas/features/shared.dart';
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/main.dart' as app;
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: task CRUD against a disposable Supabase account', (
    tester,
  ) async {
    const email = String.fromEnvironment('WAKTUTUGAS_TEST_A_EMAIL');
    const password = String.fromEnvironment('WAKTUTUGAS_TEST_A_PASSWORD');
    final uri = Uri.parse(SupabaseConfig.supabaseUrl);
    expect(['10.0.2.2', '127.0.0.1', 'localhost'], contains(uri.host));
    expect(email, isNotEmpty);
    expect(password, isNotEmpty);

    PlannerApi api() => PlannerApi(SupabaseConfig.client);
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> tasks() => tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Tugas'),
          )
          .first,
    );

    Future<void> fill(Finder finder, String value) async {
      await tester.ensureVisible(finder);
      await tester.enterText(finder, value);
      await tester.pumpAndSettle();
    }

    void expectTask(Task task) {
      expect(find.text(task.title), findsOneWidget);
      if (task.course case final course?) {
        expect(find.text(course), findsOneWidget);
      }
      expect(
        find.text('Tenggat ${dateTimeLabel(task.deadlineAt)}'),
        findsOneWidget,
      );
      expect(
        find.text('${task.remainingMinutes} menit tersisa'),
        findsOneWidget,
      );
    }

    await app.main();
    await tester.pumpAndSettle();
    // Prior integration runs can leave a session in the debug app.
    if (SupabaseConfig.client.auth.currentSession != null) {
      await SupabaseConfig.client.auth.signOut();
      await tester.pumpAndSettle();
    }
    await fill(find.widgetWithText(TextFormField, 'Email'), email);
    await fill(find.widgetWithText(TextFormField, 'Kata sandi'), password);
    await tap(find.widgetWithText(AppButton, 'Masuk'));
    expect(
      SupabaseConfig.client.auth.currentUser?.email,
      email,
      reason: tester
          .widget<WaktuTugasApp>(find.byType(WaktuTugasApp))
          .auth
          .error,
    );
    await tasks();
    final initial = await api().fetchSnapshot();
    expect(initial.tasks, isEmpty, reason: 'Use a fresh test account.');

    final title = find.byKey(const Key('title'));
    final course = find.widgetWithText(TextFormField, 'Mata kuliah (opsional)');
    final minutes = find.byKey(const Key('remaining'));
    final save = find.text('Simpan tugas');
    await tap(find.byTooltip('Tambah tugas'));
    await fill(title, '   ');
    await fill(minutes, '-1');
    await tap(save);
    expect(find.text('Nama wajib diisi.'), findsOneWidget);
    expect(find.text('Masukkan menit bulat positif.'), findsOneWidget);
    final rejected = await api().fetchSnapshot();
    expect(rejected.revision, initial.revision);
    expect(rejected.tasks, isEmpty);

    final datePicker = find.byType(PickerField).first;
    final timePicker = find.byType(PickerField).last;
    final date = tester.widget<PickerField>(datePicker).value;
    final time = tester.widget<PickerField>(timePicker).value;
    await fill(title, '  Tugas CRUD  ');
    await fill(course, '  Basis Data  ');
    await fill(minutes, '35');
    await tap(save);
    var saved = (await api().fetchSnapshot()).tasks.single;
    expect(saved.title, 'Tugas CRUD');
    expect(saved.course, 'Basis Data');
    expect(saved.remainingMinutes, 35);
    expectTask(saved);

    await tap(find.byTooltip('Ubah Tugas CRUD'));
    expect(tester.widget<PickerField>(datePicker).value, date);
    expect(tester.widget<PickerField>(timePicker).value, time);
    final localDeadline = tz.TZDateTime.from(saved.deadlineAt, jakarta);
    final nextMonth = DateTime(localDeadline.year, localDeadline.month + 1);
    await tap(datePicker);
    final dialog = find.byType(DatePickerDialog);
    final labels = MaterialLocalizations.of(tester.element(dialog));
    await tap(find.byTooltip(labels.nextMonthTooltip));
    await tap(find.descendant(of: dialog, matching: find.text('12')));
    await tap(find.text(labels.okButtonLabel));
    await fill(title, 'Tugas CRUD revisi');
    await fill(course, 'Sistem Informasi');
    await fill(minutes, '45');
    await tap(save);
    final edited = (await api().fetchSnapshot()).tasks.single;
    expect(edited.id, saved.id);
    expect(edited.title, 'Tugas CRUD revisi');
    expect(edited.course, 'Sistem Informasi');
    expect(edited.remainingMinutes, 45);
    final editedDeadline = tz.TZDateTime(
      jakarta,
      nextMonth.year,
      nextMonth.month,
      12,
      localDeadline.hour,
      localDeadline.minute,
    );
    expect(edited.deadlineAt.isAtSameMomentAs(editedDeadline), isTrue);
    expect(find.text(saved.title), findsNothing);
    expectTask(edited);

    // Prepare a real related session through the same planner API.
    final now = DateTime.now();
    final wib = tz.TZDateTime.from(now, jakarta);
    final tomorrow = DateTime(wib.year, wib.month, wib.day + 1);
    await api().saveTimeWindow(
      date: tomorrow.toIso8601String().split('T').first,
      startMinute: 480,
      endMinute: 600,
      expectedRevision: (await api().fetchSnapshot()).revision,
    );
    await api().confirmSchedule(
      preview: buildPreview(await api().fetchSnapshot(), now),
    );
    final beforeDelete = await api().fetchSnapshot();
    expect(beforeDelete.sessions.single.taskId, edited.id);

    // Reload production bootstrap and restore the session from secure storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await Supabase.instance.dispose();
    await app.main();
    await tester.pumpAndSettle();
    expect(SupabaseConfig.client.auth.currentUser?.email, email);
    await tasks();
    expectTask(edited);

    final remove = find.byTooltip('Hapus Tugas CRUD revisi');
    await tap(remove);
    await tap(find.text('Batal'));
    expectTask(edited);
    final afterCancel = await api().fetchSnapshot();
    expect(afterCancel.revision, beforeDelete.revision);
    expect(afterCancel.tasks.single.id, edited.id);
    expect(afterCancel.sessions.single.id, beforeDelete.sessions.single.id);

    await tap(remove);
    await tap(find.text('Hapus tugas dan sesi'));
    expect(find.text(edited.title), findsNothing);
    final afterDelete = await api().fetchSnapshot();
    expect(afterDelete.tasks, isEmpty);
    expect(afterDelete.sessions, isEmpty);
    expect(afterDelete.revision, beforeDelete.revision + 1);
  });
}
