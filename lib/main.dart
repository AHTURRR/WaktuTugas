import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app/app.dart';
import 'data/auth_storage.dart';
import 'data/cache.dart';
import 'data/planner_api.dart';
import 'data/supabase_client.dart';
import 'state/auth_controller.dart';
import 'state/planner_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  LocalCache? cache;
  const storage = SecureLocalStorage();
  if (SupabaseConfig.isConfigured) {
    await SupabaseConfig.initialize(localStorage: storage);
    cache = await LocalCache.initialize();
  }
  late final PlannerController planner;
  final auth = AuthController(
    client: SupabaseConfig.isConfigured ? SupabaseConfig.client : null,
    cache: cache,
    storage: SupabaseConfig.isConfigured ? storage : null,
    onSessionCleared: () => planner.clear(),
  );
  planner = PlannerController(
    clock: SupabaseConfig.isConfigured ? DateTime.now : null,
    api: SupabaseConfig.isConfigured ? PlannerApi(SupabaseConfig.client) : null,
    cache: cache,
    userId: auth.userId,
    onUnauthenticated: auth.handleUnauthenticated,
    connectivityStream: SupabaseConfig.isConfigured
        ? Connectivity().onConnectivityChanged
        : null,
  );
  await auth.restoreSession();
  runApp(WaktuTugasApp(auth: auth, planner: planner));
}
