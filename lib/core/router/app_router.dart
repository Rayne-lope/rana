import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/camera/view/camera_screen.dart';
import 'package:rana/features/gallery/view/gallery_screen.dart';
import 'package:rana/features/settings/view/settings_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Centrally-defined route names — always reference these constants,
/// never hard-code path strings.
abstract final class AppRoutes {
  static const camera = '/camera';
  static const gallery = '/gallery';
  static const settings = '/settings';
}

@riverpod
GoRouter appRouter(Ref ref) {
  AppLogger.i('AppRouter', 'Initialising router');
  return GoRouter(
    initialLocation: AppRoutes.camera,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.camera,
        name: 'camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        name: 'gallery',
        builder: (context, state) => const GalleryScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
