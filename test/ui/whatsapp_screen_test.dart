import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/data/whatsapp_api.dart';
import 'package:waktu_tugas/features/auth/account_screen.dart';
import 'package:waktu_tugas/state/auth_controller.dart';

class _CloudAccount extends AuthController {
  @override
  bool get isCloud => true;
  @override
  bool get signedIn => true;
  @override
  String get userId => 'account-a';
}

class _ReminderApi implements WhatsAppApi {
  WhatsAppSettings settings = (
    phone: null,
    verified: false,
    enabled: false,
    awaitingCode: false,
  );
  final actions = <String>[];

  @override
  Future<WhatsAppSettings> update(
    String action, {
    String? phone,
    String? code,
    bool? enabled,
  }) async {
    actions.add(action);
    settings = switch (action) {
      'request_code' => (
        phone: '+62••••0001',
        verified: false,
        enabled: false,
        awaitingCode: true,
      ),
      'verify_code' when code == '123456' => (
        phone: settings.phone,
        verified: true,
        enabled: false,
        awaitingCode: false,
      ),
      'verify_code' => throw WhatsAppApiException('wrong_code', settings),
      'enable' => (
        phone: settings.phone,
        verified: settings.verified,
        enabled: enabled!,
        awaitingCode: false,
      ),
      _ => settings,
    };
    return settings;
  }
}

void main() {
  testWidgets(
    'account entry, verification, opt-in, opt-out and number change',
    (t) async {
      t.view.physicalSize = const Size(375, 800);
      t.view.devicePixelRatio = 1;
      final mode = ValueNotifier(ThemeMode.dark);
      final cloud = _CloudAccount();
      final demo = AuthController()..enterDemo();
      final api = _ReminderApi();
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        mode.dispose();
        cloud.dispose();
        demo.dispose();
      });
      Future<void> account(AuthController auth) async {
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(brightness: Brightness.dark),
            home: AccountScreen(auth: auth, themeMode: mode, whatsapp: api),
          ),
        );
        await t.pumpAndSettle();
      }

      Future<void> tap(String label) async {
        final target = find.text(label);
        await t.ensureVisible(target);
        await t.tap(target);
        await t.pumpAndSettle();
      }

      await account(demo);
      expect(find.text('Pengingat WhatsApp'), findsNothing);
      await account(cloud);
      await tap('Pengingat WhatsApp');
      expect(find.text('Belum terverifikasi'), findsOneWidget);
      final toggle = find.byType(SwitchListTile);
      expect(t.widget<SwitchListTile>(toggle).onChanged, isNull);
      await t.enterText(find.byType(TextField).first, '081200000001');
      await tap('Kirim kode');
      expect(find.text('Kirim ulang kode'), findsOneWidget);
      final code = find.byType(TextField).last;
      await t.enterText(code, '654321');
      await tap('Verifikasi nomor');
      expect(
        find.text('Kode salah. Periksa pesan WhatsApp Anda.'),
        findsOneWidget,
      );
      await t.enterText(code, '123456');
      await tap('Verifikasi nomor');
      expect(find.text('Terverifikasi'), findsOneWidget);
      await tap('Aktifkan pengingat');
      expect(t.widget<SwitchListTile>(toggle).value, isTrue);
      await tap('Aktifkan pengingat');
      expect(t.widget<SwitchListTile>(toggle).value, isFalse);
      await tap('Aktifkan pengingat');
      await t.ensureVisible(find.byType(TextField).first);
      await t.enterText(find.byType(TextField).first, '+6281200000002');
      await tap('Kirim kode');
      expect(t.widget<SwitchListTile>(toggle).value, isFalse);
      expect(t.widget<SwitchListTile>(toggle).onChanged, isNull);
      expect(api.actions, [
        'status',
        'request_code',
        'verify_code',
        'verify_code',
        'enable',
        'enable',
        'enable',
        'request_code',
      ]);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
