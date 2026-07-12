import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/features/camera/controller/camera_controller.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/preset/model/rana_style_mood.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraState & Native Bridge', () {
    const methodChannel = MethodChannel('com.rana.app/camera_control');
    final log = <MethodCall>[];
    Future<Map<String, dynamic>> Function(MethodCall methodCall)?
    executeCaptureHandler;
    var nativeMaxZoomRatio = userMaxZoomRatio;
    var nativeHasTelephotoCandidate = false;
    var nativePhysicalCameraCount = 0;
    var captureCounter = 0;

    Map<String, dynamic> zoomQualityFields(double zoomRatio) {
      final isZoomed = zoomRatio > userMinZoomRatio + 0.01;
      final isLikelyDigitalZoom = isZoomed && !nativeHasTelephotoCandidate;
      return {
        'zoomQualityLabel': !isZoomed
            ? 'native'
            : nativeHasTelephotoCandidate
            ? 'tele_candidate'
            : 'digital_likely',
        'hasTelephotoCandidate': nativeHasTelephotoCandidate,
        'isLikelyDigitalZoom': isLikelyDigitalZoom,
        'shouldWarnDigitalZoom': zoomRatio >= 2 && isLikelyDigitalZoom,
        'physicalCameraCount': nativePhysicalCameraCount,
      };
    }

    void dispatchCameraStatusEvent(Map<String, dynamic> event) {
      const codec = StandardMethodCodec();
      final data = codec.encodeSuccessEnvelope(event);
      unawaited(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'com.rana.app/camera_status',
              data,
              (ByteData? reply) {},
            ),
      );
    }

    Future<void> drainCaptureEvents() async {
      for (var i = 0; i < 4; i += 1) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() {
      log.clear();
      executeCaptureHandler = null;
      nativeMaxZoomRatio = userMaxZoomRatio;
      nativeHasTelephotoCandidate = false;
      nativePhysicalCameraCount = 0;
      captureCounter = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (
            MethodCall methodCall,
          ) async {
            final effectiveMaxZoomRatio = nativeMaxZoomRatio < userMaxZoomRatio
                ? nativeMaxZoomRatio
                : userMaxZoomRatio;
            log.add(methodCall);
            switch (methodCall.method) {
              case 'initializeCamera':
                return <String, dynamic>{
                  'status': 'initialized',
                  'lens': 'back',
                  'zoomRatio': userMinZoomRatio,
                  'minZoomRatio': userMinZoomRatio,
                  'maxZoomRatio': nativeMaxZoomRatio,
                  'effectiveMaxZoomRatio': effectiveMaxZoomRatio,
                  'isZoomLimited': nativeMaxZoomRatio < userMaxZoomRatio,
                }..addAll(zoomQualityFields(userMinZoomRatio));
              case 'selectPreset':
                final args = methodCall.arguments as Map<dynamic, dynamic>;
                return <String, dynamic>{
                  'status': 'preset_selected',
                  'presetId': args['presetId'],
                };
              case 'setFlashMode':
                final args = methodCall.arguments as Map<dynamic, dynamic>;
                return {'status': 'flash_set', 'flashMode': args['flashMode']};
              case 'toggleLens':
                final args = methodCall.arguments as Map<dynamic, dynamic>;
                final currentLens = args['lens'] as String;
                final nextLens = currentLens == 'back' ? 'front' : 'back';
                return <String, dynamic>{
                  'status': 'lens_toggled',
                  'lens': nextLens,
                  'zoomRatio': userMinZoomRatio,
                  'minZoomRatio': userMinZoomRatio,
                  'maxZoomRatio': nativeMaxZoomRatio,
                  'effectiveMaxZoomRatio': effectiveMaxZoomRatio,
                  'isZoomLimited': nativeMaxZoomRatio < userMaxZoomRatio,
                }..addAll(zoomQualityFields(userMinZoomRatio));
              case 'setZoomRatio':
                final args = methodCall.arguments as Map<dynamic, dynamic>;
                final requestedZoomRatio = (args['zoomRatio'] as num)
                    .toDouble();
                final appliedZoomRatio = requestedZoomRatio.clamp(
                  userMinZoomRatio,
                  effectiveMaxZoomRatio,
                );
                return <String, dynamic>{
                  'status': 'zoom_set',
                  'requestedZoomRatio': requestedZoomRatio,
                  'zoomRatio': appliedZoomRatio,
                  'minZoomRatio': userMinZoomRatio,
                  'maxZoomRatio': nativeMaxZoomRatio,
                  'effectiveMaxZoomRatio': effectiveMaxZoomRatio,
                  'isZoomLimited': nativeMaxZoomRatio < userMaxZoomRatio,
                }..addAll(zoomQualityFields(appliedZoomRatio));
              case 'executeCapture':
                return executeCaptureHandler?.call(methodCall) ??
                    {'status': 'captured', 'filePath': '/mock/path/photo.jpg'};
              case 'beginCapture':
                final captureId = 'test-capture-${++captureCounter}';
                Future<Map<String, dynamic>> captureResult;
                try {
                  captureResult =
                      executeCaptureHandler?.call(methodCall) ??
                      Future<Map<String, dynamic>>.value({
                        'status': 'captured',
                        'filePath': '/mock/path/photo.jpg',
                      });
                } on Object catch (error) {
                  captureResult = Future<Map<String, dynamic>>.error(error);
                }
                unawaited(
                  Future<void>.delayed(Duration.zero).then((_) {
                    dispatchCameraStatusEvent({
                      'type': 'capture_progress',
                      'captureId': captureId,
                      'phase': 'image_captured',
                      'elapsedMs': 80,
                    });
                  }),
                );
                unawaited(
                  captureResult.then<void>(
                    (payload) async {
                      await Future<void>.delayed(Duration.zero);
                      dispatchCameraStatusEvent({
                        'type': 'capture_completed',
                        'captureId': captureId,
                        'uri': payload['filePath'],
                        'elapsedMs': 320,
                        'qualityReduced': false,
                        'inSampleSize': 1,
                        'lutSkipped': false,
                      });
                    },
                    onError: (Object error) async {
                      await Future<void>.delayed(Duration.zero);
                      dispatchCameraStatusEvent({
                        'type': 'capture_failed',
                        'captureId': captureId,
                        'errorCode': error is PlatformException
                            ? error.code
                            : 'CAPTURE_FAILED',
                        'message': error is PlatformException
                            ? error.message
                            : error.toString(),
                        'elapsedMs': 320,
                      });
                    },
                  ),
                );
                return {'status': 'capture_started', 'captureId': captureId};
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    test('initial state is uninitialized', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(cameraControllerProvider);
      expect(state.isCameraInitialized, isFalse);
      expect(state.flashMode, equals(FlashMode.off));
      expect(state.activeLens, equals(CameraLens.back));
      expect(state.captureStatus, equals(CaptureStatus.idle));
      expect(state.currentFps, equals(0));
      expect(state.selfTimerMode, equals(SelfTimerMode.off));
      expect(state.selfTimerRemainingSeconds, equals(0));
      expect(state.isSelfTimerRunning, isFalse);
      expect(state.activeStyle, equals(const RanaStyle()));
      expect(state.zoomRatio, equals(userMinZoomRatio));
      expect(state.minZoomRatio, equals(userMinZoomRatio));
      expect(state.maxZoomRatio, equals(userMaxZoomRatio));
      expect(state.effectiveMaxZoomRatio, equals(userMaxZoomRatio));
      expect(state.zoomQualityLabel, equals('native'));
      expect(state.isLikelyDigitalZoom, isFalse);
      expect(state.shouldWarnDigitalZoom, isFalse);
    });

    test('initialize registers and connects channels successfully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();

      final state = container.read(cameraControllerProvider);
      expect(state.isCameraInitialized, isTrue);
      expect(state.activeLens, equals(CameraLens.back));
      expect(state.zoomRatio, equals(userMinZoomRatio));
      expect(log, hasLength(2));
      expect(log[0].method, equals('initializeCamera'));
      expect(log[1].method, equals('setAspectRatio'));
    });

    test(
      'releaseCamera resets camera initialization and invokes channel',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();
        expect(
          container.read(cameraControllerProvider).isCameraInitialized,
          isTrue,
        );
        log.clear();

        await controller.releaseCamera();
        final state = container.read(cameraControllerProvider);
        expect(state.isCameraInitialized, isFalse);
        expect(state.currentFps, equals(0));
        expect(log.length, equals(1));
        expect(log.first.method, equals('releaseCamera'));
      },
    );

    test('toggleFlashMode updates flash mode and invokes channel', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      await controller.toggleFlashMode();
      var state = container.read(cameraControllerProvider);
      expect(state.flashMode, equals(FlashMode.on));
      expect(log.length, equals(1));
      expect(log.first.method, equals('setFlashMode'));
      final args1 = log.first.arguments as Map<dynamic, dynamic>;
      expect(args1['flashMode'], equals('on'));

      await controller.toggleFlashMode();
      state = container.read(cameraControllerProvider);
      expect(state.flashMode, equals(FlashMode.auto));

      await controller.toggleFlashMode();
      state = container.read(cameraControllerProvider);
      expect(state.flashMode, equals(FlashMode.off));
    });

    test('toggleLens flips active lens and invokes channel', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      await controller.toggleLens();
      var state = container.read(cameraControllerProvider);
      expect(state.activeLens, equals(CameraLens.front));
      expect(log.length, equals(1));
      expect(log.first.method, equals('toggleLens'));
      final args = log.first.arguments as Map<dynamic, dynamic>;
      expect(args['lens'], equals('back'));

      await controller.toggleLens();
      state = container.read(cameraControllerProvider);
      expect(state.activeLens, equals(CameraLens.back));
    });

    test(
      'setZoomRatio updates native zoom within the 1x to 3x range',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();
        log.clear();

        await controller.setZoomRatio(2.4);

        final state = container.read(cameraControllerProvider);
        expect(state.zoomRatio, equals(2.4));
        expect(log, hasLength(1));
        expect(log.single.method, equals('setZoomRatio'));
        final args = log.single.arguments as Map<dynamic, dynamic>;
        expect(args['zoomRatio'], equals(2.4));
      },
    );

    test(
      'setZoomRatio surfaces likely digital zoom warning above 2x',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();

        await controller.setZoomRatio(3);

        final state = container.read(cameraControllerProvider);
        expect(state.zoomRatio, equals(3));
        expect(state.zoomQualityLabel, equals('digital_likely'));
        expect(state.hasTelephotoCandidate, isFalse);
        expect(state.isLikelyDigitalZoom, isTrue);
        expect(state.shouldWarnDigitalZoom, isTrue);
      },
    );

    test(
      'setZoomRatio keeps digital warning off for telephoto candidates',
      () async {
        nativeHasTelephotoCandidate = true;
        nativePhysicalCameraCount = 2;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();

        await controller.setZoomRatio(3);

        final state = container.read(cameraControllerProvider);
        expect(state.zoomQualityLabel, equals('tele_candidate'));
        expect(state.hasTelephotoCandidate, isTrue);
        expect(state.isLikelyDigitalZoom, isFalse);
        expect(state.shouldWarnDigitalZoom, isFalse);
        expect(state.physicalCameraCount, equals(2));
      },
    );

    test('setZoomRatio clamps requested zoom above 3x', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      await controller.setZoomRatio(5);

      final state = container.read(cameraControllerProvider);
      expect(state.zoomRatio, equals(userMaxZoomRatio));
      final args = log.single.arguments as Map<dynamic, dynamic>;
      expect(args['zoomRatio'], equals(userMaxZoomRatio));
    });

    test('setZoomRatio respects device max zoom below 3x', () async {
      nativeMaxZoomRatio = 2.2;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      await controller.setZoomRatio(3);

      final state = container.read(cameraControllerProvider);
      expect(state.zoomRatio, equals(2.2));
      expect(state.maxZoomRatio, equals(2.2));
      expect(state.effectiveMaxZoomRatio, equals(2.2));
      expect(state.isZoomLimited, isTrue);
      final args = log.single.arguments as Map<dynamic, dynamic>;
      expect(args['zoomRatio'], equals(2.2));
    });

    test('toggleLens resets zoom ratio to 1x', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      await controller.setZoomRatio(2);
      log.clear();

      await controller.toggleLens();

      final state = container.read(cameraControllerProvider);
      expect(state.activeLens, equals(CameraLens.front));
      expect(state.zoomRatio, equals(userMinZoomRatio));
      expect(log.single.method, equals('toggleLens'));
    });

    test('aspect ratio changes preserve zoom ratio', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      await controller.setZoomRatio(2);
      log.clear();

      await controller.setAspectRatio(CameraAspectRatio.square11);

      final state = container.read(cameraControllerProvider);
      expect(state.aspectRatio, equals(CameraAspectRatio.square11));
      expect(state.zoomRatio, equals(2));
      expect(log.first.method, equals('setAspectRatio'));
    });

    test('setZoomRatio no-ops while self timer is running', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      controller.startSelfTimer(SelfTimerMode.threeSeconds);
      log.clear();

      await controller.setZoomRatio(2);

      expect(container.read(cameraControllerProvider).zoomRatio, equals(1));
      expect(log, isEmpty);
    });

    test('selectPreset selects preset ID and invokes channel', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      const preset = PresetModel(
        id: 'classic_f1',
        name: 'Classic F1',
        category: 'Classic',
        color: PresetColor(temperature: 0.1, contrast: 0.2, saturation: 0.3),
        grain: PresetGrain(intensity: 0.4),
        vignette: PresetVignette(intensity: 0.5),
      );

      await controller.selectPreset(preset);
      final state = container.read(cameraControllerProvider);
      expect(state.activePresetId, equals('classic_f1'));
      expect(state.activeStyle, equals(const RanaStyle()));
      expect(log.length, equals(1));
      expect(log.first.method, equals('selectPreset'));
      final args = log.first.arguments as Map<dynamic, dynamic>;
      expect(args['presetId'], equals('classic_f1'));
      final params = args['params'] as Map<dynamic, dynamic>;
      expect(params['temperature'], equals(0.1));
      expect(params['contrast'], equals(0.2));
      expect(params['saturation'], equals(0.3));
      expect(params['grain'], equals(0.4));
      expect(params['vignette'], equals(0.5));
      expect(params['lutPath'], isNull);
      expect(params['lutStrength'], equals(0.0));
      expect(params['lightLeakIntensity'], equals(0.0));
      expect(params['lightLeakVariant'], inInclusiveRange(0, 3));
      expect(params['dustIntensity'], equals(0.0));
      expect(params['bloomThreshold'], equals(0.8));
      expect(params['bloomIntensity'], equals(0.0));
      expect(params['halationIntensity'], equals(0.0));
      expect(params['lensDistortionStrength'], equals(0.0));
      expect(params['chromaticAberrationIntensity'], equals(0.0));
      expect(params['fade'], equals(0.0));
      expect(params['dateStampEnable'], isFalse);
      expect(params['shadowsTintR'], equals(0.0));
      expect(params['shadowsTintG'], equals(0.0));
      expect(params['shadowsTintB'], equals(0.0));
      expect(params['highlightsTintR'], equals(0.0));
      expect(params['highlightsTintG'], equals(0.0));
      expect(params['highlightsTintB'], equals(0.0));
    });

    test('analog params match between preview and capture', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      const preset = PresetModel(
        id: 'analog_custom',
        name: 'Analog Custom',
        category: 'Custom',
        color: PresetColor(
          temperature: 0.1,
          contrast: 0.2,
          saturation: 0.3,
          fade: 0.25,
        ),
        grain: PresetGrain(intensity: 0.4, size: 1.6),
        vignette: PresetVignette(intensity: 0.5),
        effects: PresetEffects(
          lightLeak: LightLeakEffect(intensity: 0, variant: 0),
          dust: DustEffect(intensity: 0),
          chromaticAberration: PresetChromaticAberration(intensity: 0.12),
          softness: 0.2,
          dateStamp: PresetDateStamp(enable: true),
          splitToning: PresetSplitToning(
            shadowsTint: <double>[0.1, 0.2, 0.3],
            highlightsTint: <double>[0.7, 0.8, 0.9],
          ),
        ),
        style: RanaStyle(textureVal: 50, styleStrength: 50),
      );

      await controller.selectPreset(preset);
      final previewCall = log.singleWhere(
        (call) => call.method == 'selectPreset',
      );
      final previewArgs = previewCall.arguments as Map<dynamic, dynamic>;
      final previewParams = previewArgs['params'] as Map<dynamic, dynamic>;
      log.clear();

      await controller.capture();
      final captureCall = log.singleWhere(
        (call) => call.method == 'beginCapture',
      );
      final captureParams = captureCall.arguments as Map<dynamic, dynamic>;

      for (final key in <String>[
        'chromaticAberrationIntensity',
        'fade',
        'dateStampEnable',
        'shadowsTintR',
        'shadowsTintG',
        'shadowsTintB',
        'highlightsTintR',
        'highlightsTintG',
        'highlightsTintB',
        'textureVal',
        'grainSize',
        'softness',
      ]) {
        expect(captureParams[key], equals(previewParams[key]), reason: key);
      }
      expect(previewParams['textureVal'], 50.0);
      expect(previewParams['grainSize'], closeTo(1.52, 0.0001));
      expect(previewParams['softness'], closeTo(0.275, 0.0001));
      expect(previewParams['dateStampEnable'], isTrue);
    });

    test('selectPreset seeds active style and sends style params', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      const preset = PresetModel(
        id: 'styled_preset',
        name: 'Styled Preset',
        category: 'Classic',
        color: PresetColor(temperature: 0.1, contrast: 0.2, saturation: 0.3),
        grain: PresetGrain(intensity: 0.4),
        vignette: PresetVignette(intensity: 0.5),
        style: RanaStyle(
          tone: 12,
          color: -8,
          texture: 40,
          styleStrength: 70,
          undertoneX: 0.25,
          undertoneY: -0.5,
        ),
      );

      await controller.selectPreset(preset);

      final state = container.read(cameraControllerProvider);
      expect(state.activePresetId, equals('styled_preset'));
      expect(state.activeStyle, equals(preset.style));

      final args = log.single.arguments as Map<dynamic, dynamic>;
      final params = args['params'] as Map<dynamic, dynamic>;
      expect(params['tone'], equals(12.0));
      expect(params['color'], equals(-8.0));
      expect(params['textureVal'], equals(40.0));
      expect(params['styleStrength'], equals(70.0));
      expect(params['undertoneX'], equals(0.25));
      expect(params['undertoneY'], equals(-0.5));
    });

    test('selectPreset seeds Kodak Gold photographic style defaults', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      const goldStyle = RanaStyle(
        tone: -8,
        color: 14,
        undertoneX: -0.42,
        undertoneY: -0.04,
      );
      const preset = PresetModel(
        id: 'gold_200',
        name: 'Kodak Gold 200',
        category: 'Vintage',
        color: PresetColor(temperature: 0.24, contrast: 0.12, saturation: 0.16),
        grain: PresetGrain(intensity: 0.22),
        vignette: PresetVignette(intensity: 0.04),
        style: goldStyle,
      );

      await controller.selectPreset(preset);

      expect(container.read(cameraControllerProvider).activeStyle, goldStyle);
      final args = log.single.arguments as Map<dynamic, dynamic>;
      final params = args['params'] as Map<dynamic, dynamic>;
      expect(params['tone'], equals(-8.0));
      expect(params['color'], equals(14.0));
      expect(params['textureVal'], equals(0.0));
      expect(params['styleStrength'], equals(100.0));
      expect(params['undertoneX'], equals(-0.42));
      expect(params['undertoneY'], equals(-0.04));
    });

    test('updateActiveStyle clamps values and pushes preview params', () async {
      const preset = PresetModel(
        id: 'rana_warm',
        name: 'Rana Warm',
        category: 'Classic',
        color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
        grain: PresetGrain(intensity: 0.1),
        vignette: PresetVignette(intensity: 0.05),
      );
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([preset]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await container.read(presetsProvider.future);
      await controller.initialize();
      await controller.selectPreset(preset);
      log.clear();

      await controller.updateActiveStyle(
        const RanaStyle(
          tone: 150,
          color: -140,
          texture: 120,
          styleStrength: -5,
          undertoneX: 2,
          undertoneY: -2,
        ),
      );

      expect(
        container.read(cameraControllerProvider).activeStyle,
        equals(
          const RanaStyle(
            tone: 100,
            color: -100,
            texture: 100,
            styleStrength: 0,
            undertoneX: 1,
            undertoneY: -1,
          ),
        ),
      );

      final updateCall = log.singleWhere(
        (call) => call.method == 'selectPreset',
      );
      final updateArgs = updateCall.arguments as Map<dynamic, dynamic>;
      final params = updateArgs['params'] as Map<dynamic, dynamic>;
      expect(params['tone'], equals(100.0));
      expect(params['color'], equals(-100.0));
      expect(params['textureVal'], equals(100.0));
      expect(params['styleStrength'], equals(0.0));
      expect(params['undertoneX'], equals(1.0));
      expect(params['undertoneY'], equals(-1.0));
    });

    test(
      'palette update maps to styleStrength without changing texture',
      () async {
        const preset = PresetModel(
          id: 'gold_200',
          name: 'Kodak Gold 200',
          category: 'Vintage',
          color: PresetColor(
            temperature: 0.24,
            contrast: 0.12,
            saturation: 0.16,
          ),
          grain: PresetGrain(intensity: 0.22),
          vignette: PresetVignette(intensity: 0.04),
          style: RanaStyle(),
        );
        final container = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _FakePresetRepository([preset]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await container.read(presetsProvider.future);
        await controller.initialize();
        await controller.selectPreset(preset);
        log.clear();

        await controller.updateActiveStyle(const RanaStyle(styleStrength: 42));

        expect(
          container.read(cameraControllerProvider).activeStyle.styleStrength,
          equals(42),
        );
        final updateCall = log.singleWhere(
          (call) => call.method == 'selectPreset',
        );
        final updateArgs = updateCall.arguments as Map<dynamic, dynamic>;
        final params = updateArgs['params'] as Map<dynamic, dynamic>;
        expect(params['styleStrength'], equals(42.0));
        expect(params['textureVal'], equals(0.0));
      },
    );

    test(
      'applyStyleMood keeps preset params and sends mood style params',
      () async {
        const goldStyle = RanaStyle(
          tone: -8,
          color: 14,
          undertoneX: -0.42,
          undertoneY: -0.04,
        );
        const preset = PresetModel(
          id: 'gold_200',
          name: 'Kodak Gold 200',
          category: 'Vintage',
          color: PresetColor(
            temperature: 0.24,
            contrast: 0.12,
            saturation: 0.16,
          ),
          grain: PresetGrain(intensity: 0.22),
          vignette: PresetVignette(intensity: 0.04),
          style: goldStyle,
        );
        final container = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _FakePresetRepository([preset]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await container.read(presetsProvider.future);
        await controller.initialize();
        await controller.selectPreset(preset);
        log.clear();

        await controller.applyStyleMood(RanaStyleMood.coolRose);

        final expectedStyle = RanaStyleMood.coolRose.resolve(preset);
        expect(
          container.read(cameraControllerProvider).activeStyle,
          expectedStyle,
        );
        final updateCall = log.singleWhere(
          (call) => call.method == 'selectPreset',
        );
        final updateArgs = updateCall.arguments as Map<dynamic, dynamic>;
        expect(updateArgs['presetId'], equals('gold_200'));
        final params = updateArgs['params'] as Map<dynamic, dynamic>;
        expect(params['temperature'], equals(0.24));
        expect(params['contrast'], equals(0.12));
        expect(params['saturation'], equals(0.16));
        expect(params['tone'], equals(-8.0));
        expect(params['color'], equals(12.0));
        expect(params['styleStrength'], equals(100.0));
        expect(params['textureVal'], equals(0.0));
        expect(params['undertoneX'], closeTo(0.13, 0.001));
        expect(params['undertoneY'], closeTo(0.14, 0.001));
      },
    );

    test('manual edits still work after applying a style mood', () async {
      const preset = PresetModel(
        id: 'gold_200',
        name: 'Kodak Gold 200',
        category: 'Vintage',
        color: PresetColor(temperature: 0.24, contrast: 0.12, saturation: 0.16),
        grain: PresetGrain(intensity: 0.22),
        vignette: PresetVignette(intensity: 0.04),
        style: RanaStyle(tone: -8, color: 14, undertoneX: -0.42),
      );
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([preset]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await container.read(presetsProvider.future);
      await controller.initialize();
      await controller.selectPreset(preset);
      await controller.applyStyleMood(RanaStyleMood.gold);
      log.clear();

      await controller.updateActiveStyle(
        container
            .read(cameraControllerProvider)
            .activeStyle
            .copyWith(styleStrength: 56),
      );

      final updateCall = log.singleWhere(
        (call) => call.method == 'selectPreset',
      );
      final updateArgs = updateCall.arguments as Map<dynamic, dynamic>;
      final params = updateArgs['params'] as Map<dynamic, dynamic>;
      expect(params['styleStrength'], equals(56.0));
      expect(params['textureVal'], equals(0.0));
      expect(
        RanaStyleMood.matchForStyle(
          preset,
          container.read(cameraControllerProvider).activeStyle,
        ),
        isNull,
      );
    });

    test(
      'capture exports the same style params after applying a mood',
      () async {
        const preset = PresetModel(
          id: 'gold_200',
          name: 'Kodak Gold 200',
          category: 'Vintage',
          color: PresetColor(
            temperature: 0.24,
            contrast: 0.12,
            saturation: 0.16,
          ),
          grain: PresetGrain(intensity: 0.22),
          vignette: PresetVignette(intensity: 0.04),
          style: RanaStyle(tone: -8, color: 14, undertoneX: -0.42),
        );
        final container = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _FakePresetRepository([preset]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await container.read(presetsProvider.future);
        await controller.initialize();
        await controller.selectPreset(preset);
        log.clear();

        await controller.applyStyleMood(RanaStyleMood.coolRose);
        final previewCall = log.singleWhere(
          (call) => call.method == 'selectPreset',
        );
        final previewArgs = previewCall.arguments as Map<dynamic, dynamic>;
        final previewParams = previewArgs['params'] as Map<dynamic, dynamic>;
        log.clear();

        await controller.capture();

        final captureCall = log.singleWhere(
          (call) => call.method == 'beginCapture',
        );
        final exportParams = captureCall.arguments as Map<dynamic, dynamic>;
        for (final key in [
          'temperature',
          'contrast',
          'saturation',
          'tone',
          'color',
          'textureVal',
          'styleStrength',
          'undertoneX',
          'undertoneY',
        ]) {
          expect(exportParams[key], equals(previewParams[key]), reason: key);
        }
      },
    );

    test(
      'initialize reapplies edited active style after camera release',
      () async {
        const preset = PresetModel(
          id: 'rana_warm',
          name: 'Rana Warm',
          category: 'Classic',
          color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
          grain: PresetGrain(intensity: 0.1),
          vignette: PresetVignette(intensity: 0.05),
        );
        const editedStyle = RanaStyle(
          tone: -72,
          color: 33,
          texture: 64,
          styleStrength: 85,
          undertoneX: -0.4,
          undertoneY: 0.6,
        );
        final container = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _FakePresetRepository([preset]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await container.read(presetsProvider.future);
        await controller.initialize();
        await controller.selectPreset(preset);
        await controller.updateActiveStyle(editedStyle);
        await controller.releaseCamera();
        log.clear();

        await controller.initialize();

        final replayCall = log.singleWhere(
          (call) => call.method == 'selectPreset',
        );
        final replayArgs = replayCall.arguments as Map<dynamic, dynamic>;
        final params = replayArgs['params'] as Map<dynamic, dynamic>;
        expect(replayArgs['presetId'], equals('rana_warm'));
        expect(params['tone'], equals(-72.0));
        expect(params['color'], equals(33.0));
        expect(params['textureVal'], equals(64.0));
        expect(params['styleStrength'], equals(85.0));
        expect(params['undertoneX'], equals(-0.4));
        expect(params['undertoneY'], equals(0.6));
        expect(
          container.read(cameraControllerProvider).activeStyle,
          equals(editedStyle),
        );
      },
    );

    test(
      'reapplyActivePreviewParams no-ops when camera or preset is unavailable',
      () async {
        const preset = PresetModel(
          id: 'normal',
          name: 'Normal',
          category: 'Classic',
          color: PresetColor(temperature: 0, contrast: 0, saturation: 0),
          grain: PresetGrain(intensity: 0),
          vignette: PresetVignette(intensity: 0),
        );
        final uninitializedContainer = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _FakePresetRepository([preset]),
            ),
          ],
        );
        addTearDown(uninitializedContainer.dispose);
        await uninitializedContainer.read(presetsProvider.future);
        log.clear();

        await uninitializedContainer
            .read(cameraControllerProvider.notifier)
            .reapplyActivePreviewParams();
        expect(log, isEmpty);

        final missingPresetContainer = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _FakePresetRepository([]),
            ),
          ],
        );
        addTearDown(missingPresetContainer.dispose);
        final missingPresetController = missingPresetContainer.read(
          cameraControllerProvider.notifier,
        );
        await missingPresetContainer.read(presetsProvider.future);
        await missingPresetController.initialize();
        log.clear();

        await missingPresetController.reapplyActivePreviewParams();
        expect(log, isEmpty);
      },
    );

    test('capture uses the currently edited active style params', () async {
      const preset = PresetModel(
        id: 'rana_warm',
        name: 'Rana Warm',
        category: 'Classic',
        color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
        grain: PresetGrain(intensity: 0.1),
        vignette: PresetVignette(intensity: 0.05),
      );
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([preset]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await container.read(presetsProvider.future);
      await controller.initialize();
      await controller.selectPreset(preset);
      await controller.updateActiveStyle(
        const RanaStyle(
          tone: 24,
          color: 18,
          texture: 36,
          styleStrength: 80,
          undertoneX: 0.5,
          undertoneY: -0.25,
        ),
      );
      log.clear();

      await controller.capture();

      final captureCall = log.singleWhere(
        (call) => call.method == 'beginCapture',
      );
      final args = captureCall.arguments as Map<dynamic, dynamic>;
      expect(args['tone'], equals(24.0));
      expect(args['color'], equals(18.0));
      expect(args['textureVal'], equals(36.0));
      expect(args['styleStrength'], equals(80.0));
      expect(args['undertoneX'], equals(0.5));
      expect(args['undertoneY'], equals(-0.25));
    });

    test('cycleSelfTimer rotates through all available modes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();

      expect(
        container.read(cameraControllerProvider).selfTimerMode,
        equals(SelfTimerMode.off),
      );

      controller.cycleSelfTimer();
      expect(
        container.read(cameraControllerProvider).selfTimerMode,
        equals(SelfTimerMode.threeSeconds),
      );

      controller.cycleSelfTimer();
      expect(
        container.read(cameraControllerProvider).selfTimerMode,
        equals(SelfTimerMode.fiveSeconds),
      );

      controller.cycleSelfTimer();
      expect(
        container.read(cameraControllerProvider).selfTimerMode,
        equals(SelfTimerMode.tenSeconds),
      );

      controller.cycleSelfTimer();
      expect(
        container.read(cameraControllerProvider).selfTimerMode,
        equals(SelfTimerMode.off),
      );
    });

    test(
      'handleShutterPressed captures immediately when timer is off',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();
        log.clear();

        await controller.handleShutterPressed();

        expect(
          log.where((call) => call.method == 'beginCapture'),
          hasLength(1),
        );
        expect(
          container.read(cameraControllerProvider).captureStatus,
          equals(CaptureStatus.capturing),
        );
        expect(
          container.read(cameraControllerProvider).activeCaptureId,
          isNotNull,
        );

        await drainCaptureEvents();
        expect(
          container.read(cameraControllerProvider).captureStatus,
          equals(CaptureStatus.idle),
        );
        expect(
          container.read(cameraControllerProvider).lastCapturedPath,
          equals('/mock/path/photo.jpg'),
        );
      },
    );

    test('self timer counts down before triggering capture', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      controller.cycleSelfTimer();
      log.clear();

      fakeAsync((async) {
        controller.handleShutterPressed();

        expect(
          container.read(cameraControllerProvider).selfTimerRemainingSeconds,
          equals(3),
        );

        async.elapse(const Duration(seconds: 1));
        expect(
          container.read(cameraControllerProvider).selfTimerRemainingSeconds,
          equals(2),
        );

        async.elapse(const Duration(seconds: 1));
        expect(
          container.read(cameraControllerProvider).selfTimerRemainingSeconds,
          equals(1),
        );

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
      });

      await drainCaptureEvents();
      expect(log.where((call) => call.method == 'beginCapture'), hasLength(1));
      expect(
        container.read(cameraControllerProvider).captureStatus,
        equals(CaptureStatus.idle),
      );
      expect(
        container.read(cameraControllerProvider).selfTimerRemainingSeconds,
        equals(0),
      );
    });

    test(
      'releaseCamera cancels an active self timer without capturing',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();
        controller.cycleSelfTimer();
        log.clear();

        fakeAsync((async) {
          controller.handleShutterPressed();

          expect(
            container.read(cameraControllerProvider).selfTimerRemainingSeconds,
            equals(3),
          );

          async.elapse(const Duration(seconds: 1));
          expect(
            container.read(cameraControllerProvider).selfTimerRemainingSeconds,
            equals(2),
          );

          unawaited(controller.releaseCamera());
          expect(
            container.read(cameraControllerProvider).selfTimerRemainingSeconds,
            equals(0),
          );
          expect(
            container.read(cameraControllerProvider).selfTimerMode,
            equals(SelfTimerMode.threeSeconds),
          );

          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
        });

        expect(log.where((call) => call.method == 'beginCapture'), isEmpty);
        expect(
          container.read(cameraControllerProvider).isCameraInitialized,
          isFalse,
        );
      },
    );

    test('resetActiveStyle restores preset style or neutral values', () async {
      const presetStyle = RanaStyle(
        tone: 10,
        color: 20,
        texture: 30,
        styleStrength: 90,
      );
      const styledPreset = PresetModel(
        id: 'styled_preset',
        name: 'Styled Preset',
        category: 'Classic',
        color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
        grain: PresetGrain(intensity: 0.1),
        vignette: PresetVignette(intensity: 0.05),
        style: presetStyle,
      );
      const neutralPreset = PresetModel(
        id: 'neutral_preset',
        name: 'Neutral Preset',
        category: 'Classic',
        color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
        grain: PresetGrain(intensity: 0.1),
        vignette: PresetVignette(intensity: 0.05),
      );
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([styledPreset, neutralPreset]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await container.read(presetsProvider.future);
      await controller.initialize();

      await controller.selectPreset(styledPreset);
      await controller.updateActiveStyle(const RanaStyle(tone: -60));
      await controller.resetActiveStyle();
      expect(
        container.read(cameraControllerProvider).activeStyle,
        equals(presetStyle),
      );

      await controller.selectPreset(neutralPreset);
      await controller.updateActiveStyle(const RanaStyle(tone: 50));
      await controller.resetActiveStyle();
      expect(
        container.read(cameraControllerProvider).activeStyle,
        equals(const RanaStyle()),
      );
    });

    test(
      'capture flow stays available and updates the saved file path',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();
        log.clear();

        final states = <CameraState>[];
        container.listen<CameraState>(
          cameraControllerProvider,
          (previous, next) => states.add(next),
          fireImmediately: true,
        );

        await controller.capture();
        await drainCaptureEvents();

        expect(
          states.any((s) => s.captureStatus == CaptureStatus.capturing),
          isTrue,
        );
        expect(
          states.any((s) => s.captureStatus == CaptureStatus.processing),
          isFalse,
        );
        expect(
          states.any((s) => s.captureStatus == CaptureStatus.success),
          isFalse,
        );
        expect(
          states.any(
            (s) =>
                s.captureStatus == CaptureStatus.idle &&
                s.lastCapturedPath == '/mock/path/photo.jpg',
          ),
          isTrue,
        );
      },
    );

    test('capture completion returns immediately to idle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen<CameraState>(
        cameraControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();

      await controller.capture();
      await drainCaptureEvents();
      expect(
        container.read(cameraControllerProvider).captureStatus,
        equals(CaptureStatus.idle),
      );
      expect(
        container.read(cameraControllerProvider).completedCaptureId,
        equals('test-capture-1'),
      );
    });

    test('capture sends active preset params including LUT', () async {
      const warmPreset = PresetModel(
        id: 'rana_warm',
        name: 'Rana Warm',
        category: 'Classic',
        color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
        grain: PresetGrain(intensity: 0.1),
        vignette: PresetVignette(intensity: 0.05),
        lut: 'assets/luts/rana_warm_v1.png',
        effects: PresetEffects(
          lightLeak: LightLeakEffect(intensity: 0.22, variant: -1),
          dust: DustEffect(intensity: 0.06),
          bloom: PresetBloom(threshold: 0.65, intensity: 0.10),
          halation: PresetHalation(intensity: 0.08),
          lensDistortion: PresetLensDistortion(strength: 0.06),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([warmPreset]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await container.read(presetsProvider.future);
      await controller.initialize();
      await controller.selectPreset(warmPreset);
      final previewCall = log.singleWhere(
        (call) => call.method == 'selectPreset',
      );
      final previewArgs = previewCall.arguments as Map<dynamic, dynamic>;
      final previewParams = previewArgs['params'] as Map<dynamic, dynamic>;
      final previewVariant = previewParams['lightLeakVariant'] as int;
      expect(previewParams['lightLeakIntensity'], equals(0.22));
      expect(previewVariant, inInclusiveRange(0, 3));
      expect(previewParams['dustIntensity'], equals(0.06));
      expect(previewParams['bloomThreshold'], equals(0.65));
      expect(previewParams['bloomIntensity'], equals(0.10));
      expect(previewParams['halationIntensity'], equals(0.08));
      expect(previewParams['lensDistortionStrength'], equals(0.06));
      log.clear();

      await controller.capture();

      final captureCall = log.firstWhere(
        (call) => call.method == 'beginCapture',
      );
      final args = captureCall.arguments as Map<dynamic, dynamic>;
      expect(args['temperature'], equals(0.3));
      expect(args['saturation'], equals(0.1));
      expect(args['contrast'], equals(0.0));
      expect(args['grain'], equals(0.1));
      expect(args['vignette'], equals(0.05));
      expect(args['lutPath'], equals('assets/luts/rana_warm_v1.png'));
      expect(args['lutStrength'], equals(1.0));
      expect(args['outputQuality'], equals('high_jpeg'));
      expect(args['lightLeakIntensity'], equals(0.22));
      expect(args['lightLeakVariant'], equals(previewVariant));
      expect(args['dustIntensity'], equals(0.06));
      expect(args['bloomThreshold'], equals(0.65));
      expect(args['bloomIntensity'], equals(0.10));
      expect(args['halationIntensity'], equals(0.08));
      expect(args['lensDistortionStrength'], equals(0.06));
    });

    test('capture sends neutral params when preset is unavailable', () async {
      final container = ProviderContainer(
        overrides: [
          presetRepositoryProvider.overrideWithValue(
            const _FakePresetRepository([]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await container.read(presetsProvider.future);
      await controller.initialize();
      log.clear();

      await controller.capture();

      final captureCall = log.firstWhere(
        (call) => call.method == 'beginCapture',
      );
      final args = captureCall.arguments as Map<dynamic, dynamic>;
      expect(args['temperature'], equals(0.0));
      expect(args['saturation'], equals(0.0));
      expect(args['contrast'], equals(0.0));
      expect(args['grain'], equals(0.0));
      expect(args['vignette'], equals(0.0));
      expect(args['lutPath'], isNull);
      expect(args['lutStrength'], equals(0.0));
      expect(args['lightLeakIntensity'], equals(0.0));
      expect(args['lightLeakVariant'], equals(-1));
      expect(args['dustIntensity'], equals(0.0));
      expect(args['bloomThreshold'], equals(0.8));
      expect(args['bloomIntensity'], equals(0.0));
      expect(args['halationIntensity'], equals(0.0));
      expect(args['lensDistortionStrength'], equals(0.0));
    });

    test(
      'a second capture starts while the first is still processing',
      () async {
        final captureCompleter = Completer<Map<String, dynamic>>();
        executeCaptureHandler = (_) => captureCompleter.future;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();
        log.clear();

        await controller.capture();
        await drainCaptureEvents();
        expect(
          container.read(cameraControllerProvider).captureStatus,
          equals(CaptureStatus.idle),
        );

        await controller.capture();
        await drainCaptureEvents();

        final captureCalls = log
            .where((call) => call.method == 'beginCapture')
            .toList();
        expect(captureCalls.length, equals(2));

        captureCompleter.complete({
          'status': 'captured',
          'filePath': '/mock/path/photo.jpg',
        });
        await drainCaptureEvents();
        expect(
          container.read(cameraControllerProvider).lastCapturedPath,
          equals('/mock/path/photo.jpg'),
        );
      },
    );

    test(
      'acknowledgeResultDismissed resets to idle and preserves camera config',
      () async {
        const warmPreset = PresetModel(
          id: 'rana_warm',
          name: 'Rana Warm',
          category: 'Classic',
          color: PresetColor(temperature: 0.3, contrast: 0, saturation: 0.1),
          grain: PresetGrain(intensity: 0.1),
          vignette: PresetVignette(intensity: 0.05),
          lut: 'assets/luts/rana_warm_v1.png',
        );
        final container = ProviderContainer(
          overrides: [
            presetRepositoryProvider.overrideWithValue(
              const _FakePresetRepository([warmPreset]),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen<CameraState>(
          cameraControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final controller = container.read(cameraControllerProvider.notifier);
        await container.read(presetsProvider.future);
        await controller.initialize();
        await controller.toggleFlashMode();
        await controller.toggleLens();
        await controller.selectPreset(warmPreset);
        await controller.capture();
        await drainCaptureEvents();

        final successState = container.read(cameraControllerProvider);
        expect(successState.captureStatus, equals(CaptureStatus.idle));
        expect(successState.completedCaptureId, equals('test-capture-1'));
        expect(successState.activePresetId, equals('rana_warm'));
        expect(successState.flashMode, equals(FlashMode.on));
        expect(successState.activeLens, equals(CameraLens.front));
        expect(successState.lastCapturedPath, equals('/mock/path/photo.jpg'));

        controller.acknowledgeResultDismissed();

        final dismissedState = container.read(cameraControllerProvider);
        expect(dismissedState.captureStatus, equals(CaptureStatus.idle));
        expect(dismissedState.completedCaptureId, isNull);
        expect(dismissedState.activePresetId, equals('rana_warm'));
        expect(dismissedState.flashMode, equals(FlashMode.on));
        expect(dismissedState.activeLens, equals(CameraLens.front));
        expect(dismissedState.lastCapturedPath, equals('/mock/path/photo.jpg'));
      },
    );

    test('capture error keeps the shutter available', () async {
      executeCaptureHandler = (_) async {
        throw PlatformException(
          code: 'CAPTURE_FAILED',
          message: 'Native capture failed',
        );
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      final states = <CameraState>[];
      container.listen<CameraState>(
        cameraControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      await controller.capture();
      await drainCaptureEvents();
      expect(
        container.read(cameraControllerProvider).captureStatus,
        equals(CaptureStatus.idle),
      );
      expect(
        states.any((s) => s.captureStatus == CaptureStatus.error),
        isFalse,
      );
      expect(
        container.read(cameraControllerProvider).captureError,
        contains('Native capture failed'),
      );
    });

    test(
      'receiving EventChannel FPS updates updates state currentFps',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(cameraControllerProvider.notifier);
        await controller.initialize();

        // Send event to EventChannel
        const codec = StandardMethodCodec();
        final data = codec.encodeSuccessEnvelope({
          'type': 'status_update',
          'fps': 27,
          'active': true,
        });

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'com.rana.app/camera_status',
              data,
              (ByteData? reply) {},
            );

        final state = container.read(cameraControllerProvider);
        expect(state.currentFps, equals(27));
      },
    );
  });
}

class _FakePresetRepository implements PresetRepository {
  const _FakePresetRepository(this.presets);

  final List<PresetModel> presets;

  @override
  Future<List<PresetModel>> loadAll() async => presets;
}
