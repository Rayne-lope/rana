import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/features/camera/view/camera_screen.dart';
import 'package:rana/features/camera/widgets/latest_capture_thumbnail.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';
import 'package:rana/features/splash/view/splash_screen.dart';
import 'package:rana/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testImageBytes = _testImageBytes();

  group('Navigation', () {
    const permissionChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    const cameraChannel = MethodChannel('com.rana.app/camera_control');
    var captureCounter = 0;

    Future<void> dispatchCameraStatusEvent(Map<String, dynamic> event) async {
      const codec = StandardMethodCodec();
      final data = codec.encodeSuccessEnvelope(event);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.rana.app/camera_status',
            data,
            (ByteData? reply) {},
          );
    }

    setUp(() {
      captureCounter = 0;
      SharedPreferences.setMockInitialValues({});
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
              case 'beginCapture':
                final captureId = 'navigation-capture-${++captureCounter}';
                unawaited(
                  Future<void>.delayed(Duration.zero).then((_) async {
                    await dispatchCameraStatusEvent({
                      'type': 'capture_progress',
                      'captureId': captureId,
                      'phase': 'image_captured',
                      'elapsedMs': 80,
                    });
                    await dispatchCameraStatusEvent({
                      'type': 'capture_completed',
                      'captureId': captureId,
                      'uri': 'content://rana/test-photo.jpg',
                      'elapsedMs': 320,
                    });
                  }),
                );
                return {'status': 'capture_started', 'captureId': captureId};
              case 'loadCapturedImageBytes':
                return testImageBytes;
              case 'listGalleryMedia':
                return const [];
              case 'loadGalleryThumbnailBytes':
                return testImageBytes;
              case 'openMediaInGallery':
                return null;
              case 'shareGalleryMedia':
                return null;
              case 'deleteGalleryMedia':
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

    testWidgets('NavigationBar is removed and not visible after splash delay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));

      // Advance past SplashScreen._duration (1200 ms).
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      // NavigationBar should not be present.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationDestination), findsNothing);
    });

    testWidgets('tapping gallery thumbnail navigates to Gallery Screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      // Tap gallery thumbnail icon button
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      // Gallery screen shows its AppBar title.
      expect(find.text('Gallery'), findsWidgets);
    });

    testWidgets('tapping Settings cog navigates to Settings Screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      // Tap settings cog icon button
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('capture stays on CameraScreen and refreshes thumbnail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('camera-shutter-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(CameraScreen), findsOneWidget);
      expect(find.text('SHOOT AGAIN'), findsNothing);
      expect(find.text('VIEW IN GALLERY'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LatestCaptureThumbnail),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
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
