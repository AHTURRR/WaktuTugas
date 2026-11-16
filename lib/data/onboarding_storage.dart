import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan status penyelesaian/penundaan panduan awal per akun.
abstract class OnboardingStorage {
  Future<bool> isFinished(String userKey);
  Future<void> markFinished(String userKey);
}

class SecureOnboardingStorage implements OnboardingStorage {
  final FlutterSecureStorage _storage;

  const SecureOnboardingStorage([
    FlutterSecureStorage? storage,
  ]) : _storage = storage ?? const FlutterSecureStorage();

  String _keyFor(String userKey) => 'waktutugas.onboarding.$userKey';

  @override
  Future<bool> isFinished(String userKey) async {
    try {
      final value = await _storage.read(key: _keyFor(userKey));
      return value == 'done';
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> markFinished(String userKey) async {
    try {
      await _storage.write(key: _keyFor(userKey), value: 'done');
    } on Exception {
      // Abaikan kegagalan penulisan penyimpanan aman agar UI tetap responsif.
    }
  }
}

class MemoryOnboardingStorage implements OnboardingStorage {
  final Set<String> _finished = <String>{};

  @override
  Future<bool> isFinished(String userKey) async => _finished.contains(userKey);

  @override
  Future<void> markFinished(String userKey) async {
    _finished.add(userKey);
  }
}
