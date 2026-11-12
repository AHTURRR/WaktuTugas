import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/tasks/task_form_screen.dart';
import '../features/time/time_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/schedule/preview_screen.dart';
import '../features/schedule/session_screen.dart';
import '../features/shared.dart';
import '../features/auth/account_screen.dart';
import '../state/auth_controller.dart';
import '../state/planner_controller.dart';

const _destinations = [
  NavigationDestination(icon: DesignIcon('imgHome'), label: 'Ringkasan'),
  NavigationDestination(
    icon: DesignIcon('imgNavigationCheckSquare'),
    label: 'Tugas',
  ),
  NavigationDestination(icon: DesignIcon('imgClock1'), label: 'Waktu'),
  NavigationDestination(icon: DesignIcon('imgCalendar'), label: 'Jadwal'),
];

GoRouter createRouter(
  AuthController auth,
  PlannerController planner,
  ValueNotifier<ThemeMode> themeMode,
) {
  final root = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: root,
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      if (!auth.signedIn) {
        return state.matchedLocation == '/login' ? null : '/login';
      }
      if (state.matchedLocation == '/login') return '/home';
      if (state.matchedLocation == '/schedule/preview' &&
          planner.preview == null) {
        return '/schedule?missing=1';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => LoginScreen(auth: auth),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          final colors = AppColors.of(context);
          final showTaskList = shell.currentIndex == 1;
          final wide = MediaQuery.sizeOf(context).width >= 900;
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.panel,
                      borderRadius: BorderRadius.circular(
                        AppLayout.controlRadius,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppLayout.space8),
                      child: DesignIcon(
                        'imgClock1',
                        size: 20,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppLayout.space8),
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('WaktuTugas'),
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AccountScreen(auth: auth, themeMode: themeMode),
                      ),
                    ),
                    tooltip: 'Akun Anda',
                    icon: DesignIcon(
                      'imgUserCircle',
                      size: 22,
                      color: colors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
            body: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Row(
                children: [
                  if (wide)
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: SafeArea(
                        top: false,
                        right: false,
                        minimum: const EdgeInsets.fromLTRB(12, 4, 0, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppLayout.navigationRadius,
                          ),
                          child: NavigationRail(
                            extended: true,
                            minExtendedWidth: 168,
                            scrollable: true,
                            selectedIndex: shell.currentIndex,
                            onDestinationSelected: (i) => shell.goBranch(i),
                            destinations: [
                              for (final destination in _destinations)
                                NavigationRailDestination(
                                  icon: destination.icon,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppLayout.space4,
                                  ),
                                  label: ListenableBuilder(
                                    listenable: FocusManager.instance,
                                    builder: (context, _) {
                                      final focused =
                                          Focus.maybeOf(context)?.hasFocus ??
                                          false;
                                      return Text(
                                        destination.label,
                                        style: focused
                                            ? TextStyle(
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor:
                                                    colors.focusOnPanel,
                                                decorationThickness: 2,
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    key: const ValueKey('navigation-content'),
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: FocusTraversalGroup(
                        child: Column(
                          children: [
                            ListenableBuilder(
                              listenable: planner,
                              builder: (c, _) => planner.isOfflineSnapshot
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        12,
                                        20,
                                        0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Notice(
                                            title: 'Luring · hanya baca',
                                            message:
                                                'Cache akun yang sama. ${planner.fetchedAt == null ? '' : 'Pembaruan terakhir: ${dateTimeLabel(planner.fetchedAt!)}'}',
                                            color: colors.warningBg,
                                            live: true,
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: planner.isPending
                                                  ? null
                                                  : () => planner.fetchSnapshot(
                                                      userId: auth.userId,
                                                    ),
                                              child: const Text(
                                                'Coba sambungkan lagi',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : planner.isPending && !showTaskList
                                  ? LinearProgressIndicator(
                                      color: colors.primary,
                                      backgroundColor: colors.primarySoft,
                                      semanticsLabel: 'Sedang memuat…',
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            Expanded(
                              child: ListenableBuilder(
                                listenable: planner,
                                builder: (context, _) {
                                  final loading =
                                      planner.isApiBacked &&
                                      planner.isPending &&
                                      !showTaskList;
                                  return Stack(
                                    children: [
                                      Offstage(offstage: loading, child: shell),
                                      if (loading)
                                        const PageContent(
                                          children: [
                                            PageHeading(
                                              'Menyiapkan ruang fokus',
                                              'Memuat tugas, waktu, dan jadwal untuk akun Anda.',
                                            ),
                                            SizedBox(height: 16),
                                            Notice(
                                              title: 'Sedang memuat…',
                                              message:
                                                  'Tunggu hingga data siap. Jadwal belum dihitung atau diubah.',
                                            ),
                                          ],
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(
                      AppLayout.space12,
                      AppLayout.space4,
                      AppLayout.space12,
                      AppLayout.space8,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppLayout.navigationRadius,
                      ),
                      child: NavigationBar(
                        height:
                            AppLayout.navigationHeight +
                            (MediaQuery.textScalerOf(context).scale(16) - 16)
                                .clamp(0, 32),
                        animationDuration: AppMotion.durationOf(context),
                        selectedIndex: shell.currentIndex,
                        onDestinationSelected: (i) => shell.goBranch(i),
                        destinations: [
                          for (final destination in _destinations)
                            KeyboardFocusOutline(
                              color: colors.focusOnPanel,
                              child: destination,
                            ),
                        ],
                      ),
                    ),
                  ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (c, s) => HomeScreen(planner: planner),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (c, s) => TasksScreen(planner: planner),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/time',
                builder: (c, s) => TimeScreen(planner: planner),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (c, s) => ScheduleScreen(
                  planner: planner,
                  missingPreview: s.uri.queryParameters['missing'] == '1',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/task/new',
        parentNavigatorKey: root,
        builder: (c, s) => TaskFormScreen(planner: planner),
      ),
      GoRoute(
        path: '/task/:id',
        parentNavigatorKey: root,
        builder: (c, s) =>
            TaskFormScreen(planner: planner, taskId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/schedule/preview',
        parentNavigatorKey: root,
        builder: (c, s) => PreviewScreen(planner: planner),
      ),
      GoRoute(
        path: '/session/:id',
        parentNavigatorKey: root,
        builder: (c, s) =>
            SessionScreen(planner: planner, sessionId: s.pathParameters['id']!),
      ),
    ],
  );
}
