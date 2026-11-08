import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/fixtures.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  Future<PlannerController> confirmed() async {
    final p = PlannerController();
    expect(await p.generatePreview(), isTrue);
    expect(await p.confirmSchedule(), isTrue);
    return p;
  }

  test('missed_preserves_remaining and double_close_rejected', () async {
    final p = await confirmed();
    p.advanceDemoClock();
    final id = p.snapshot.sessions.first.id;
    expect(await p.recordProgress(id, SessionStatus.missed, null), isTrue);
    expect(p.snapshot.tasks.first.remainingMinutes, 240);
    final rev = p.snapshot.revision;
    expect(await p.recordProgress(id, SessionStatus.completed, 90), isFalse);
    expect(p.snapshot.revision, rev);
  });
  test('completed_remaining_90 and increased_estimate_allowed', () async {
    for (final remaining in [90, 300]) {
      final p = await confirmed();
      p.advanceDemoClock();
      expect(
        await p.recordProgress(
          p.snapshot.sessions.first.id,
          SessionStatus.completed,
          remaining,
        ),
        isTrue,
      );
      expect(p.snapshot.tasks.first.remainingMinutes, remaining);
      expect(p.snapshot.sessions.first.status, SessionStatus.completed);
    }
  });
  test('started_planned_blocks_preview and future progress rejected', () async {
    final p = await confirmed();
    expect(
      await p.recordProgress(
        p.snapshot.sessions.first.id,
        SessionStatus.missed,
        null,
      ),
      isFalse,
    );
    p.advanceDemoClock();
    expect(await p.generatePreview(), isFalse);
    expect(p.error, contains('Tutup progres'));
  });
  test(
    'stale preview and elapsed candidate preserve existing schedule',
    () async {
      final p = await confirmed();
      await p.generatePreview();
      final before = p.snapshot.sessions.map((s) => s.toJson()).toList();
      await p.saveTask(
        id: 'T01',
        title: 'Perubahan',
        course: null,
        deadline: demoSnapshot().tasks.first.deadlineAt,
        remaining: 240,
      );
      expect(await p.confirmSchedule(), isFalse);
      expect(p.snapshot.sessions.map((s) => s.toJson()).toList(), before);
      final q = PlannerController();
      await q.generatePreview();
      q.advanceDemoClock();
      expect(await q.confirmSchedule(), isFalse);
      expect(q.snapshot.sessions, isEmpty);
    },
  );
  test(
    'reschedule keeps completed/missed history and cancels future planned',
    () async {
      for (final status in [SessionStatus.completed, SessionStatus.missed]) {
        final p = await confirmed();
        p.advanceDemoClock();
        final id = p.snapshot.sessions.first.id;
        await p.recordProgress(
          id,
          status,
          status == SessionStatus.completed ? 180 : null,
        );
        final old = p.snapshot.sessions.first.toJson();
        expect(await p.generatePreview(), isTrue);
        expect(await p.confirmSchedule(), isTrue);
        expect(p.snapshot.sessions.first.toJson(), old);
        expect(
          p.snapshot.sessions
              .where((s) => s.status == SessionStatus.cancelled)
              .length,
          4,
        );
        expect(
          p.snapshot.sessions.firstWhere((s) => s.id == id).status,
          status,
        );
      }
    },
  );
  test(
    'pending duplicate confirm, invalid save, delete cancel/confirm are atomic',
    () async {
      final p = PlannerController();
      await p.generatePreview();
      final first = p.confirmSchedule();
      expect(p.isPending, isTrue);
      expect(await p.confirmSchedule(), isFalse);
      expect(await first, isTrue);
      final rev = p.snapshot.revision;
      expect(
        await p.saveTask(
          title: ' ',
          course: null,
          deadline: demoNow,
          remaining: -1,
        ),
        isFalse,
      );
      expect(p.snapshot.revision, rev);
      expect(await p.deleteTask('T01', confirmed: false), isFalse);
      expect(p.snapshot.revision, rev);
      expect(await p.deleteTask('T01', confirmed: true), isTrue);
      expect(p.snapshot.sessions.where((s) => s.taskId == 'T01'), isEmpty);
      expect(p.snapshot.tasks.where((t) => t.id == 'T01'), isEmpty);
    },
  );
}
