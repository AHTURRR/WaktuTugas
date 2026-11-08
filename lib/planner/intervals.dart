import 'models.dart';

List<Interval> mergeIntervals(List<Interval> intervals) {
  final sorted = [...intervals]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <Interval>[];
  for (final item in sorted) {
    if (merged.isEmpty || item.start.isAfter(merged.last.end)) {
      merged.add(item);
    } else if (item.end.isAfter(merged.last.end)) {
      merged[merged.length - 1] = Interval(merged.last.start, item.end);
    }
  }
  return merged;
}

List<Interval> subtractIntervals(List<Interval> allowed, List<Interval> busy) {
  final result = <Interval>[];
  final blocks = mergeIntervals(busy);
  for (final slot in mergeIntervals(allowed)) {
    var cursor = slot.start;
    for (final block in blocks) {
      if (!block.end.isAfter(cursor)) continue;
      if (!block.start.isBefore(slot.end)) break;
      if (block.start.isAfter(cursor)) {
        result.add(Interval(cursor, block.start));
      }
      if (block.end.isAfter(cursor)) cursor = block.end;
      if (!cursor.isBefore(slot.end)) break;
    }
    if (cursor.isBefore(slot.end)) result.add(Interval(cursor, slot.end));
  }
  return result;
}
