// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/cache.dart';

class AuthController extends ChangeNotifier {
  final SupabaseClient? _client;
  final LocalCache? _cache;
  bool _signedIn = false;
  String? _userId;
  String? error;
  bool get signedIn => _signedIn;
  String? get userId => _userId;
  bool get isCloud => _client != null;
  String? get email => _client?.auth.currentUser?.email;
  String? get userName {
    final value = _client?.auth.currentUser?.userMetadata?['full_name'];
    return value is String ? value : null;
  }

  AuthController({SupabaseClient? client, LocalCache? cache})
    : _client = client,
      _cache = cache {
    _client?.auth.onAuthStateChange.listen((data) {
      _applySession(data.session);
    });
  }

  Future<void> restoreSession() async {
    _applySession(_client?.auth.currentSession);
  }

  void _applySession(Session? session) {
    _userId = session?.user.id;
    _signedIn = session != null;
    notifyListeners();
  }

  void enterDemo() {
    error = null;
    _userId = null;
    _signedIn = true;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    final client = _client;
    if (client == null) return false;
    error = null;
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      error = 'Layanan belum dapat dihubungi. Periksa koneksi lalu coba lagi.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    final client = _client;
    if (client == null) return false;
    error = null;
    try {
      await client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      return true;
    } on AuthException catch (e) {
      error = e.message;
    } catch (_) {
      error =
          'Pendaftaran belum terkonfirmasi. Periksa email sebelum mencoba lagi.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> resendConfirmation(String email) async {
    final client = _client;
    if (client == null) return false;
    error = null;
    try {
      await client.auth.resend(type: OtpType.signup, email: email);
      return true;
    } on AuthException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Email belum dapat dikirim. Periksa koneksi lalu coba lagi.';
    }
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    final id = _userId;
    if (_client != null) {
      await _client.auth.signOut();
    }
    if (id != null) await _cache?.clearCache(id);
    _userId = null;
    _signedIn = false;
    notifyListeners();
  }
}
