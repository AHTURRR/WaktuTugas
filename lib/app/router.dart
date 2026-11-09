import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

GoRouter createRouter(AuthController auth, PlannerController planner) {
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
        builder: (context, state, shell) => Scaffold(
          appBar: AppBar(
            title: Text(
              [
                'WaktuTugas',
                'Tugas',
                'Waktu Anda',
                'Jadwal',
              ][shell.currentIndex],
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountScreen(auth: auth),
                  ),
                ),
                tooltip: 'Akun Anda',
                icon: const DesignIcon('imgUserCircle'),
              ),
            ],
          ),
          body: Column(
            children: [
              ListenableBuilder(
                listenable: planner,
                builder: (c, _) => planner.isOfflineSnapshot
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Notice(
                              title: 'Luring · hanya baca',
                              message:
                                  'Cache akun yang sama. ${planner.fetchedAt == null ? '' : 'Pembaruan terakhir: ${dateTimeLabel(planner.fetchedAt!)}'}',
                            ),
                            TextButton(
                              onPressed: planner.isPending
                                  ? null
                                  : () => planner.fetchSnapshot(
                                      userId: auth.userId,
                                    ),
                              child: const Text('Coba sambungkan lagi'),
                            ),
                          ],
                        ),
                      )
                    : planner.isPending
                    ? const LinearProgressIndicator(
                        semanticsLabel: 'Sedang memuat…',
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: planner,
                  builder: (context, _) {
                    final loading = planner.isApiBacked && planner.isPending;
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
          bottomNavigationBar: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                width: 2,
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => shell.goBranch(i),
              destinations: const [
                NavigationDestination(
                  icon: DesignIcon('imgHome'),
                  label: 'Ringkasan',
                ),
                NavigationDestination(
                  icon: DesignIcon('imgNavigationCheckSquare'),
                  label: 'Tugas',
                ),
                NavigationDestination(
                  icon: DesignIcon('imgClock1'),
                  label: 'Waktu',
                ),
                NavigationDestination(
                  icon: DesignIcon('imgCalendar'),
                  label: 'Jadwal',
                ),
              ],
            ),
          ),
        ),
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
