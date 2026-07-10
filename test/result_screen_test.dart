import 'dart:convert';
import 'dart:ui' as ui;

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
    late Uint8List capturedImageBytes;

    setUp(() {
      methodCalls.clear();
      capturedImageBytes = _testImageBytes();
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
                  () => capturedImageBytes,
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

    testWidgets('contains a landscape result without forcing portrait', (
      WidgetTester tester,
    ) async {
      capturedImageBytes = _landscapeTestImageBytes();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ResultScreen(imageUri: imageUri)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      final image = tester.widget<Image>(imageFinder);
      final codec = (await tester.runAsync(
        () => ui.instantiateImageCodec(capturedImageBytes),
      ))!;
      final frame = (await tester.runAsync(codec.getNextFrame))!;
      addTearDown(() {
        frame.image.dispose();
        codec.dispose();
      });

      expect(image.fit, BoxFit.contain);
      expect(image.width, isNull);
      expect(image.height, isNull);
      expect(
        find.ancestor(of: imageFinder, matching: find.byType(AspectRatio)),
        findsNothing,
      );
      expect(frame.image.width, greaterThan(frame.image.height));
      expect(frame.image.width / frame.image.height, closeTo(16 / 9, 0.02));
    });
  });
}

Uint8List _testImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMA'
  'ASsJTYQAAAAASUVORK5CYII=',
);

Uint8List _landscapeTestImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAJCAYAAAA7KqwyAAAAFklEQVR4nGO406PxnxLM'
  'MGrAqAFADAARhHCA1uhxAQAAAABJRU5ErkJggg==',
);
