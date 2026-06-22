import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rana/core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: RanaApp(),
    ),
  );
}

/// Root application widget.
class RanaApp extends ConsumerWidget {
  const RanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Rana',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
