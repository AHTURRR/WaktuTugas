import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:waktu_tugas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android local demo: login, preview, confirm, progress', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka demo lokal'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Jadwal'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hitung pratinjau'));
    await tester.pumpAndSettle();
    expect(find.text('120 menit belum tertampung'), findsOneWidget);
    await tester.ensureVisible(find.text('Konfirmasi jadwal'));
    await tester.tap(find.text('Konfirmasi jadwal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Majukan jam demo ke sesi berikutnya'),
    );
    await tester.tap(find.text('Majukan jam demo ke sesi berikutnya'));
    await tester.pumpAndSettle();
    final session = find.byKey(const Key('session-1-0'));
    await tester.ensureVisible(session);
    await tester.tap(session);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('remaining-after')), '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.ensureVisible(find.text('Simpan progres'));
    await tester.tap(find.text('Simpan progres'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Tugas'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('90 menit tersisa'), findsOneWidget);
  });
}
