import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppLayout {
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const page = 20.0;
  static const section = 24.0;
  static const radius = 20.0;
  static const controlRadius = 12.0;
  static const navigationRadius = 24.0;
  static const panelRadius = 28.0;
  static const control = 48.0;
  static const fieldHeight = 56.0;
  static const navigationHeight = 72.0;
  static const contentWidth = 560.0;

  static double gutter(BuildContext context) =>
      switch (MediaQuery.sizeOf(context).width) {
        < 360 => space16,
        >= 600 => section,
        _ => page,
      };
}

abstract final class AppTypography {
  static const font = 'Plus Jakarta Sans';
  static const time = TextStyle(
    fontFamily: 'IBM Plex Mono',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );
}

abstract final class AppMotion {
  static Duration durationOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 160);
}

class _AccessibleTransitions extends PageTransitionsBuilder {
  final PageTransitionsBuilder delegate;
  const _AccessibleTransitions(this.delegate);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : delegate.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}

final class AppColors {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.border,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.primaryPressed,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.accent,
    required this.onAccent,
    required this.accentPressed,
    required this.panel,
    required this.onPanel,
    required this.nav,
    required this.onNav,
    required this.focus,
    required this.focusOnPanel,
    required this.infoBg,
    required this.infoInk,
    required this.successBg,
    required this.successInk,
    required this.warningBg,
    required this.warningInk,
    required this.dangerBg,
    required this.dangerInk,
    required this.dangerPressed,
    required this.onDanger,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color border;
  final Color outline;
  final Color primary;
  final Color onPrimary;
  final Color primaryPressed;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color accent;
  final Color onAccent;
  final Color accentPressed;
  final Color panel;
  final Color onPanel;
  final Color nav;
  final Color onNav;
  final Color focus;
  final Color focusOnPanel;
  final Color infoBg;
  final Color infoInk;
  final Color successBg;
  final Color successInk;
  final Color warningBg;
  final Color warningInk;
  final Color dangerBg;
  final Color dangerInk;
  final Color dangerPressed;
  final Color onDanger;

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const light = AppColors(
    canvas: Color(0xFFF7F5ED),
    surface: Color(0xFFFFFEFA),
    surfaceMuted: Color(0xFFEBEDE2),
    ink: Color(0xFF203A32),
    inkSecondary: Color(0xFF4D5F54),
    inkMuted: Color(0xFF53624F),
    border: Color(0xFFDFE3D5),
    outline: Color(0xFF73816B),
    primary: Color(0xFF285847),
    onPrimary: Color(0xFFFFFEFA),
    primaryPressed: Color(0xFF1B4334),
    primarySoft: Color(0xFFEAF0DF),
    onPrimarySoft: Color(0xFF203A32),
    accent: Color(0xFFD7ED98),
    onAccent: Color(0xFF183D36),
    accentPressed: Color(0xFFC7DF83),
    panel: Color(0xFF183D36),
    onPanel: Color(0xFFEDF3DF),
    nav: Color(0xFF183D36),
    onNav: Color(0xFFEDF3DF),
    focus: Color(0xFF285847),
    focusOnPanel: Color(0xFFD7ED98),
    infoBg: Color(0xFFE3F2FC),
    infoInk: Color(0xFF1B4D6C),
    successBg: Color(0xFFDCFCE7),
    successInk: Color(0xFF166534),
    warningBg: Color(0xFFFEF3C7),
    warningInk: Color(0xFF92400E),
    dangerBg: Color(0xFFFEE2E2),
    dangerInk: Color(0xFFB91C1C),
    dangerPressed: Color(0xFF991B1B),
    onDanger: Color(0xFFFFFEFA),
  );

  static const dark = AppColors(
    canvas: Color(0xFF101815),
    surface: Color(0xFF17231E),
    surfaceMuted: Color(0xFF22312A),
    ink: Color(0xFFEEF4EC),
    inkSecondary: Color(0xFFC1CEC5),
    inkMuted: Color(0xFFA6B7AC),
    border: Color(0xFF34463D),
    outline: Color(0xFF829588),
    primary: Color(0xFFA5D3B6),
    onPrimary: Color(0xFF11261B),
    primaryPressed: Color(0xFF8CB99D),
    primarySoft: Color(0xFF263D31),
    onPrimarySoft: Color(0xFFCDEBD8),
    accent: Color(0xFFD7ED98),
    onAccent: Color(0xFF183D36),
    accentPressed: Color(0xFFC7DF83),
    panel: Color(0xFF213C32),
    onPanel: Color(0xFFEDF3DF),
    nav: Color(0xFF132820),
    onNav: Color(0xFFEDF3DF),
    focus: Color(0xFFB9E9C9),
    focusOnPanel: Color(0xFFD7ED98),
    infoBg: Color(0xFF1C3544),
    infoInk: Color(0xFFB7E1F8),
    successBg: Color(0xFF183826),
    successInk: Color(0xFFA9E6B9),
    warningBg: Color(0xFF3C2B16),
    warningInk: Color(0xFFF9D790),
    dangerBg: Color(0xFF472521),
    dangerInk: Color(0xFFFFC4BC),
    dangerPressed: Color(0xFFF2ABA3),
    onDanger: Color(0xFF321311),
  );
}

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
      ).copyWith(
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        primaryContainer: colors.primarySoft,
        onPrimaryContainer: colors.onPrimarySoft,
        secondary: colors.inkSecondary,
        onSecondary: colors.canvas,
        secondaryContainer: colors.surfaceMuted,
        onSecondaryContainer: colors.ink,
        tertiary: colors.accent,
        onTertiary: colors.onAccent,
        surface: colors.surface,
        surfaceDim: colors.canvas,
        surfaceBright: colors.surface,
        surfaceContainerLowest: colors.canvas,
        surfaceContainerLow: colors.surface,
        surfaceContainer: colors.surface,
        surfaceContainerHigh: colors.surfaceMuted,
        surfaceContainerHighest: colors.surfaceMuted,
        onSurface: colors.ink,
        onSurfaceVariant: colors.inkSecondary,
        outline: colors.outline,
        outlineVariant: colors.border,
        error: colors.dangerInk,
        onError: colors.onDanger,
        errorContainer: colors.dangerBg,
        onErrorContainer: colors.dangerInk,
      );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: AppTypography.font,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    dividerColor: colors.border,
    splashFactory: InkRipple.splashFactory,
    shadowColor: isDark ? const Color(0x7A000000) : const Color(0x29183D36),
  );
  final type = base.textTheme
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 32,
          height: 38 / 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineSmall: const TextStyle(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(
        fontFamily: AppTypography.font,
        bodyColor: colors.ink,
        displayColor: colors.ink,
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppLayout.controlRadius),
    borderSide: BorderSide(color: colors.outline),
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppLayout.controlRadius),
  );
  final dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppLayout.navigationRadius),
    side: BorderSide(color: colors.border),
  );
  final modalBarrier = isDark
      ? Colors.black54
      : colors.panel.withValues(alpha: .48);
  const controlSize = Size(AppLayout.control, AppLayout.control);
  final focusSide = BorderSide(color: colors.focus, width: 2);

  return base.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final entry in const PageTransitionsTheme().builders.entries)
          entry.key: _AccessibleTransitions(entry.value),
      },
    ),
    textTheme: type,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.surfaceMuted
            : colors.surface,
      ),
      border: border,
      enabledBorder: border,
      disabledBorder: border.copyWith(
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.focus, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.dangerInk, width: 1.5),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.dangerInk, width: 2),
      ),
      constraints: const BoxConstraints(minHeight: AppLayout.fieldHeight),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: type.labelLarge?.copyWith(color: colors.inkSecondary),
      floatingLabelStyle: type.labelLarge?.copyWith(color: colors.focus),
      helperStyle: type.bodySmall?.copyWith(color: colors.inkMuted),
      errorStyle: type.bodySmall?.copyWith(color: colors.dangerInk),
      contentPadding: const EdgeInsets.all(AppLayout.space16),
      helperMaxLines: 4,
      errorMaxLines: 4,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: AppLayout.page,
      titleTextStyle: type.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.canvas,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppLayout.navigationHeight,
      backgroundColor: colors.nav,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: colors.accent,
      indicatorShape: const StadiumBorder(),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? colors.focusOnPanel.withValues(alpha: .18)
            : null,
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colors.onAccent : colors.onNav,
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return type.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? colors.accent : colors.onNav,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.nav,
      elevation: 0,
      useIndicator: true,
      indicatorColor: colors.accent,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: colors.onAccent, size: 22),
      unselectedIconTheme: IconThemeData(color: colors.onNav, size: 22),
      selectedLabelTextStyle: type.labelLarge?.copyWith(
        color: colors.accent,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: type.labelLarge?.copyWith(color: colors.onNav),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      barrierColor: modalBarrier,
      elevation: 4,
      titleTextStyle: type.titleLarge,
      contentTextStyle: type.bodyMedium?.copyWith(color: colors.inkSecondary),
      shape: dialogShape,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: dialogShape,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: colors.surface,
      shape: dialogShape,
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          TextButton.styleFrom(
            foregroundColor: colors.primary,
            minimumSize: controlSize,
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.space12,
              vertical: AppLayout.space8,
            ),
            textStyle: type.labelLarge,
            shape: controlShape,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? focusSide
                  : BorderSide.none,
            ),
          ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.surfaceMuted,
        disabledForegroundColor: colors.inkMuted,
        minimumSize: controlSize,
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.space16,
          vertical: AppLayout.space12,
        ),
        textStyle: type.labelLarge,
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: colors.ink,
            minimumSize: controlSize,
            side: BorderSide(color: colors.outline),
            shape: controlShape,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? focusSide
                  : BorderSide(color: colors.outline),
            ),
          ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style:
          IconButton.styleFrom(
            foregroundColor: colors.inkSecondary,
            minimumSize: controlSize,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? focusSide
                  : BorderSide.none,
            ),
          ),
    ),
  );
}
