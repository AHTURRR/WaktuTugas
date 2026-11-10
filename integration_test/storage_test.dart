import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/data/auth_storage.dart';
import 'package:waktu_tugas/data/cache.dart';
import 'package:waktu_tugas/planner/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz.initializeTimeZones);

  testWidgets(
    'Android SecureLocalStorage and SQLite LocalCache persist and isolate per user',
    (tester) async {
      const storage = SecureLocalStorage();
      await storage.initialize();
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);

      await storage.persistSession('{"access_token":"device-test-session"}');
      expect(await storage.hasAccessToken(), isTrue);
      expect(
        await storage.accessToken(),
        '{"access_token":"device-test-session"}',
      );
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);

      final cache = await LocalCache.initialize(
        path: 'waktu_tugas_integration_test.db',
      );
      await cache.clearAll();
      final fetchedAt = DateTime.utc(2026, 11, 9, 11);
      await cache.writeCachedSnapshot('user-a', demoSnapshot(), fetchedAt);

      final hitA = await cache.readCachedSnapshot('user-a');
      expect(hitA, isNotNull);
      expect(hitA!.fetchedAt, fetchedAt);
      expect(hitA.snapshot.tasks.length, 3);
      expect(await cache.readCachedSnapshot('user-b'), isNull);

      await cache.clearCache('user-a');
      expect(await cache.readCachedSnapshot('user-a'), isNull);
    },
  );
}
