import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/providers/global_error_provider.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/core/widgets/global_error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Setup framework error handler
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };

  // Setup asynchronous/platform error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('PlatformDispatcher', 'Unhandled error', error, stack);
    container
        .read(globalErrorControllerProvider.notifier)
        .setError(error, stack);
    return true;
  };

  // Setup layout build error boundary
  ErrorWidget.builder = (details) => GlobalErrorScreen(
    error: details.exception,
    stackTrace: details.stack ?? StackTrace.empty,
    onReset: () {
      container.read(globalErrorControllerProvider.notifier).clearError();
    },
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const RanaApp()),
  );
}

/// Root application widget.
class RanaApp extends ConsumerWidget {
  const RanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unhandledError = ref.watch(globalErrorControllerProvider);

    if (unhandledError != null) {
      return MaterialApp(
        title: 'Rana — Critical Fault',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: GlobalErrorScreen(
          error: unhandledError.error,
          stackTrace: unhandledError.stackTrace,
          onReset: () {
            ref.read(globalErrorControllerProvider.notifier).clearError();
          },
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Rana',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
