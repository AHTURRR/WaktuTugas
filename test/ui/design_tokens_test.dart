import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:waktu_tugas/app/app.dart';
import 'package:waktu_tugas/app/theme.dart';
import 'package:waktu_tugas/features/shared.dart';
import 'package:waktu_tugas/state/auth_controller.dart';
import 'package:waktu_tugas/state/planner_controller.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  double contrast(Color foreground, Color background) {
    final a = foreground.computeLuminance(), b = background.computeLuminance();
    return ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
  }

  for (final brightness in Brightness.values) {
    test(
      'text and controls meet contrast targets in ${brightness.name} mode',
      () {
        final colors = brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        for (final background in [
          colors.canvas,
          colors.surface,
          colors.surfaceMuted,
        ]) {
          for (final text in [
            colors.ink,
            colors.inkSecondary,
            colors.inkMuted,
          ]) {
            expect(contrast(text, background), greaterThanOrEqualTo(4.5));
          }
          expect(contrast(colors.outline, background), greaterThanOrEqualTo(3));
          expect(contrast(colors.focus, background), greaterThanOrEqualTo(3));
        }
        for (final (text, fill) in [
          (colors.onPrimary, colors.primary),
          (colors.onPrimary, colors.primaryPressed),
          (colors.onPrimarySoft, colors.primarySoft),
          (colors.onAccent, colors.accent),
          (colors.onAccent, colors.accentPressed),
          (colors.onPanel, colors.panel),
          (colors.onNav, colors.nav),
          (colors.accent, colors.nav),
          (colors.infoInk, colors.infoBg),
          (colors.successInk, colors.successBg),
          (colors.warningInk, colors.warningBg),
          (colors.dangerInk, colors.dangerBg),
          (colors.onDanger, colors.dangerInk),
          (colors.onDanger, colors.dangerPressed),
          (colors.primary, colors.warningBg),
          (colors.primary, colors.primarySoft),
          (colors.inkSecondary, colors.primarySoft),
          for (final (ink, fill) in [
            (colors.onPrimary, colors.primary),
            (colors.onAccent, colors.accent),
            (colors.ink, colors.surface),
            (colors.onDanger, colors.dangerInk),
          ])
            (ink, Color.alphaBlend(ink.withValues(alpha: .10), fill)),
        ]) {
          expect(contrast(text, fill), greaterThanOrEqualTo(4.5));
        }
      },
    );
  }

  testWidgets('button hover tints in place and follows reduced motion', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Center(
            child: AppButton(label: 'Aksi', onPressed: () {}),
          ),
        ),
      ),
    );
    final button = find.byType(AppButton);
    final background = find.descendant(
      of: button,
      matching: find.byType(AnimatedContainer),
    );
    final bounds = t.getRect(button);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(bounds.center);
    await t.pumpAndSettle();
    expect(t.getRect(button), bounds);
    final tint = t.widget<AnimatedContainer>(background);
    expect(tint.duration, const Duration(milliseconds: 160));
    expect((tint.decoration as BoxDecoration).color, isNot(Colors.transparent));

    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await mouse.moveTo(Offset.zero);
    await t.pumpAndSettle();
    expect(t.widget<AnimatedContainer>(background).duration, Duration.zero);
    await mouse.removePointer();
  });

  testWidgets(
    'keyboard focus remains visible and reduced motion skips dialog transitions',
    (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => PickerField(
                label: 'Tanggal',
                value: '12 November',
                icon: 'imgCalendar',
                onTap: () =>
                    confirmDelete(context, 'Hapus?', 'Contoh', 'Hapus'),
              ),
            ),
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final outline = find.descendant(
        of: find.byType(KeyboardFocusOutline),
        matching: find.byType(DecoratedBox),
      );
      final border =
          (t.widget<DecoratedBox>(outline.first).decoration as BoxDecoration)
                  .border
              as Border;
      expect(border.top, const BorderSide(color: Color(0xFF285847), width: 2));
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      final route = ModalRoute.of(t.element(find.byType(AlertDialog)))!;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      await t.tap(find.text('Batal'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'system brightness updates the global shell and shared controls',
    (tester) async {
      final auth = AuthController()..enterDemo();
      final planner = PlannerController();
      final choices = <ThemeMode>[];
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        WaktuTugasApp(
          auth: auth,
          planner: planner,
          onThemeModeChanged: choices.add,
        ),
      );
      await tester.pumpAndSettle();

      void expectPalette(AppColors colors) {
        final context = tester.element(find.byType(NavigationBar));
        expect(Theme.of(context).scaffoldBackgroundColor, colors.canvas);
        expect(NavigationBarTheme.of(context).backgroundColor, colors.nav);
        expect(Theme.of(context).textTheme.bodyLarge?.color, colors.ink);
        final page = find.byType(PageContent).first;
        expect(AppColors.of(tester.element(page)).surface, colors.surface);
      }

      expectPalette(AppColors.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expectPalette(AppColors.dark);
      await tester.tap(find.byTooltip('Akun Anda'));
      await tester.pumpAndSettle();
      final light = find.widgetWithText(RadioListTile<ThemeMode>, 'Terang');
      await tester.ensureVisible(light);
      await tester.tap(light);
      await tester.pumpAndSettle();
      expect(AppColors.of(tester.element(light)), same(AppColors.light));
      final dark = find.widgetWithText(RadioListTile<ThemeMode>, 'Gelap');
      await tester.tap(dark);
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(AppColors.of(tester.element(dark)), same(AppColors.dark));
      final system = find.widgetWithText(
        RadioListTile<ThemeMode>,
        'Ikuti sistem',
      );
      await tester.ensureVisible(system);
      await tester.tap(system);
      await tester.pumpAndSettle();
      expect(AppColors.of(tester.element(system)), same(AppColors.light));
      expect(choices, [ThemeMode.light, ThemeMode.dark, ThemeMode.system]);
      await tester.tap(find.byTooltip('Kembali'));
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
      expect(find.text('Tambah tugas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      planner.dispose();
    },
  );
}
