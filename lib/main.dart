import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app/app.dart';
import 'data/auth_storage.dart';
import 'data/cache.dart';
import 'data/planner_api.dart';
import 'data/supabase_client.dart';
import 'data/whatsapp_api.dart';
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
  const preferences = FlutterSecureStorage();
  const themeKey = 'waktutugas.appearance';
  var themeMode = ThemeMode.system;
  try {
    themeMode = switch (await preferences.read(key: themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  } on Exception {
    debugPrint('Preferensi tema tidak dapat dibaca.');
  }
  var pendingThemeWrite = Future<void>.value();
  runApp(
    WaktuTugasApp(
      auth: auth,
      planner: planner,
      whatsapp: SupabaseConfig.isConfigured
          ? WhatsAppApi(SupabaseConfig.client)
          : null,
      initialThemeMode: themeMode,
      onThemeModeChanged: (mode) {
        pendingThemeWrite = pendingThemeWrite.then((_) async {
          try {
            await preferences.write(key: themeKey, value: mode.name);
          } on Exception {
            debugPrint('Preferensi tema tidak dapat disimpan.');
          }
        });
      },
    ),
  );
}
