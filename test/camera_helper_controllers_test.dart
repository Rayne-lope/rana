import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rana/core/services/camera_platform_service.dart';
import 'package:rana/features/camera/state/camera_state.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/rana_style.dart';
import 'package:rana/features/settings/provider/settings_provider.dart';
import 'package:rana/src/features/camera/controller/camera_lifecycle_controller.dart';
import 'package:rana/src/features/camera/controller/camera_recipe_builder.dart';
import 'package:rana/src/features/camera/controller/camera_timer_controller.dart';
import 'package:rana/src/features/camera/controller/camera_zoom_controller.dart';

final class _FakeCameraPlatformService extends CameraPlatformService {
  final List<Completer<Map<String, dynamic>>> zoomRequests =
      <Completer<Map<String, dynamic>>>[];
  final StreamController<Map<String, dynamic>> statusController =
      StreamController<Map<String, dynamic>>.broadcast();
  Completer<Map<String, dynamic>>? initializeCompleter;
  int releaseCount = 0;

  @override
  Future<Map<String, dynamic>> initializeCamera() =>
      initializeCompleter?.future ??
      Future<Map<String, dynamic>>.value(<String, dynamic>{});

  @override
  Future<Map<String, dynamic>> releaseCamera() async {
    releaseCount += 1;
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> setZoomRatio(double zoomRatio) {
    final completer = Completer<Map<String, dynamic>>();
    zoomRequests.add(completer);
    return completer.future;
  }

  @override
  Stream<Map<String, dynamic>> get statusStream => statusController.stream;

  Future<void> dispose() => statusController.close();
}

void main() {
  group('CameraRecipeBuilder', () {
    const preset = PresetModel(
      id: 'test',
      name: 'Test',
      category: 'Classic',
      color: PresetColor(temperature: 0.2, contrast: 0.3, saturation: 0.4),
      grain: PresetGrain(intensity: 0.25, size: 1.2),
      vignette: PresetVignette(intensity: 0.1),
      style: RanaStyle(tone: 5, texture: 20, styleStrength: 30),
    );

    test('keeps shared preview and capture wire parameters identical', () {
      const builder = CameraRecipeBuilder();
      const style = RanaStyle(tone: 8, texture: 35, styleStrength: 45);
      final preview = builder.buildPreviewParams(
        preset: preset,
        style: style,
        previewVariant: 2,
      );
      final capture = builder.buildCaptureParams(
        preset: preset,
        style: style,
        previewVariant: 2,
        outputQuality: OutputQuality.highJpeg,
        filmRollId: 'roll-1',
      );

      for (final entry in preview.entries) {
        expect(capture[entry.key], equals(entry.value), reason: entry.key);
      }
      expect(
        capture.keys.toSet().difference(preview.keys.toSet()),
        equals(<String>{
          'outputQuality',
          'presetId',
          'isStyleModified',
          'filmRollId',
        }),
      );
      expect(capture['outputQuality'], equals('high_jpeg'));
      expect(capture['filmRollId'], equals('roll-1'));
    });

    test('derives preview and capture adapters from one typed snapshot', () {
      const builder = CameraRecipeBuilder();
      const style = RanaStyle(tone: 8, texture: 35, styleStrength: 45);
      final recipe = builder.buildRecipe(
        preset: preset,
        style: style,
        previewVariant: 2,
        outputQuality: OutputQuality.highJpeg,
        aspectRatio: 'square_1_1',
      );
      final preview = builder.previewParamsFor(recipe);
      final capture = builder.captureParamsFor(recipe, filmRollId: 'roll-1');

      for (final entry in preview.entries) {
        expect(capture[entry.key], equals(entry.value), reason: entry.key);
      }
      expect(recipe.aspectRatio, 'square_1_1');
      expect(recipe.presetId, preset.id);
      expect(capture['filmRollId'], 'roll-1');
      expect(capture, isNot(contains('aspectRatio')));
    });

    test('clamps every editable style dimension', () {
      const builder = CameraRecipeBuilder();
      final clamped = builder.clampStyle(
        const RanaStyle(
          tone: 150,
          color: -150,
          texture: 120,
          styleStrength: -10,
          undertoneX: 2,
          undertoneY: -2,
        ),
      );

      expect(clamped.tone, equals(100));
      expect(clamped.color, equals(-100));
      expect(clamped.texture, equals(100));
      expect(clamped.styleStrength, equals(0));
      expect(clamped.undertoneX, equals(1));
      expect(clamped.undertoneY, equals(-1));
    });
  });

  group('CameraTimerController', () {
    test('dispose cancels countdown without a delayed capture', () {
      fakeAsync((async) {
        var state = CameraState.initial().copyWith(isCameraInitialized: true);
        var captureCount = 0;
        final controller = CameraTimerController(
          readState: () => state,
          writeState: (nextState) => state = nextState,
          captureBlockReason: () => null,
          capture: () async {
            captureCount += 1;
          },
        );

        controller.start(SelfTimerMode.threeSeconds);
        async.elapse(const Duration(seconds: 1));
        expect(state.selfTimerRemainingSeconds, equals(2));

        controller.dispose();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(captureCount, equals(0));
      });
    });
  });

  group('CameraZoomController', () {
    test('debounce coalesces pinch updates to the latest ratio', () {
      fakeAsync((async) {
        final platform = _FakeCameraPlatformService();
        var state = CameraState.initial().copyWith(isCameraInitialized: true);
        final controller = CameraZoomController(
          platformService: platform,
          readState: () => state,
          writeState: (nextState) => state = nextState,
        );

        unawaited(controller.setZoomRatio(1.5, commit: false));
        unawaited(controller.setZoomRatio(2.5, commit: false));
        async.elapse(const Duration(milliseconds: 15));
        expect(platform.zoomRequests, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(platform.zoomRequests, hasLength(1));
        expect(state.zoomRatio, equals(2.5));
        platform.zoomRequests.single.complete(<String, dynamic>{
          'zoomRatio': 2.5,
        });
        async.flushMicrotasks();
        unawaited(platform.dispose());
      });
    });

    test('ignores a native zoom response from an older generation', () async {
      final platform = _FakeCameraPlatformService();
      var state = CameraState.initial().copyWith(isCameraInitialized: true);
      final controller = CameraZoomController(
        platformService: platform,
        readState: () => state,
        writeState: (nextState) => state = nextState,
      );

      final first = controller.setZoomRatio(2);
      final second = controller.setZoomRatio(2.5);
      platform.zoomRequests[1].complete(<String, dynamic>{'zoomRatio': 2.5});
      await second;
      platform.zoomRequests[0].complete(<String, dynamic>{'zoomRatio': 2});
      await first;

      expect(state.zoomRatio, equals(2.5));
      await platform.dispose();
    });
  });

  group('CameraLifecycleController', () {
    test('releases a native initialization invalidated by pause', () async {
      final platform = _FakeCameraPlatformService();
      final initializeCompleter = Completer<Map<String, dynamic>>();
      platform.initializeCompleter = initializeCompleter;
      var state = CameraState.initial();
      final controller = CameraLifecycleController(
        platformService: platform,
        readState: () => state,
        writeState: (nextState) => state = nextState,
        applyInitializeResult: (_) {
          state = state.copyWith(isCameraInitialized: true);
        },
        configureInitializedCamera: (_) async {},
        handleStatusEvent: (_) {},
        prepareRelease: () {},
        hasCaptureWork: () => false,
      );

      final initialization = controller.initialize();
      final release = controller.releaseCamera();
      initializeCompleter.complete(<String, dynamic>{});
      await Future.wait<void>(<Future<void>>[initialization, release]);
      await Future<void>.delayed(Duration.zero);

      expect(state.isCameraInitialized, isFalse);
      expect(platform.releaseCount, equals(1));
      controller.dispose();
      await platform.dispose();
    });

    test('keeps status subscription through release until dispose', () async {
      final platform = _FakeCameraPlatformService();
      var state = CameraState.initial();
      var receivedStatusCount = 0;
      final controller = CameraLifecycleController(
        platformService: platform,
        readState: () => state,
        writeState: (nextState) => state = nextState,
        applyInitializeResult: (_) {
          state = state.copyWith(isCameraInitialized: true);
        },
        configureInitializedCamera: (_) async {},
        handleStatusEvent: (_) {
          receivedStatusCount += 1;
        },
        prepareRelease: () {},
        hasCaptureWork: () => false,
      );

      await controller.initialize();
      await controller.releaseCamera();
      platform.statusController.add(<String, dynamic>{'type': 'capture_done'});
      await Future<void>.delayed(Duration.zero);
      expect(receivedStatusCount, equals(1));

      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      platform.statusController.add(<String, dynamic>{'type': 'ignored'});
      await Future<void>.delayed(Duration.zero);
      expect(receivedStatusCount, equals(1));
      await platform.dispose();
    });
  });
}
