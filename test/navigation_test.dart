import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/camera/view/camera_screen.dart';
import 'package:rana/features/camera/widgets/latest_capture_thumbnail.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
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
    var autoCompleteCapture = true;
    String? pendingCaptureId;

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
      autoCompleteCapture = true;
      pendingCaptureId = null;
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
                pendingCaptureId = captureId;
                if (autoCompleteCapture) {
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
                }
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
              case 'listFilmRollCaptures':
                return const [];
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
      expect(find.text('RANA GALLERY'), findsWidgets);
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

    testWidgets('Film action loads a roll and disables style editing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _StaticPresetRepository([_navigationNormalPreset]),
            ),
          ],
          child: const RanaApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CameraScreen)),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('camera-film-action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('LOAD FILM'), findsOneWidget);
      expect(find.text('LOAD 24 EXPOSURES'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('start-roll-size-12')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('load-roll-button')));
      await tester.pump();
      // The analog shutter surface owns a long-lived animation controller;
      // poll a bounded time for the async recipe application instead of
      // waiting for every app animation to become idle.
      for (
        var attempt = 0;
        attempt < 20 &&
            find
                .byKey(const ValueKey<String>('roll-hud-pill'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.byKey(const ValueKey<String>('roll-hud-pill')),
        findsOneWidget,
      );
      expect(find.text('0/12'), findsOneWidget);
      final activeRoll = container.read(filmRollControllerProvider).activeRoll;
      expect(activeRoll?.presetId, 'normal');
      expect(activeRoll?.lockedStyle, const RanaStyle());
      expect(activeRoll?.aspectRatioPlatformValue, 'portrait_3_4');
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey<String>('camera-reset-action')),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey<String>('camera-style-action')),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey<String>('camera-aspect-ratio-control')),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey<String>('camera-preset-selector')),
            )
            .onTap,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('camera-style-action')),
      );
      await tester.pump();
      expect(find.text('RANA STYLES'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('camera-film-action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('FILM ROLL'), findsOneWidget);
    });

    testWidgets('a full roll shows its completion sheet only once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CameraScreen)),
      );
      final rollController = container.read(
        filmRollControllerProvider.notifier,
      );
      await rollController.startRoll(
        presetId: 'normal',
        lockedStyle: const RanaStyle(),
        size: FilmRollSize.twelve,
        aspectRatioPlatformValue: CameraAspectRatio.portrait34.platformValue,
      );
      for (var frame = 1; frame <= FilmRollSize.twelve.count; frame += 1) {
        final reservation = rollController.reserveExposure()!;
        await rollController.recordExposure(
          captureId: 'completion-frame-$frame',
          reservation: reservation,
          mediaUri: 'content://rana/frame-$frame.jpg',
        );
      }

      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('ROLL COMPLETE'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('roll-complete-done-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ROLL COMPLETE'), findsNothing);

      await tester.pump();
      expect(find.text('ROLL COMPLETE'), findsNothing);
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

    testWidgets('capture feedback follows native capture events', (
      WidgetTester tester,
    ) async {
      autoCompleteCapture = false;
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('camera-shutter-button')),
      );
      await tester.pump();

      expect(pendingCaptureId, isNotNull);
      expect(
        find.byKey(const ValueKey<String>('capture-screen-flash')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('capture-completed-toast')),
        findsNothing,
      );

      await dispatchCameraStatusEvent({
        'type': 'capture_progress',
        'captureId': pendingCaptureId,
        'phase': 'image_captured',
        'elapsedMs': 80,
      });
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('capture-screen-flash')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('capture-completed-toast')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.byKey(const ValueKey<String>('capture-screen-flash')),
        findsNothing,
      );

      await dispatchCameraStatusEvent({
        'type': 'capture_completed',
        'captureId': pendingCaptureId,
        'uri': 'content://rana/test-photo.jpg',
        'elapsedMs': 320,
      });
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('capture-completed-toast')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        find.byKey(const ValueKey<String>('capture-completed-toast')),
        findsNothing,
      );
    });

    testWidgets('failed capture does not show success feedback', (
      WidgetTester tester,
    ) async {
      autoCompleteCapture = false;
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('camera-shutter-button')),
      );
      await tester.pump();
      await dispatchCameraStatusEvent({
        'type': 'capture_failed',
        'captureId': pendingCaptureId,
        'message': 'CameraX capture failed',
        'elapsedMs': 80,
      });
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('capture-screen-flash')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('capture-completed-toast')),
        findsNothing,
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

class _StaticPresetRepository implements PresetRepository {
  const _StaticPresetRepository(this.presets);

  final List<PresetModel> presets;

  @override
  Future<List<PresetModel>> loadAll() async => presets;
}

const _navigationNormalPreset = PresetModel(
  id: 'normal',
  name: 'Normal',
  category: 'Classic',
  color: PresetColor(temperature: 0, contrast: 0, saturation: 0),
  grain: PresetGrain(intensity: 0),
  vignette: PresetVignette(intensity: 0),
  style: RanaStyle(),
);
