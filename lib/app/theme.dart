import 'package:flutter/material.dart';

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff17665a),
    surface: const Color(0xfffafaf5),
  ),
  scaffoldBackgroundColor: const Color(0xfffafaf5),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
  appBarTheme: const AppBarTheme(centerTitle: false),
);
