import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app/app.dart';
import 'data/cache.dart';
import 'data/planner_api.dart';
import 'data/supabase_client.dart';
import 'state/auth_controller.dart';
import 'state/planner_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  LocalCache? cache;
  if (SupabaseConfig.isConfigured) {
    await SupabaseConfig.initialize();
    cache = await LocalCache.initialize();
  }
  final auth = AuthController(
    client: SupabaseConfig.isConfigured ? SupabaseConfig.client : null,
    cache: cache,
  );
  await auth.restoreSession();
  final planner = PlannerController(
    api: SupabaseConfig.isConfigured ? PlannerApi(SupabaseConfig.client) : null,
    cache: cache,
    userId: auth.userId,
  );
  runApp(WaktuTugasApp(auth: auth, planner: planner));
}
