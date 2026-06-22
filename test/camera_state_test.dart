import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/features/camera/controller/camera_controller.dart';
import 'package:rana/features/camera/state/camera_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraState & Native Bridge', () {
    const methodChannel = MethodChannel('com.rana.app/camera_control');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        methodChannel,
        (MethodCall methodCall) async {
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
              return {
                'status': 'flash_set',
                'flashMode': args['flashMode'],
              };
            case 'toggleLens':
              final args = methodCall.arguments as Map<dynamic, dynamic>;
              final currentLens = args['lens'] as String;
              final nextLens = currentLens == 'back' ? 'front' : 'back';
              return {'status': 'lens_toggled', 'lens': nextLens};
            case 'executeCapture':
              return {'status': 'captured', 'filePath': '/mock/path/photo.jpg'};
            default:
              return null;
          }
        },
      );
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
    });

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

      await controller.selectPreset('classic_f1');
      final state = container.read(cameraControllerProvider);
      expect(state.activePresetId, equals('classic_f1'));
      expect(log.length, equals(1));
      expect(log.first.method, equals('selectPreset'));
      final args = log.first.arguments as Map<dynamic, dynamic>;
      expect(args['presetId'], equals('classic_f1'));
    });

    test(
        'capture flow simulates delay and updates captureStatus and file path',
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

      // Verify state transitions:
      // 1. Initial/current state is idle
      // 2. Transited to capturing
      // 3. Transited to success with filePath set
      // 4. (Optional/Eventually) Transited back to idle
      expect(
        states.any((s) => s.captureStatus == CaptureStatus.capturing),
        isTrue,
      );
      expect(
        states.any((s) =>
            s.captureStatus == CaptureStatus.success &&
            s.lastCapturedPath == '/mock/path/photo.jpg'),
        isTrue,
      );
    });

    test('receiving EventChannel FPS updates updates state currentFps',
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
    });
  });
}
