import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/view/result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResultScreen', () {
    const methodChannel = MethodChannel('com.rana.app/camera_control');
    const imageUri = 'content://rana/test-photo.jpg';
    final methodCalls = <MethodCall>[];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
            methodCalls.add(methodCall);
            switch (methodCall.method) {
              case 'initializeCamera':
                return {'status': 'initialized', 'lens': 'back'};
              case 'executeCapture':
                return {'status': 'captured', 'filePath': imageUri};
              case 'loadCapturedImageBytes':
                return Future<Uint8List>.delayed(
                  const Duration(milliseconds: 50),
                  _testImageBytes,
                );
              case 'openMediaInGallery':
                return null;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    testWidgets('renders loading state, then image and gallery action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ResultScreen(imageUri: imageUri)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('SHOOT AGAIN'), findsOneWidget);
      expect(find.text('VIEW IN GALLERY'), findsOneWidget);

      await tester.tap(find.text('VIEW IN GALLERY'));
      await tester.pump();
      expect(
        methodCalls.any(
          (call) =>
              call.method == 'openMediaInGallery' &&
              (call.arguments as Map<dynamic, dynamic>)['uri'] == imageUri,
        ),
        isTrue,
      );
    });
  });
}

Uint8List _testImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMA'
  'ASsJTYQAAAAASUVORK5CYII=',
);
