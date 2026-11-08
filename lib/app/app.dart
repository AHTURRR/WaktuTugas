import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../state/auth_controller.dart';
import '../state/planner_controller.dart';
import 'router.dart';
import 'theme.dart';

class WaktuTugasApp extends StatefulWidget {
  final AuthController auth;
  final PlannerController planner;
  const WaktuTugasApp({super.key, required this.auth, required this.planner});
  @override
  State<WaktuTugasApp> createState() => _WaktuTugasAppState();
}

class _WaktuTugasAppState extends State<WaktuTugasApp> {
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_sessionChanged);
    router = createRouter(widget.auth, widget.planner);
  }

  void _sessionChanged() {
    if (widget.auth.signedIn) {
      widget.planner.resetDemo();
    } else {
      widget.planner.clear();
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_sessionChanged);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'WaktuTugas',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('id', 'ID'),
    supportedLocales: const [Locale('id', 'ID')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
}
