import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_storage.dart';

class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lgjzoipinceatiitptyc.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Ygli6ZLlLOy614wJvpK26A_wORDcY3J',
  );

  static bool get isConfigured =>
      supabaseUrl.startsWith('http') &&
      !supabaseUrl.contains('placeholder') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('placeholder');

  static Future<void> initialize({
    String? url,
    String? anonKey,
    LocalStorage? localStorage,
  }) async {
    await Supabase.initialize(
      url: url ?? supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: anonKey ?? supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: localStorage ?? const SecureLocalStorage(),
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
