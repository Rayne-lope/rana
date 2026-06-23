import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/core/widgets/main_shell.dart';
import 'package:rana/features/camera/view/camera_screen.dart';
import 'package:rana/features/camera/view/result_screen.dart';
import 'package:rana/features/debug/view/consistency_debug_screen.dart';
import 'package:rana/features/gallery/view/gallery_screen.dart';
import 'package:rana/features/settings/view/settings_screen.dart';
import 'package:rana/features/splash/view/splash_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Centrally-defined route paths.
///
/// Always use these constants when navigating — never hard-code path strings.
abstract final class AppRoutes {
  /// Splash — shown briefly on cold launch, then redirects to [camera].
  static const splash = '/';

  /// Camera (home) — main capture screen.
  static const camera = '/camera';

  /// Gallery — shows photos taken with Rana.
  static const gallery = '/gallery';

  /// Settings — app preferences.
  static const settings = '/settings';

  /// Result preview shown after a successful capture.
  static const result = '/result';

  /// Shader consistency debug screen.
  static const consistencyDebug = '/consistency-debug';
}

@riverpod
GoRouter appRouter(Ref ref) {
  AppLogger.i('AppRouter', 'Initialising router');
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.result,
        name: 'result',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => switch (state.extra) {
          final String imageUri => ResultScreen(imageUri: imageUri),
          _ => const SizedBox.shrink(),
        },
      ),
      GoRoute(
        path: AppRoutes.consistencyDebug,
        name: 'consistencyDebug',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConsistencyDebugScreen(),
      ),

      // ── Main shell (Camera / Gallery / Settings) ────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.camera,
                name: 'camera',
                builder: (context, state) => const CameraScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.gallery,
                name: 'gallery',
                builder: (context, state) => const GalleryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
