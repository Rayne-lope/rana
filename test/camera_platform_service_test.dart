import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/services/camera_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.rana.app/camera_control');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('lists typed Film Roll capture records from native metadata', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          expect(methodCall.method, 'listFilmRollCaptures');
          expect(methodCall.arguments, {'filmRollId': 'roll-42'});
          return <Map<String, Object>>[
            {
              'mediaUri': 'content://media/external/images/media/12',
              'capturedAtEpochMs': 1700000000123,
            },
          ];
        });

    final records = await CameraPlatformService().listFilmRollCaptures(
      'roll-42',
    );

    expect(records, hasLength(1));
    expect(records.single.mediaUri, 'content://media/external/images/media/12');
    expect(
      records.single.capturedAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000123),
    );
  });

  test('does not turn a native Film Roll query failure into an empty list', () {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          throw PlatformException(
            code: 'LIST_FILM_ROLL_CAPTURES_FAILED',
            message: 'metadata unavailable',
          );
        });

    expect(
      CameraPlatformService().listFilmRollCaptures('roll-42'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'LIST_FILM_ROLL_CAPTURES_FAILED',
        ),
      ),
    );
  });

  test('rejects malformed native Film Roll capture records', () {
    expect(
      () => FilmRollCaptureRecord.fromChannelMap({
        'capturedAtEpochMs': 1700000000123,
      }),
      throwsFormatException,
    );
  });
}
