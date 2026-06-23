import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/providers/preset_provider.dart';
import 'package:rana/features/camera/controller/camera_controller.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/repository/preset_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraState & Native Bridge', () {
    const methodChannel = MethodChannel('com.rana.app/camera_control');
    final log = <MethodCall>[];
    Future<Map<String, dynamic>> Function(MethodCall methodCall)?
    executeCaptureHandler;

    setUp(() {
      log.clear();
      executeCaptureHandler = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (
            MethodCall methodCall,
          ) async {
            log.add(methodCall);
            switch (methodCall.method) {
              case 'initializeCamera':
                return {'status': 'initialized', 'lens': 'back'};
              case 'selectPreset':
                final args = methodCall.arguments as Map<dynamic, dynamic>;
                return {
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
                return {'status': 'lens_toggled', 'lens': nextLens};
              case 'executeCapture':
                return executeCaptureHandler?.call(methodCall) ??
                    {'status': 'captured', 'filePath': '/mock/path/photo.jpg'};
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
    });

    test('initialize registers and connects channels successfully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();

      final state = container.read(cameraControllerProvider);
      expect(state.isCameraInitialized, isTrue);
      expect(state.activeLens, equals(CameraLens.back));
      expect(log.length, equals(1));
      expect(log.first.method, equals('initializeCamera'));
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
      expect(params['bloomThreshold'], equals(0.8));
      expect(params['bloomIntensity'], equals(0.0));
      expect(params['halationIntensity'], equals(0.0));
      expect(params['lensDistortionStrength'], equals(0.0));
    });

    test('capture flow enters processing and updates file path', () async {
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

      // Verify state transitions:
      // 1. Initial/current state is idle
      // 2. Transited to capturing
      // 3. Transited to processing while native work is active
      // 4. Transited to success with filePath set
      expect(
        states.any((s) => s.captureStatus == CaptureStatus.capturing),
        isTrue,
      );
      expect(
        states.any((s) => s.captureStatus == CaptureStatus.processing),
        isTrue,
      );
      expect(
        states.any(
          (s) =>
              s.captureStatus == CaptureStatus.success &&
              s.lastCapturedPath == '/mock/path/photo.jpg',
        ),
        isTrue,
      );
    });

    test('capture success remains active until result is dismissed', () async {
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
      expect(
        container.read(cameraControllerProvider).captureStatus,
        equals(CaptureStatus.success),
      );

      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(
        container.read(cameraControllerProvider).captureStatus,
        equals(CaptureStatus.success),
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
          lightLeak: LightLeakEffect(intensity: 0, variant: -1),
          dust: DustEffect(intensity: 0),
          bloom: PresetBloom(threshold: 0.7, intensity: 0.10),
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
      log.clear();

      await controller.capture();

      final captureCall = log.firstWhere(
        (call) => call.method == 'executeCapture',
      );
      final args = captureCall.arguments as Map<dynamic, dynamic>;
      expect(args['temperature'], equals(0.3));
      expect(args['saturation'], equals(0.1));
      expect(args['contrast'], equals(0.0));
      expect(args['grain'], equals(0.1));
      expect(args['vignette'], equals(0.05));
      expect(args['lutPath'], equals('assets/luts/rana_warm_v1.png'));
      expect(args['lutStrength'], equals(1.0));
      expect(args['bloomThreshold'], equals(0.7));
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
        (call) => call.method == 'executeCapture',
      );
      final args = captureCall.arguments as Map<dynamic, dynamic>;
      expect(args['temperature'], equals(0.0));
      expect(args['saturation'], equals(0.0));
      expect(args['contrast'], equals(0.0));
      expect(args['grain'], equals(0.0));
      expect(args['vignette'], equals(0.0));
      expect(args['lutPath'], isNull);
      expect(args['lutStrength'], equals(0.0));
      expect(args['bloomThreshold'], equals(0.8));
      expect(args['bloomIntensity'], equals(0.0));
      expect(args['halationIntensity'], equals(0.0));
      expect(args['lensDistortionStrength'], equals(0.0));
    });

    test('rapid duplicate capture calls invoke native capture once', () async {
      final captureCompleter = Completer<Map<String, dynamic>>();
      executeCaptureHandler = (_) => captureCompleter.future;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(cameraControllerProvider.notifier);
      await controller.initialize();
      log.clear();

      final firstCapture = controller.capture();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final secondCapture = controller.capture();
      captureCompleter.complete({
        'status': 'captured',
        'filePath': '/mock/path/photo.jpg',
      });
      await Future.wait([firstCapture, secondCapture]);

      final captureCalls = log
          .where((call) => call.method == 'executeCapture')
          .toList();
      expect(captureCalls.length, equals(1));
    });

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

        final successState = container.read(cameraControllerProvider);
        expect(successState.captureStatus, equals(CaptureStatus.success));
        expect(successState.activePresetId, equals('rana_warm'));
        expect(successState.flashMode, equals(FlashMode.on));
        expect(successState.activeLens, equals(CameraLens.front));
        expect(successState.lastCapturedPath, equals('/mock/path/photo.jpg'));

        controller.acknowledgeResultDismissed();

        final dismissedState = container.read(cameraControllerProvider);
        expect(dismissedState.captureStatus, equals(CaptureStatus.idle));
        expect(dismissedState.activePresetId, equals('rana_warm'));
        expect(dismissedState.flashMode, equals(FlashMode.on));
        expect(dismissedState.activeLens, equals(CameraLens.front));
        expect(dismissedState.lastCapturedPath, equals('/mock/path/photo.jpg'));
      },
    );

    test('capture error resets status back to idle', () async {
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
      expect(states.any((s) => s.captureStatus == CaptureStatus.error), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(
        container.read(cameraControllerProvider).captureStatus,
        equals(CaptureStatus.idle),
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
