import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/render/model/render_recipe.dart';
import 'package:rana/src/platform/rana_camera_api.g.dart' as pigeon;
import 'package:rana/src/platform/rana_camera_pigeon_mapper.dart';

final class _FakePigeonHostApi extends pigeon.RanaCameraHostApi {
  pigeon.InitializeCameraRequest? initializeRequest;
  pigeon.RenderRecipeMessage? appliedRecipe;

  @override
  Future<pigeon.CameraOperationResult> initializeCamera(
    pigeon.InitializeCameraRequest request,
  ) async {
    initializeRequest = request;
    return pigeon.CameraOperationResult(
      status: 'initialized',
      lens: request.lens,
      zoomRatio: request.zoomRatio,
      minZoomRatio: 1,
      maxZoomRatio: 3,
    );
  }

  @override
  Future<pigeon.CameraOperationResult> applyRecipe(
    pigeon.RenderRecipeMessage recipe,
  ) async {
    appliedRecipe = recipe;
    return pigeon.CameraOperationResult(status: 'preset_selected');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.rana.app/camera_control');

  setUp(() {
    CameraPlatformService.useLegacyChannelsForTests = true;
  });

  tearDown(() {
    CameraPlatformService.useLegacyChannelsForTests = false;
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

  test(
    'initializes through typed Pigeon with the active PlatformView ID',
    () async {
      CameraPlatformService.useLegacyChannelsForTests = false;
      final host = _FakePigeonHostApi();
      final service = CameraPlatformService(hostApi: host)
        ..registerPlatformView(
          const CameraPreviewRegistration(
            platformViewId: 42,
            aspectRatio: 'square_1_1',
            lens: 'front',
            flashMode: 'auto',
            zoomRatio: 2.25,
          ),
        );

      final result = await service.initializeCamera();

      expect(host.initializeRequest?.platformViewId, 42);
      expect(host.initializeRequest?.aspectRatio, 'square_1_1');
      expect(host.initializeRequest?.lens, 'front');
      expect(host.initializeRequest?.flashMode, 'auto');
      expect(host.initializeRequest?.zoomRatio, 2.25);
      expect(result['status'], 'initialized');
    },
  );

  test('maps a recipe losslessly across the typed adapter', () async {
    CameraPlatformService.useLegacyChannelsForTests = false;
    const recipe = RenderRecipeV1(
      temperature: 0.25,
      grain: 0.4,
      lightLeakVariant: 3,
      outputQuality: 'efficient_heic',
      aspectRatio: 'wide_16_9',
      presetId: 'warm',
      isStyleModified: true,
    );
    final host = _FakePigeonHostApi();

    await CameraPlatformService(
      hostApi: host,
    ).selectPreset(recipe.presetId, recipe.toMap());

    final encoded = host.appliedRecipe;
    expect(encoded, isNotNull);
    expect(recipeFromPigeon(encoded!).toMap(), recipe.toMap());
    expect(recipeFromPigeon(recipeToPigeon(recipe)).toMap(), recipe.toMap());
  });
}
