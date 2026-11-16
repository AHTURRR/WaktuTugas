import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/tasks/task_form_screen.dart';
import 'package:waktu_tugas/features/tasks/tasks_screen.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/schedule.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('id_ID');
  });

  final now = DateTime.utc(2026, 6, 1, 2, 0); // 09:00 WIB

  test(
    'tugas lama tanpa field subtasks tetap terbaca valid dan memiliki daftar subtugas kosong',
    () {
      final legacyJson = {
        'id': 'legacy-1',
        'title': 'Tugas Lama',
        'course': 'Algoritma',
        'deadline_at': '2026-06-03T16:59:00Z',
        'remaining_minutes': 90,
        'created_at': '2026-05-30T00:00:00Z',
      };
      final task = Task.fromJson(legacyJson);
      expect(task.subtasks, isEmpty);
      expect(task.subtaskProgressLabel, '0 dari 0 selesai');
      expect(Task.fromJson(task.toJson()).subtasks, isEmpty);
    },
  );

  testWidgets(
    'Tambah, ubah nama, tandai selesai (2 dari 4 selesai), hapus subtugas, serta perbarui estimasi induk untuk penjadwalan',
    (tester) async {
      final initialTask = Task(
        id: 't1',
        title: 'Laporan Akhir',
        course: 'Rekayasa Perangkat Lunak',
        remainingMinutes: 120,
        deadlineAt: DateTime.utc(2026, 6, 2, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
      );
      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [initialTask],
          timeWindows: [
            TimeWindow(
              id: 'w1',
              date: '2026-06-01',
              startMinute: 1140, // 19:00
              endMinute: 1320, // 22:00 (180 menit kapasitas)
            ),
          ],
          activities: [],
          sessions: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: TaskFormScreen(planner: planner, taskId: 't1'),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tugas awalnya belum punya subtugas
      expect(find.text('Belum ada subtugas pada tugas ini.'), findsOneWidget);

      // 2. Tambah 4 subtugas
      for (final name in ['Bab 1', 'Bab 2', 'Bab 3', 'Daftar Pustaka']) {
        await tester.ensureVisible(find.byKey(const Key('new-subtask-title')));
        await tester.enterText(
          find.byKey(const Key('new-subtask-title')),
          name,
        );
        await tester.ensureVisible(find.text('Tambah subtugas'));
        await tester.tap(find.text('Tambah subtugas'));
        await tester.pumpAndSettle();
      }

      expect(find.text('0 dari 4 selesai'), findsOneWidget);

      // 3. Tandai 2 subtugas selesai -> menampilkan "2 dari 4 selesai"
      final subtasks = planner.taskById('t1')!.subtasks;
      await tester.ensureVisible(
        find.byKey(Key('toggle-subtask-${subtasks[0].id}')),
      );
      await tester.tap(find.byKey(Key('toggle-subtask-${subtasks[0].id}')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(Key('toggle-subtask-${subtasks[1].id}')),
      );
      await tester.tap(find.byKey(Key('toggle-subtask-${subtasks[1].id}')));
      await tester.pumpAndSettle();

      expect(find.text('2 dari 4 selesai'), findsOneWidget);
      expect(find.text('Subtugas selesai'), findsOneWidget);

      // Pastikan penjadwalan masih memakai estimasi induk (120 menit), bukan checklist
      final previewBeforeEstimateUpdate = buildPreview(
        planner.snapshot,
        planner.now,
      );
      expect(
        previewBeforeEstimateUpdate.sessions.single.endsAt
            .difference(previewBeforeEstimateUpdate.sessions.single.startsAt)
            .inMinutes,
        120,
      );

      // 4. Ubah nama subtugas ke-3 ("Bab 3" -> "Bab 3 Revisi")
      final thirdId = subtasks[2].id;
      await tester.ensureVisible(find.byKey(Key('rename-subtask-$thirdId')));
      await tester.tap(find.byKey(Key('rename-subtask-$thirdId')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(Key('edit-subtask-$thirdId')),
        'Bab 3 Revisi',
      );
      await tester.tap(find.byKey(Key('save-rename-subtask-$thirdId')));
      await tester.pumpAndSettle();
      expect(find.text('Bab 3 Revisi'), findsOneWidget);

      // 5. Hapus subtugas ke-4 ("Daftar Pustaka")
      final fourthId = subtasks[3].id;
      await tester.ensureVisible(find.byKey(Key('delete-subtask-$fourthId')));
      await tester.tap(find.byKey(Key('delete-subtask-$fourthId')));
      await tester.pumpAndSettle();
      expect(find.text('Daftar Pustaka'), findsNothing);
      expect(find.text('2 dari 3 selesai'), findsOneWidget);

      // 6. Perbarui estimasi induk lewat alur yang sudah ada (120 -> 60 menit) lalu Simpan tugas
      await tester.ensureVisible(find.byKey(const Key('remaining')));
      await tester.enterText(find.byKey(const Key('remaining')), '60');
      await tester.tap(find.text('Simpan tugas'));
      await tester.pumpAndSettle();

      final updatedTask = planner.taskById('t1')!;
      expect(updatedTask.remainingMinutes, 60);
      expect(updatedTask.subtasks.length, 3);
      expect(updatedTask.subtaskProgressLabel, '2 dari 3 selesai');

      // Penjadwalan sesudah estimasi induk diperbarui memakai 60 menit terbaru
      final previewAfter = buildPreview(planner.snapshot, planner.now);
      expect(
        previewAfter.sessions.single.endsAt
            .difference(previewAfter.sessions.single.startsAt)
            .inMinutes,
        60,
      );
    },
  );

  testWidgets(
    'Checklist dan estimasi waktu tampil terpisah di daftar tugas, penghapusan induk menghapus subtugas, dan isolasi antar akun terjaga',
    (tester) async {
      final taskWithSubtasks = Task(
        id: 't1',
        title: ' Proyek Basis Data',
        remainingMinutes: 90,
        deadlineAt: DateTime.utc(2026, 6, 2, 16, 59),
        createdAt: DateTime.utc(2026, 5, 30),
        subtasks: [
          Subtask(
            id: 'st-1',
            taskId: 't1',
            title: 'Skema Tabel',
            isCompleted: true,
          ),
          Subtask(
            id: 'st-2',
            taskId: 't1',
            title: 'Migrasi RPC',
            isCompleted: false,
          ),
        ],
      );

      final planner = PlannerController(
        clock: () => now,
        initial: PlannerSnapshot(
          revision: 1,
          tasks: [taskWithSubtasks],
          timeWindows: [],
          activities: [],
          sessions: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: Brightness.light),
          home: Scaffold(body: TasksScreen(planner: planner)),
        ),
      );
      await tester.pumpAndSettle();

      // Checklist ("Subtugas: 1 dari 2 selesai") dan estimasi ("90 menit tersisa") tampil terpisah
      expect(find.text('90 menit tersisa'), findsOneWidget);
      expect(find.text('Subtugas: 1 dari 2 selesai'), findsOneWidget);

      // Penghapusan tugas induk menghapus tugas beserta subtugasnya
      await tester.runAsync(() async {
        await planner.deleteTask('t1', confirmed: true);
      });
      await tester.pumpAndSettle();
      expect(planner.snapshot.tasks, isEmpty);
      expect(find.text('Subtugas: 1 dari 2 selesai'), findsNothing);

      // Isolasi akun: saat berganti akun, data tugas & subtugas akun sebelumnya dibersihkan
      await tester.runAsync(() async {
        await planner.saveTask(
          title: 'Tugas Akun A',
          course: null,
          deadline: DateTime.utc(2026, 6, 3, 12, 0),
          remaining: 60,
        );
        final createdId = planner.snapshot.tasks.single.id;
        await planner.saveSubtask(
          taskId: createdId,
          title: 'Subtugas Rahasia Akun A',
          isCompleted: false,
        );
      });
      expect(planner.snapshot.tasks.single.subtasks.length, 1);

      // Berganti ke akun B -> tidak boleh melihat tugas/subtugas akun A
      planner.bindUser('user-b');
      await tester.pumpAndSettle();
      expect(planner.snapshot.tasks, isEmpty);

      // Upaya mengubah subtugas milik akun A dari state akun B ditolak
      late bool crossAttempt;
      await tester.runAsync(() async {
        crossAttempt = await planner.saveSubtask(
          taskId: 'task-2',
          subtaskId: 'subtask-3-1',
          title: 'Retas',
          isCompleted: true,
        );
      });
      expect(crossAttempt, isFalse);
      expect(planner.error, contains('Tugas tidak ditemukan'));
    },
  );
}
