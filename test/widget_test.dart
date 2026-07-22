import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Widget Tests', () {
    const permissionChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    const cameraChannel = MethodChannel('com.rana.app/camera_control');
    const platformViewsChannel = MethodChannel('flutter/platform_views');

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
            if (methodCall.method == 'initializeCamera') {
              return {'status': 'initialized', 'lens': 'back'};
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

    testWidgets('RanaApp renders without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: RanaApp()));
      expect(find.byType(MaterialApp), findsOneWidget);

      // Drain the pending splash timer so the test framework is happy.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    });
  });
}
