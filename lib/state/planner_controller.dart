import 'package:flutter/foundation.dart';
import '../planner/fixtures.dart';
import '../planner/models.dart';

class PlannerController extends ChangeNotifier {
  PlannerSnapshot _snapshot;
  PlannerSnapshot get snapshot => _snapshot;
  SchedulePreview? preview;
  final DateTime Function() clock;
  PlannerController({PlannerSnapshot? initial, DateTime Function()? clock})
    : _snapshot = initial ?? demoSnapshot(),
      clock = clock ?? (() => demoNow);
  void resetDemo() {
    _snapshot = demoSnapshot();
    preview = null;
    notifyListeners();
  }

  void clear() {
    _snapshot = PlannerSnapshot(
      revision: 0,
      tasks: [],
      timeWindows: [],
      activities: [],
      sessions: [],
    );
    preview = null;
    notifyListeners();
  }
}
