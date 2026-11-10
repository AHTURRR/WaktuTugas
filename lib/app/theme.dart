import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppLayout {
  static const page = 20.0;
  static const section = 24.0;
  static const radius = 20.0;
  static const control = 48.0;
  static const contentWidth = 560.0;
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

abstract final class AppColors {
  // Studio Fokus: warm paper, deep pine and lime.
  static const canvas = Color(0xFFF7F5ED);
  static const surface = Color(0xFFFFFEFA);
  static const surfaceMuted = Color(0xFFEBEDE2);

  // Typography & iconography hierarchy (deep navy & slate)
  static const ink = Color(0xFF203A32);
  static const inkSecondary = Color(0xFF4D5F54);
  static const inkMuted = Color(0xFF53624F);

  // Borders & dividers
  static const border = Color(0xFFDFE3D5);
  static const borderStrong = Color(0xFF73816B);

  // Primary actions and brand surfaces.
  static const primary = Color(0xFF285847);
  static const primaryDark = Color(0xFF1B4334);
  static const primarySoft = Color(0xFFEAF0DF);
  static const primaryBorder = Color(0xFFCEDDBB);

  // Semantic accents (soft pastel fills + high-contrast text/borders)
  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFDCFCE7);
  static const successBorder = Color(0xFFBBF7D0);

  static const warningInk = Color(0xFF92400E);
  static const warning = Color(0xFFFEF3C7);
  static const warningSoft = warning;
  static const warningBorder = Color(0xFFFDE68A);

  static const error = Color(0xFFB91C1C);
  static const errorSoft = Color(0xFFFEE2E2);
  static const errorBorder = Color(0xFFFECACA);

  static const accentInk = Color(0xFF254834);
  static const cyan = Color(0xFFEAF0DF);
  static const lilac = Color(0xFFF0EDDE);
  static const lime = Color(0xFFD7ED98);
  static const forest = Color(0xFF183D36);
  static const onForest = Color(0xFFEDF3DF);
  static const peach = Color(0xFFF4DFCD);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Plus Jakarta Sans',
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.inkSecondary,
      onSecondary: AppColors.surface,
      secondaryContainer: AppColors.surfaceMuted,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSecondary,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: AppColors.surface,
      errorContainer: AppColors.errorSoft,
      onErrorContainer: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.border,
    splashFactory: InkRipple.splashFactory,
  );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppLayout.radius),
    borderSide: const BorderSide(color: AppColors.borderStrong, width: 1),
  );

  return base.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final entry in const PageTransitionsTheme().builders.entries)
          entry.key: _AccessibleTransitions(entry.value),
      },
    ),
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 30,
            height: 1.15,
            letterSpacing: -1.0,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: const TextStyle(
            fontSize: 23,
            height: 1.2,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: const TextStyle(
            fontSize: 18,
            height: 1.35,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          fontFamily: 'Plus Jakarta Sans',
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: border,
      enabledBorder: border,
      disabledBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      constraints: const BoxConstraints(minHeight: AppLayout.control),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        color: AppColors.inkSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      helperStyle: const TextStyle(
        color: AppColors.inkMuted,
        fontSize: 12,
        height: 1.4,
      ),
      errorStyle: const TextStyle(
        color: AppColors.error,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      helperMaxLines: 4,
      errorMaxLines: 4,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: 20,

      titleTextStyle: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: AppColors.forest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: AppColors.lime,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.forest : AppColors.onForest,
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.lime : AppColors.onForest,
        );
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      titleTextStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 14,
        height: 1.5,
        color: AppColors.inkSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(width: 1, color: AppColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(AppLayout.control, AppLayout.control),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        minimumSize: const Size(AppLayout.control, AppLayout.control),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(AppLayout.control, AppLayout.control),
        side: const BorderSide(width: 1, color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.inkSecondary,
        minimumSize: const Size(AppLayout.control, AppLayout.control),
      ),
    ),
  );
}
