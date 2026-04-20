import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/morning/morning_screen.dart';
import '../features/monitor/monitor_settings_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/session/session_screen.dart';
import '../features/hall_of_shame/hall_of_shame_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/morning',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/morning',
                name: 'morning',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: MorningScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/planner',
                name: 'planner',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: PlannerScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/session',
                name: 'session',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: SessionScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/monitor',
                name: 'monitor',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: MonitorSettingsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                name: 'stats',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: StatsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
