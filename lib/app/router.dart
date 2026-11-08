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
            title: const Text('WaktuTugas'),
            actions: [
              IconButton(
                onPressed: auth.logout,
                tooltip: 'Keluar demo',
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Column(
            children: [
              ListenableBuilder(
                listenable: planner,
                builder: (c, _) => Container(
                  width: double.infinity,
                  color: Theme.of(c).colorScheme.secondaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    'Demo lokal • ${dateTimeLabel(planner.now)}\nData contoh hanya tersimpan selama aplikasi terbuka.',
                  ),
                ),
              ),
              Expanded(child: shell),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) => shell.goBranch(i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                label: 'Ringkasan',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist),
                label: 'Tugas',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time),
                label: 'Waktu',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                label: 'Jadwal',
              ),
            ],
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
