import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app/app.dart';
import 'state/auth_controller.dart';
import 'state/planner_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(WaktuTugasApp(auth: AuthController(), planner: PlannerController()));
}
