// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waktu_tugas/data/auth_storage.dart';
import 'package:waktu_tugas/data/cache.dart';
import 'package:waktu_tugas/planner/fixtures.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw Exception('Secure storage read error');
    return values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw Exception('Secure storage containsKey error');
    return values.containsKey(key);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw Exception('Secure storage write error');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) throw Exception('Secure storage delete error');
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCache implements LocalCache {
  final Map<String, CachedSnapshot> store = {};
  bool failClear = false;

  @override
  Future<CachedSnapshot?> readCachedSnapshot(String userId) async =>
      store[userId];

  @override
  Future<void> writeCachedSnapshot(
    String userId,
    snapshot,
    DateTime fetchedAt,
  ) async {
    store[userId] = CachedSnapshot(snapshot: snapshot, fetchedAt: fetchedAt);
  }

  @override
  Future<void> clearCache(String userId) async {
    if (failClear) throw Exception('Cache clear error');
    store.remove(userId);
  }

  @override
  Future<void> clearAll() async {
    if (failClear) throw Exception('Cache clearAll error');
    store.clear();
  }
}

class FakeAuthHttpClient extends http.BaseClient {
  http.Response Function(http.BaseRequest request) handler;
  FakeAuthHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = handler(request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      request: request,
    );
  }
}

Map<String, dynamic> _fakeSessionPayload({
  required String userId,
  required String email,
  String fullName = 'Mahasiswa Uji',
}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final exp =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': userId,
        'email': email,
        'role': 'authenticated',
        'exp': exp,
      }),
    ),
  );
  final token = '$header.$payload.signature';
  return {
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'refresh_token': 'refresh-$userId',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'app_metadata': {'provider': 'email'},
      'user_metadata': {'full_name': fullName},
      'created_at': '2026-11-09T00:00:00Z',
    },
  };
}

void main() {
  test(
    'SecureLocalStorage persists, checks, reads, and removes session string',
    () async {
      final raw = FakeSecureStorage();
      final storage = SecureLocalStorage(raw);
      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);

      await storage.persistSession('{"access_token":"secret-session"}');
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), '{"access_token":"secret-session"}');
      expect(raw.values[supabasePersistSessionKey], isNotNull);

      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    },
  );

  test(
    'AuthController signIn, register confirmation, offline logout, and storage failure',
    () async {
      final rawStorage = FakeSecureStorage();
      final storage = SecureLocalStorage(rawStorage);
      final cache = FakeCache();
      var signOutShouldFail = false;

      final httpClient = FakeAuthHttpClient((req) {
        final path = req.url.path;
        if (path.endsWith('/token')) {
          return http.Response(
            jsonEncode(
              _fakeSessionPayload(
                userId: '11111111-1111-1111-1111-111111111111',
                email: 'a@example.com',
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/signup')) {
          return http.Response(
            jsonEncode({
              'id': '22222222-2222-2222-2222-222222222222',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'baru@example.com',
              'app_metadata': {'provider': 'email'},
              'user_metadata': {'full_name': 'Mahasiswa Baru'},
              'created_at': '2026-11-09T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/resend')) {
          return http.Response(
            jsonEncode({'message_id': 'msg-1'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/logout')) {
          if (signOutShouldFail) {
            throw Exception('Network unreachable during logout');
          }
          return http.Response('', 204);
        }
        return http.Response('{}', 200);
      });

      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: httpClient,
      );
      addTearDown(client.dispose);

      final planner = PlannerController(initial: demoSnapshot());
      final auth = AuthController(
        client: client,
        cache: cache,
        storage: storage,
        onSessionCleared: planner.clear,
      );
      addTearDown(auth.dispose);

      // 1. Register when email confirmation is required: returns true, stays signedOut
      expect(
        await auth.register(
          'Mahasiswa Baru',
          'baru@example.com',
          'password123',
        ),
        isTrue,
      );
      expect(auth.signedIn, isFalse);
      expect(await auth.resendConfirmation('baru@example.com'), isTrue);

      // 2. SignIn persists session and updates user identity
      expect(await auth.signIn('a@example.com', 'password123'), isTrue);
      expect(auth.signedIn, isTrue);
      expect(auth.userId, '11111111-1111-1111-1111-111111111111');
      expect(auth.email, 'a@example.com');
      expect(auth.userName, 'Mahasiswa Uji');
      expect(await storage.hasAccessToken(), isTrue);

      await cache.writeCachedSnapshot(
        auth.userId!,
        demoSnapshot(),
        DateTime.utc(2026, 11, 9, 11),
      );
      expect(await cache.readCachedSnapshot(auth.userId!), isNotNull);

      // 3. If cache cleanup fails on logout, do not open next account with dirty cache
      cache.failClear = true;
      expect(await auth.logout(), isFalse);
      expect(auth.error, contains('Gagal membersihkan'));
      cache.failClear = false;

      // 4. Offline logout (server signOut throws network error) still cleans local session, cache, and memory
      signOutShouldFail = true;
      expect(await auth.logout(), isTrue);
      expect(auth.signedIn, isFalse);
      expect(auth.userId, isNull);
      expect(await storage.hasAccessToken(), isFalse);
      expect(
        await cache.readCachedSnapshot('11111111-1111-1111-1111-111111111111'),
        isNull,
      );
      expect(planner.snapshot.tasks, isEmpty);

      // 5. Storage failure blocks login and restoreSession without plaintext fallback
      rawStorage.failRead = true;
      await auth.restoreSession();
      expect(auth.signedIn, isFalse);
      expect(auth.error, contains('Penyimpanan sesi aman'));
      expect(await auth.signIn('a@example.com', 'password123'), isFalse);
      expect(auth.signedIn, isFalse);
      expect(auth.error, contains('Penyimpanan sesi aman'));
    },
  );
}
