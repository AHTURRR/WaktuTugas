import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const canvas = Color(0xfffffdf2);
  static const ink = Color(0xff171717);
  static const lime = Color(0xffd7ff00);
  static const cyan = Color(0xffbdeff2);
  static const lilac = Color(0xffd9c6f2);
  static const warning = Color(0xfff8e5a6);
  static const error = Color(0xffb3261e);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Plus Jakarta Sans',
    colorScheme: const ColorScheme.light(
      primary: AppColors.lime,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.cyan,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.ink,
      onSecondary: AppColors.canvas,
      secondaryContainer: AppColors.lilac,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.canvas,
      onSurface: AppColors.ink,
      onSurfaceVariant: Color(0xff4a4a4a),
      outline: AppColors.ink,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.ink, width: 2),
  );
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 32 / 28,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
          bodySmall: const TextStyle(fontSize: 12, height: 1.4),
        )
        .apply(
          fontFamily: 'Plus Jakarta Sans',
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.canvas,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.ink, width: 3),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 3),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(color: AppColors.ink),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      helperMaxLines: 4,
      errorMaxLines: 4,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: 20,
      titleTextStyle: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: AppColors.canvas,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.lime,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(width: 2, color: AppColors.ink),
      ),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(width: 2, color: AppColors.ink),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 52),
        side: const BorderSide(width: 2, color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
