import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/router/app_router.dart';
import 'package:rana/features/camera/view/result_screen.dart';
import 'package:rana/features/gallery/view/gallery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testImageBytes = _testImageBytes();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const cameraChannel = MethodChannel('com.rana.app/camera_control');

  setUp(() {
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

  testWidgets('shows settings prompt when storage access is denied', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'listGalleryMedia':
              return const [];
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
    expect(find.text('OPEN SETTINGS'), findsOneWidget);
    expect(find.text('CHECK AGAIN'), findsOneWidget);
  });
}

Uint8List _testImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMA'
  'ASsJTYQAAAAASUVORK5CYII=',
);
