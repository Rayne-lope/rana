import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/camera/view/result_screen.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/gallery/view/gallery_screen.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testImageBytes = _testImageBytes();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const cameraChannel = MethodChannel('com.rana.app/camera_control');

  setUp(() {
    CameraPlatformService.useLegacyChannelsForTests = true;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'checkPermissionStatus') {
            final permissionValue = methodCall.arguments as int;
            if (permissionValue == 1) {
              return 1; // Camera granted.
            }
            if (permissionValue == 9 || permissionValue == 22) {
              return 1; // Storage/photos granted.
            }
            return 0;
          }
          return null;
        });
  });

  tearDown(() {
    CameraPlatformService.useLegacyChannelsForTests = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
  });

  testWidgets('renders MediaStore grid and opens the detail viewer', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'listGalleryMedia':
              return [
                {
                  'id': 101,
                  'contentUri': 'content://media/external/images/media/101',
                  'displayName': 'Rana_2026-06-25-10-11-12.jpg',
                  'dateTaken': DateTime(
                    2026,
                    6,
                    25,
                    10,
                    11,
                    12,
                  ).millisecondsSinceEpoch,
                  'dateAdded': DateTime(
                    2026,
                    6,
                    25,
                    10,
                    11,
                    12,
                  ).millisecondsSinceEpoch,
                  'width': 4032,
                  'height': 3024,
                  'sizeBytes': 1_024_000,
                  'mimeType': 'image/jpeg',
                  'relativePath': 'Pictures/Rana/',
                },
              ];
            case 'loadGalleryThumbnailBytes':
              return testImageBytes;
            case 'loadCapturedImageBytes':
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

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const GalleryScreen()),
        GoRoute(
          path: AppRoutes.result,
          builder: (context, state) =>
              ResultScreen(imageUri: state.extra! as String),
        ),
      ],
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RANA LIBRARY'), findsOneWidget);
    expect(find.text('1 photo saved in MediaStore'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gallery-tile-101')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Rana_2026-06-25-10-11-12.jpg'), findsOneWidget);
    expect(find.byTooltip('Favorite'), findsOneWidget);
    expect(find.byTooltip('Share photo'), findsOneWidget);
    expect(find.byTooltip('Delete photo'), findsOneWidget);
  });

  testWidgets('switches to a Rolls view without photo filters', (
    WidgetTester tester,
  ) async {
    var rollMetadataRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'listGalleryMedia':
              return [
                {
                  'id': 202,
                  'contentUri': 'content://media/external/images/media/202',
                  'displayName': 'Rana_2026-07-01-09-00-00.jpg',
                  'dateTaken': DateTime(2026, 7, 1, 9).millisecondsSinceEpoch,
                  'width': 4032,
                  'height': 3024,
                  'mimeType': 'image/jpeg',
                },
              ];
            case 'loadGalleryThumbnailBytes':
              return testImageBytes;
            case 'listFilmRollCaptures':
              rollMetadataRequests += 1;
              return const <Map<String, dynamic>>[];
          }
          return null;
        });

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const GalleryScreen()),
      ],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ALL TIME'), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-mode-photos')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-mode-rolls')), findsOneWidget);
    expect(rollMetadataRequests, 0);

    await tester.tap(find.byKey(const ValueKey('gallery-mode-rolls')));
    await tester.pumpAndSettle();

    expect(find.text('NO FILM ROLLS YET'), findsOneWidget);
    expect(find.text('ALL TIME'), findsNothing);
    expect(find.text('OPEN CAMERA'), findsOneWidget);
    expect(rollMetadataRequests, 0);
  });

  testWidgets('renders partial early Film Roll cards and opens their route', (
    WidgetTester tester,
  ) async {
    final archivedRoll = FilmRoll(
      id: 'roll-archive',
      presetId: 'night-drive',
      lockedStyle: const RanaStyle(),
      aspectRatioPlatformValue: 'portrait_3_4',
      size: FilmRollSize.twelve,
      exposuresTaken: 2,
      status: FilmRollStatus.completed,
      startedAt: DateTime.utc(2026, 7, 1, 9),
      completedAt: DateTime.utc(2026, 7, 1, 10),
      coverUri: 'content://media/external/images/media/301',
    );
    SharedPreferences.setMockInitialValues({
      'rana.film_rolls.v1': jsonEncode([archivedRoll.toJson()]),
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'listGalleryMedia':
              return [
                {
                  'id': 301,
                  'contentUri': 'content://media/external/images/media/301',
                  'displayName': 'Rana_2026-07-01-09-00-00.jpg',
                  'dateTaken': DateTime(2026, 7, 1, 9).millisecondsSinceEpoch,
                  'width': 4032,
                  'height': 3024,
                  'mimeType': 'image/jpeg',
                },
              ];
            case 'listFilmRollCaptures':
              return [
                {
                  'mediaUri': 'content://media/external/images/media/301',
                  'capturedAtEpochMs': DateTime(
                    2026,
                    7,
                    1,
                    9,
                  ).millisecondsSinceEpoch,
                },
                {
                  'mediaUri': 'content://media/external/images/media/302',
                  'capturedAtEpochMs': DateTime(
                    2026,
                    7,
                    1,
                    10,
                  ).millisecondsSinceEpoch,
                },
              ];
            case 'loadGalleryThumbnailBytes':
              return testImageBytes;
          }
          return null;
        });

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const GalleryScreen()),
        GoRoute(
          path: '/rolls/:id',
          builder: (context, state) =>
              Text('ROLL DETAIL ${state.pathParameters['id']}'),
        ),
      ],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gallery-mode-rolls')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('gallery-roll-roll-archive')),
      findsOneWidget,
    );
    expect(find.text('ENDED EARLY'), findsOneWidget);
    expect(find.text('2/12 EXPOSURES'), findsOneWidget);
    expect(find.text('PARTIAL · 1 UNAVAILABLE'), findsOneWidget);
    expect(find.text('1 OF 2 FRAMES AVAILABLE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gallery-roll-roll-archive')));
    await tester.pumpAndSettle();

    expect(find.text('ROLL DETAIL roll-archive'), findsOneWidget);
  });

  testWidgets('shows lazy photo-access prompt when MediaStore denies access', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'listGalleryMedia':
              throw PlatformException(
                code: 'PERMISSION_DENIED',
                message: 'Photos access is required',
              );
            case 'loadGalleryThumbnailBytes':
              return testImageBytes;
            case 'loadCapturedImageBytes':
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'checkPermissionStatus') {
            final permissionValue = methodCall.arguments as int;
            if (permissionValue == 1) {
              return 1; // Camera granted.
            }
            return 0; // Storage/photos denied.
          }
          return null;
        });

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const GalleryScreen()),
        GoRoute(
          path: AppRoutes.result,
          builder: (context, state) =>
              ResultScreen(imageUri: state.extra! as String),
        ),
      ],
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PHOTOS ACCESS REQUIRED'), findsOneWidget);
    expect(find.text('ALLOW PHOTO ACCESS'), findsOneWidget);
    expect(find.text('CHECK AGAIN'), findsOneWidget);
  });

  testWidgets('offers lazy restore action when owned Rana gallery is empty', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'listGalleryMedia':
              return const [];
            case 'getPermissionCapabilities':
              return const {
                'requiresLegacyStorageForCapture': false,
                'galleryReadPermission': 'photos',
              };
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'checkPermissionStatus') return 0;
          return <int, int>{};
        });

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const GalleryScreen()),
      ],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NO RANA PHOTOS YET'), findsOneWidget);
    expect(find.text('FIND PHOTOS FROM PREVIOUS RANA INSTALL'), findsOneWidget);
  });
}

Uint8List _testImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMA'
  'ASsJTYQAAAAASUVORK5CYII=',
);
