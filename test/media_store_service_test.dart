import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/services/media_store_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.rana.app/camera_control');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('shares a contact sheet through the PNG bridge', () async {
    final pngBytes = Uint8List.fromList(const <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);

    await MediaStoreService().shareContactSheet(pngBytes);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'shareContactSheet');
    final arguments = calls.single.arguments as Map<dynamic, dynamic>;
    expect(arguments['pngBytes'], orderedEquals(pngBytes));
  });

  test('propagates Android contact-sheet share failures', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw PlatformException(
            code: 'SHARE_CONTACT_SHEET_FAILED',
            message: 'Unable to encode contact sheet JPEG',
          );
        });

    await expectLater(
      MediaStoreService().shareContactSheet(
        Uint8List.fromList(const <int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]),
      ),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'SHARE_CONTACT_SHEET_FAILED')
            .having(
              (error) => error.message,
              'message',
              'Unable to encode contact sheet JPEG',
            ),
      ),
    );

    expect(calls.single.method, 'shareContactSheet');
  });

  test('keeps individual MediaStore photo sharing unchanged', () async {
    await MediaStoreService().shareGalleryMedia(
      'content://media/external/images/media/42',
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'shareGalleryMedia');
    expect(
      (calls.single.arguments as Map<dynamic, dynamic>)['uri'],
      'content://media/external/images/media/42',
    );
  });
}
