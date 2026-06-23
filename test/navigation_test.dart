import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';
import 'package:rana/features/splash/view/splash_screen.dart';
import 'package:rana/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testImageBytes = _testImageBytes();

  group('Navigation', () {
    const permissionChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    const cameraChannel = MethodChannel('com.rana.app/camera_control');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'checkPermissionStatus') {
              return 1; // Granted
            }
            if (methodCall.method == 'requestPermissions') {
              final args = methodCall.arguments as List<dynamic>;
              final results = <int, int>{};
              for (final p in args) {
                results[p as int] = 1;
              }
              return results;
            }
            return null;
          });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, (
            MethodCall methodCall,
          ) async {
            switch (methodCall.method) {
              case 'initializeCamera':
                return {'status': 'initialized', 'lens': 'back'};
              case 'executeCapture':
                return {
                  'status': 'captured',
                  'filePath': 'content://rana/test-photo.jpg',
                };
              case 'loadCapturedImageBytes':
                return testImageBytes;
              case 'openMediaInGallery':
                return null;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, null);
    });

    testWidgets('app starts on SplashScreen', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      // Pump one frame — splash visible before timer fires.
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      // Drain the pending splash timer so the test cleans up cleanly.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'NavigationBar with 3 destinations appears after splash delay',
      (WidgetTester tester) async {
        await tester.pumpWidget(const ProviderScope(child: RanaApp()));

        // Advance past SplashScreen._duration (1200 ms).
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        // Shell should now be visible with a NavigationBar.
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationDestination), findsNWidgets(3));

        // Verify destination labels.
        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('Gallery'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets('tapping Gallery tab switches to Gallery branch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();

      // Gallery screen shows its AppBar title.
      expect(find.text('Gallery'), findsWidgets);
    });

    testWidgets('tapping Settings tab switches to Settings branch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('router opens result fullscreen without shell nav', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _EmptyPresetRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const RanaApp()),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      final router = container.read(appRouterProvider);
      unawaited(
        router.push(AppRoutes.result, extra: 'content://rana/test-photo.jpg'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('SHOOT AGAIN'), findsOneWidget);
      expect(find.text('VIEW IN GALLERY'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.text('SHOOT AGAIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
    });
  });
}

Uint8List _testImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMA'
  'ASsJTYQAAAAASUVORK5CYII=',
);

class _EmptyPresetRepository implements PresetRepository {
  const _EmptyPresetRepository();

  @override
  Future<List<PresetModel>> loadAll() async => const [];
}
