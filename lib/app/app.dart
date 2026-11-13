import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../data/whatsapp_api.dart';
import '../state/auth_controller.dart';
import '../state/planner_controller.dart';
import 'router.dart';
import 'theme.dart';

class WaktuTugasApp extends StatefulWidget {
  final AuthController auth;
  final PlannerController planner;
  final WhatsAppApi? whatsapp;
  final ThemeMode initialThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const WaktuTugasApp({
    super.key,
    required this.auth,
    required this.planner,
    this.whatsapp,
    this.initialThemeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });
  @override
  State<WaktuTugasApp> createState() => _WaktuTugasAppState();
}

class _WaktuTugasAppState extends State<WaktuTugasApp> {
  late final GoRouter router;
  late final ValueNotifier<ThemeMode> themeMode;
  final lightTheme = buildTheme();
  final darkTheme = buildTheme(brightness: Brightness.dark);
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_sessionChanged);
    themeMode = ValueNotifier(widget.initialThemeMode)
      ..addListener(_themeChanged);
    router = createRouter(
      widget.auth,
      widget.planner,
      themeMode,
      whatsapp: widget.whatsapp,
    );
    if (widget.auth.signedIn &&
        widget.auth.isCloud &&
        widget.planner.api != null) {
      widget.planner.fetchSnapshot(userId: widget.auth.userId);
    }
  }

  void _themeChanged() => widget.onThemeModeChanged?.call(themeMode.value);

  void _sessionChanged() {
    if (widget.auth.signedIn &&
        widget.auth.isCloud &&
        widget.planner.api != null) {
      widget.planner.fetchSnapshot(userId: widget.auth.userId);
    } else if (widget.auth.signedIn && !widget.auth.isCloud) {
      widget.planner.resetDemo();
    } else if (widget.auth.signedIn && widget.planner.isApiBacked) {
      widget.planner.fetchSnapshot(userId: widget.auth.userId);
    } else {
      widget.planner.clear();
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_sessionChanged);
    router.dispose();
    themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: themeMode,
    builder: (context, mode, _) => MaterialApp.router(
      title: 'WaktuTugas',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      themeAnimationStyle: AnimationStyle.noAnimation,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    ),
  );
}
