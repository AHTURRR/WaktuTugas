// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/cache.dart';

class AuthController extends ChangeNotifier {
  final SupabaseClient? _client;
  final LocalCache? _cache;
  final LocalStorage? _storage;
  final VoidCallback? _onSessionCleared;
  StreamSubscription<AuthState>? _authSub;
  bool _signedIn = false;
  bool _isDemo = false;
  bool _storageFailed = false;
  String? _userId;
  String? error;
  bool get signedIn => _signedIn;
  bool get isDemo => _isDemo;
  String? get userId => _userId;
  bool get isCloud => _client != null && !_isDemo;
  String? get email => _isDemo ? null : _client?.auth.currentUser?.email;
  String? get userName {
    if (_isDemo) return null;
    final value = _client?.auth.currentUser?.userMetadata?['full_name'];
    return value is String ? value : null;
  }

  AuthController({
    SupabaseClient? client,
    LocalCache? cache,
    LocalStorage? storage,
    VoidCallback? onSessionCleared,
  }) : _client = client,
       _cache = cache,
       _storage = storage,
       _onSessionCleared = onSessionCleared {
    _authSub = _client?.auth.onAuthStateChange.listen((data) {
      if (_storageFailed) return;
      _applySession(data.session);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> restoreSession() async {
    final storage = _storage;
    if (storage != null) {
      try {
        await storage.initialize();
        await storage.hasAccessToken();
        _storageFailed = false;
      } catch (_) {
        _storageFailed = true;
        _signedIn = false;
        _userId = null;
        error =
            'Penyimpanan sesi aman gagal diakses. Masuk dinonaktifkan demi keamanan.';
        notifyListeners();
        return;
      }
    }
    _applySession(_client?.auth.currentSession);
  }

  void _applySession(Session? session) {
    final prevUserId = _userId;
    final nextUserId = session?.user.id;
    if (prevUserId != null && prevUserId != nextUserId) {
      _onSessionCleared?.call();
    }
    if (session != null) {
      _isDemo = false;
    }
    _userId = nextUserId;
    _signedIn = session != null;
    notifyListeners();
  }

  void enterDemo() {
    error = null;
    _isDemo = true;
    _userId = null;
    _signedIn = true;
    notifyListeners();
  }

  static String _mapAuthMessage(AuthException e) {
    final lower = e.message.toLowerCase();
    if (lower.contains('email not confirmed') ||
        e.code == 'email_not_confirmed') {
      return 'Email belum dikonfirmasi. Periksa kotak masuk email Anda.';
    }
    if (lower.contains('invalid login credentials') ||
        e.code == 'invalid_credentials') {
      return 'Email atau kata sandi tidak sesuai.';
    }
    return e.message;
  }

  Future<bool> signIn(String email, String password) async {
    final client = _client;
    if (client == null) return false;
    error = null;
    final storage = _storage;
    if (storage != null) {
      try {
        await storage.hasAccessToken();
        _storageFailed = false;
      } catch (_) {
        _storageFailed = true;
        error =
            'Penyimpanan sesi aman gagal diakses. Masuk dinonaktifkan demi keamanan.';
        notifyListeners();
        return false;
      }
    }
    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (storage != null && res.session != null) {
        await storage.persistSession(jsonEncode(res.session!.toJson()));
      }
      _isDemo = false;
      _applySession(res.session ?? client.auth.currentSession);
      return true;
    } on AuthException catch (e) {
      error = _mapAuthMessage(e);
      notifyListeners();
      return false;
    } catch (_) {
      if (_storageFailed) {
        error =
            'Penyimpanan sesi aman gagal diakses. Masuk dinonaktifkan demi keamanan.';
      } else {
        error =
            'Layanan belum dapat dihubungi. Periksa koneksi lalu coba lagi.';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    final client = _client;
    if (client == null) return false;
    error = null;
    final storage = _storage;
    if (storage != null) {
      try {
        await storage.hasAccessToken();
        _storageFailed = false;
      } catch (_) {
        _storageFailed = true;
        error =
            'Penyimpanan sesi aman gagal diakses. Pendaftaran dinonaktifkan demi keamanan.';
        notifyListeners();
        return false;
      }
    }
    try {
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      _isDemo = false;
      if (res.session != null) {
        _applySession(res.session);
      }
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      error = _mapAuthMessage(e);
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
      error = _mapAuthMessage(e);
    } catch (_) {
      error = 'Email belum dapat dikirim. Periksa koneksi lalu coba lagi.';
    }
    notifyListeners();
    return false;
  }

  void handleUnauthenticated() {
    logout();
  }

  Future<bool> logout() async {
    final id = _userId;
    error = null;
    if (_client != null) {
      try {
        await _client.auth.signOut();
      } catch (_) {
        try {
          await _client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
      }
    }
    try {
      if (_storage != null) {
        await _storage.removePersistedSession();
      }
      if (id != null) {
        await _cache?.clearCache(id);
      } else {
        await _cache?.clearAll();
      }
    } catch (_) {
      error =
          'Gagal membersihkan cache atau sesi lokal. Coba keluar lagi sebelum berganti akun.';
      notifyListeners();
      return false;
    }
    _onSessionCleared?.call();
    _isDemo = false;
    _userId = null;
    _signedIn = false;
    notifyListeners();
    return true;
  }
}
