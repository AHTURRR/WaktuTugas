import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
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
        builder: (context, state) => LoginScreen(auth: auth),
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
              const MaterialBanner(
                content: Text(
                  'Demo lokal • 9 November 2026, 18.00 WIB • data direset saat keluar',
                ),
                actions: [SizedBox.shrink()],
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
                builder: (c, s) => const Center(child: Text('Ringkasan tugas')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (c, s) => ListView(
                  children: [
                    for (final t in planner.snapshot.tasks)
                      ListTile(
                        title: Text(t.title),
                        subtitle: Text('${t.remainingMinutes} menit'),
                        onTap: () => c.push('/task/${t.id}'),
                      ),
                    IconButton(
                      onPressed: () => c.push('/task/new'),
                      tooltip: 'Tambah tugas',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/time',
                builder: (c, s) =>
                    const Center(child: Text('Waktu pengerjaan')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (c, s) => Center(
                  child: Text(
                    s.uri.queryParameters['missing'] == '1'
                        ? 'Hitung pratinjau terlebih dahulu.'
                        : 'Jadwal terkonfirmasi',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/task/new',
        parentNavigatorKey: root,
        builder: (c, s) =>
            Scaffold(appBar: AppBar(title: const Text('Tambah tugas'))),
      ),
      GoRoute(
        path: '/task/:id',
        parentNavigatorKey: root,
        builder: (c, s) =>
            Scaffold(appBar: AppBar(title: const Text('Ubah tugas'))),
      ),
      GoRoute(
        path: '/schedule/preview',
        parentNavigatorKey: root,
        builder: (c, s) =>
            Scaffold(appBar: AppBar(title: const Text('Pratinjau'))),
      ),
      GoRoute(
        path: '/session/:id',
        parentNavigatorKey: root,
        builder: (c, s) =>
            Scaffold(appBar: AppBar(title: const Text('Progres sesi'))),
      ),
    ],
  );
}
