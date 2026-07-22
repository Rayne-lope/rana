import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/camera/view/camera_screen.dart';
import 'package:rana/features/camera/widgets/latest_capture_thumbnail.dart';
import 'package:rana/features/film_roll/controller/film_roll_controller.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/widgets/contact_sheet_export.dart';
import 'package:rana/features/gallery/controller/gallery_controller.dart';
import 'package:rana/features/gallery/state/gallery_state.dart';
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
    const platformViewsChannel = MethodChannel('flutter/platform_views');
    var captureCounter = 0;
    var autoCompleteCapture = true;
    String? pendingCaptureId;
    var galleryItems = <Map<String, dynamic>>[];
    var filmRollCaptures = <String, List<Map<String, dynamic>>>{};
    var contactSheetShareCalls = 0;
    String? exportedContactSheetRollId;
    String? exportedContactSheetPresetName;
    var initializeCameraCalls = 0;
    var releaseCameraCalls = 0;

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
      galleryItems = <Map<String, dynamic>>[];
      filmRollCaptures = <String, List<Map<String, dynamic>>>{};
      contactSheetShareCalls = 0;
      exportedContactSheetRollId = null;
      exportedContactSheetPresetName = null;
      initializeCameraCalls = 0;
      releaseCameraCalls = 0;
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
                initializeCameraCalls += 1;
                return {'status': 'initialized', 'lens': 'back'};
              case 'releaseCamera':
                releaseCameraCalls += 1;
                return {'status': 'released'};
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
                return galleryItems;
              case 'loadGalleryThumbnailBytes':
                return testImageBytes;
              case 'openMediaInGallery':
                return null;
              case 'shareGalleryMedia':
                return null;
              case 'shareContactSheet':
                contactSheetShareCalls += 1;
                return null;
              case 'deleteGalleryMedia':
                return null;
              case 'listFilmRollCaptures':
                final arguments = methodCall.arguments;
                if (arguments is! Map<dynamic, dynamic>) return const [];
                final rollId = arguments['filmRollId'];
                return rollId is String
                    ? filmRollCaptures[rollId] ?? const []
                    : const [];
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformViewsChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'create') return 0;
            if (methodCall.method == 'resize') {
              final arguments = methodCall.arguments as Map<dynamic, dynamic>;
              return <String, double>{
                'width': arguments['width'] as double,
                'height': arguments['height'] as double,
              };
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(cameraChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformViewsChannel, null);
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

    testWidgets(
      'camera controls stay balanced and preset selector stays compact',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const ProviderScope(child: RanaApp()));
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        final controls = find.byKey(
          const ValueKey<String>('camera-bottom-controls'),
        );
        final gallery = find.byKey(
          const ValueKey<String>('camera-gallery-action'),
        );
        final film = find.byKey(const ValueKey<String>('camera-film-action'));
        final shutter = find.byKey(
          const ValueKey<String>('camera-shutter-button'),
        );
        final reset = find.byKey(const ValueKey<String>('camera-reset-action'));
        final style = find.byKey(const ValueKey<String>('camera-style-action'));

        final galleryRect = tester.getRect(gallery);
        final filmRect = tester.getRect(film);
        final shutterRect = tester.getRect(shutter);
        final resetRect = tester.getRect(reset);
        final styleRect = tester.getRect(style);

        expect(galleryRect.center.dx, lessThan(filmRect.center.dx));
        expect(filmRect.center.dx, lessThan(shutterRect.center.dx));
        expect(shutterRect.center.dx, lessThan(resetRect.center.dx));
        expect(resetRect.center.dx, lessThan(styleRect.center.dx));
        expect(
          shutterRect.center.dx,
          closeTo(tester.getCenter(controls).dx, 0.01),
        );

        for (final sideControl in [gallery, film, reset, style]) {
          expect(shutterRect.overlaps(tester.getRect(sideControl)), isFalse);
        }

        expect(
          tester
              .getSize(
                find.byKey(const ValueKey<String>('camera-preset-selector')),
              )
              .height,
          44,
        );
        expect(
          tester
              .getSize(
                find.byKey(
                  const ValueKey<String>('camera-preset-selector-surface'),
                ),
              )
              .height,
          34,
        );
      },
    );

    testWidgets('roll detail route loads chronological Film Roll frames '
        'and opens the viewer', (WidgetTester tester) async {
      final roll = FilmRoll(
        id: 'roll-archive',
        presetId: 'normal',
        lockedStyle: const RanaStyle(),
        aspectRatioPlatformValue: 'portrait_3_4',
        size: FilmRollSize.twelve,
        exposuresTaken: 2,
        status: FilmRollStatus.completed,
        startedAt: DateTime.utc(2026, 7, 10, 9),
        completedAt: DateTime.utc(2026, 7, 10, 10),
        coverUri: 'content://rana/roll-frame-101.jpg',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'rana.film_rolls.v1': jsonEncode(<Map<String, dynamic>>[roll.toJson()]),
      });
      galleryItems = <Map<String, dynamic>>[
        _galleryItemMap(
          id: 102,
          uri: 'content://rana/roll-frame-102.jpg',
          capturedAt: DateTime.utc(2026, 7, 10, 9, 30),
        ),
        _galleryItemMap(
          id: 101,
          uri: 'content://rana/roll-frame-101.jpg',
          capturedAt: DateTime.utc(2026, 7, 10, 9, 10),
        ),
      ];
      filmRollCaptures = <String, List<Map<String, dynamic>>>{
        roll.id: <Map<String, dynamic>>[
          <String, dynamic>{
            'mediaUri': 'content://rana/roll-frame-102.jpg',
            'capturedAtEpochMs': DateTime.utc(
              2026,
              7,
              10,
              9,
              30,
            ).millisecondsSinceEpoch,
          },
          <String, dynamic>{
            'mediaUri': 'content://rana/roll-frame-101.jpg',
            'capturedAtEpochMs': DateTime.utc(
              2026,
              7,
              10,
              9,
              10,
            ).millisecondsSinceEpoch,
          },
        ],
      };

      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _StaticPresetRepository(<PresetModel>[
              _navigationNormalPreset,
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const RanaApp()),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      container.read(appRouterProvider).go(AppRoutes.rollDetail(roll.id));
      for (
        var attempt = 0;
        attempt < 20 &&
            find
                .byKey(const ValueKey<String>('roll-detail-tile-101'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.byKey(const ValueKey<String>('roll-detail-screen')),
        findsOneWidget,
      );
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('2/12'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('roll-detail-tile-101')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('roll-detail-tile-101')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('unknown roll route returns safely to Rolls', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _StaticPresetRepository(<PresetModel>[
              _navigationNormalPreset,
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const RanaApp()),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      container
          .read(appRouterProvider)
          .go(AppRoutes.rollDetail('missing-roll'));
      for (
        var attempt = 0;
        attempt < 20 &&
            find
                .byKey(const ValueKey<String>('roll-detail-not-found'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.byKey(const ValueKey<String>('roll-detail-not-found')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('roll-detail-show-rolls-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('RANA GALLERY'), findsWidgets);
      expect(
        container.read(galleryControllerProvider).viewMode,
        GalleryViewMode.rolls,
      );
    });

    testWidgets(
      'roll detail retains archive metadata when frames are missing',
      (WidgetTester tester) async {
        final roll = FilmRoll(
          id: 'roll-without-photos',
          presetId: 'normal',
          lockedStyle: const RanaStyle(),
          aspectRatioPlatformValue: 'portrait_3_4',
          size: FilmRollSize.twelve,
          exposuresTaken: 1,
          status: FilmRollStatus.completed,
          startedAt: DateTime.utc(2026, 7, 11, 9),
          completedAt: DateTime.utc(2026, 7, 11, 10),
          coverUri: 'content://rana/missing-roll-frame.jpg',
        );
        SharedPreferences.setMockInitialValues(<String, Object>{
          'rana.film_rolls.v1': jsonEncode(<Map<String, dynamic>>[
            roll.toJson(),
          ]),
        });
        filmRollCaptures = <String, List<Map<String, dynamic>>>{
          roll.id: <Map<String, dynamic>>[
            <String, dynamic>{
              'mediaUri': 'content://rana/missing-roll-frame.jpg',
              'capturedAtEpochMs': DateTime.utc(
                2026,
                7,
                11,
                9,
              ).millisecondsSinceEpoch,
            },
          ],
        };

        final container = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _StaticPresetRepository(<PresetModel>[
                _navigationNormalPreset,
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const RanaApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        container.read(appRouterProvider).go(AppRoutes.rollDetail(roll.id));
        for (
          var attempt = 0;
          attempt < 20 &&
              find
                  .byKey(const ValueKey<String>('roll-detail-empty'))
                  .evaluate()
                  .isEmpty;
          attempt += 1
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('1/12'), findsOneWidget);
        expect(find.text('ENDED EARLY'), findsOneWidget);
        expect(find.text('1 FRAME UNAVAILABLE'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('roll-detail-empty')),
          findsOneWidget,
        );
      },
    );

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

    testWidgets('camera initializes only after the native preview is created', (
      WidgetTester tester,
    ) async {
      final createCompleter = Completer<int>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformViewsChannel, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'create') {
              return createCompleter.future;
            }
            if (methodCall.method == 'resize') {
              final arguments = methodCall.arguments as Map<dynamic, dynamic>;
              return <String, double>{
                'width': arguments['width'] as double,
                'height': arguments['height'] as double,
              };
            }
            return null;
          });

      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(AndroidView), findsOneWidget);
      expect(initializeCameraCalls, equals(0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(initializeCameraCalls, equals(0));

      createCompleter.complete(0);
      await tester.pumpAndSettle();

      expect(initializeCameraCalls, equals(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(initializeCameraCalls, equals(1));
    });

    testWidgets('transient inactive keeps the camera initialized', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(initializeCameraCalls, equals(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(releaseCameraCalls, equals(0));
    });

    for (final terminalState in <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      testWidgets('$terminalState releases the camera', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const ProviderScope(child: RanaApp()));
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();
        expect(initializeCameraCalls, equals(1));

        tester.binding.handleAppLifecycleStateChanged(terminalState);
        await tester.pump();
        expect(releaseCameraCalls, equals(1));
      });
    }

    testWidgets(
      'metrics change recreates a transparent preview and keeps UI tappable',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(400, 800);
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
        });

        await tester.pumpWidget(const ProviderScope(child: RanaApp()));
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        final initialPreview = tester.widget<AndroidView>(
          find.byType(AndroidView),
        );
        expect(
          initialPreview.hitTestBehavior,
          PlatformViewHitTestBehavior.transparent,
        );
        expect(initializeCameraCalls, equals(1));

        tester.view.physicalSize = const Size(800, 400);
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('camera-preview-metrics-gate')),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        final recreatedPreview = tester.widget<AndroidView>(
          find.byType(AndroidView),
        );
        expect(
          recreatedPreview.hitTestBehavior,
          PlatformViewHitTestBehavior.transparent,
        );
        expect(releaseCameraCalls, equals(1));
        expect(initializeCameraCalls, equals(2));

        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsWidgets);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.photo_library_outlined));
        await tester.pumpAndSettle();
        expect(find.text('RANA GALLERY'), findsWidgets);
      },
    );

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

    testWidgets('active Roll Info exports durable saved frames', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _StaticPresetRepository([_navigationNormalPreset]),
            ),
            contactSheetExportRunnerProvider.overrideWithValue(({
              required FilmRoll roll,
              required String presetName,
            }) async {
              contactSheetShareCalls += 1;
              exportedContactSheetRollId = roll.id;
              exportedContactSheetPresetName = presetName;
              return ContactSheetExportResult.shared(
                exportedFrameCount: roll.exposuresTaken,
                historicalFrameCount: roll.exposuresTaken,
                skippedFrameCount: 0,
                width: 1440,
                height: 1000,
              );
            }),
          ],
          child: const RanaApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CameraScreen)),
      );
      final rollController = container.read(
        filmRollControllerProvider.notifier,
      );
      expect(
        (await rollController.startRoll(
          presetId: 'normal',
          lockedStyle: const RanaStyle(),
          size: FilmRollSize.twelve,
          aspectRatioPlatformValue: CameraAspectRatio.portrait34.platformValue,
        )).succeeded,
        isTrue,
      );
      final activeRoll = container.read(filmRollControllerProvider).activeRoll!;
      final reservation = rollController.tryReserveExposure().reservation!;
      expect(
        (await rollController.recordExposure(
          captureId: 'contact-sheet-frame',
          reservation: reservation,
          mediaUri: 'content://rana/contact-sheet-frame.jpg',
        )).succeeded,
        isTrue,
      );
      filmRollCaptures[activeRoll.id] = <Map<String, dynamic>>[
        <String, dynamic>{
          'mediaUri': 'content://rana/contact-sheet-frame.jpg',
          'capturedAtEpochMs': DateTime.utc(
            2026,
            7,
            16,
            12,
          ).millisecondsSinceEpoch,
        },
      ];

      await tester.tap(
        find.byKey(const ValueKey<String>('camera-film-action')),
      );
      await tester.pumpAndSettle();

      final exportButton = find.byKey(
        const ValueKey<String>('export-contact-sheet-button'),
      );
      expect(exportButton, findsOneWidget);
      await tester.tap(exportButton);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('roll-info-error')),
        findsNothing,
      );
      expect(contactSheetShareCalls, 1);
      expect(exportedContactSheetRollId, activeRoll.id);
      expect(exportedContactSheetPresetName, 'Normal');
      expect(find.text('CONTACT SHEET READY: 1 FRAME'), findsOneWidget);
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
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAJCAYAAAA7KqwyAAAAFklEQVR4nGO406PxnxLM'
  'MGrAqAFADAARhHCA1uhxAQAAAABJRU5ErkJggg==',
);

Map<String, dynamic> _galleryItemMap({
  required int id,
  required String uri,
  required DateTime capturedAt,
}) => <String, dynamic>{
  'id': id,
  'contentUri': uri,
  'displayName': 'Rana_$id.jpg',
  'dateTaken': capturedAt.millisecondsSinceEpoch,
  'dateAdded': capturedAt.millisecondsSinceEpoch,
  'width': 4032,
  'height': 3024,
  'sizeBytes': 1024000,
  'mimeType': 'image/jpeg',
  'relativePath': 'Pictures/Rana/',
};

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
