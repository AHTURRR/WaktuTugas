import 'package:flutter_test/flutter_test.dart';
import 'package:waktu_tugas/planner/models.dart';
import 'package:waktu_tugas/planner/intervals.dart';

Interval slot(int start, int end) =>
    Interval(DateTime.utc(2026, 11, 9, start), DateTime.utc(2026, 11, 9, end));
void main() {
  test('merge_overlap and adjacency do not double count', () {
    final result = mergeIntervals([slot(21, 23), slot(19, 22), slot(23, 24)]);
    expect(result.length, 1);
    expect(result.single.minutes, 300);
    expect(mergeIntervals([slot(19, 22), slot(21, 23)]).single.minutes, 240);
  });
  test('subtract_busy produces 180 minutes in two intervals', () {
    final result = subtractIntervals(
      [slot(19, 22), slot(21, 23)],
      [slot(20, 21)],
    );
    expect(result.map((v) => v.toJson()), [
      slot(19, 20).toJson(),
      slot(21, 23).toJson(),
    ]);
    expect(result.fold(0, (int n, v) => n + v.minutes), 180);
  });
  test('closures cover whole slots, edges, and overlapping busy windows', () {
    expect(subtractIntervals([slot(19, 20)], [slot(18, 21)]), isEmpty);
    expect(
      subtractIntervals([slot(19, 20)], [slot(20, 21)]).single.minutes,
      60,
    );
    expect(
      subtractIntervals(
        [slot(18, 24)],
        [slot(19, 21), slot(20, 22)],
      ).map((v) => v.minutes),
      [60, 120],
    );
    expect(subtractIntervals([], [slot(19, 20)]), isEmpty);
  });
}
