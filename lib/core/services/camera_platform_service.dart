import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rana/core/utils/app_logger.dart';
import 'package:rana/features/camera/telemetry/camera_telemetry.dart';
import 'package:rana/features/preset/model/capture_style_metadata.dart';
import 'package:rana/features/render/model/render_recipe.dart';
import 'package:rana/src/platform/rana_camera_api.g.dart' as pigeon;
import 'package:rana/src/platform/rana_camera_pigeon_mapper.dart';

/// A successful native capture durably associated with a Film Roll.
class FilmRollCaptureRecord {
  const FilmRollCaptureRecord({
    required this.mediaUri,
    required this.capturedAt,
  });

  factory FilmRollCaptureRecord.fromChannelMap(Map<dynamic, dynamic> map) {
    final mediaUri = map['mediaUri'];
    final capturedAtEpochMs = map['capturedAtEpochMs'];
    if (mediaUri is! String || mediaUri.isEmpty) {
      throw const FormatException(
        'Film Roll capture record is missing mediaUri',
      );
    }
    if (capturedAtEpochMs is! num) {
      throw const FormatException(
        'Film Roll capture record is missing capturedAtEpochMs',
      );
    }
    return FilmRollCaptureRecord(
      mediaUri: mediaUri,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        capturedAtEpochMs.toInt(),
      ),
    );
  }

  final String mediaUri;
  final DateTime capturedAt;
}

@immutable
final class CameraPreviewRegistration {
  const CameraPreviewRegistration({
    required this.platformViewId,
    required this.aspectRatio,
    required this.lens,
    required this.flashMode,
    required this.zoomRatio,
  });

  final int platformViewId;
  final String aspectRatio;
  final String lens;
  final String flashMode;
  final double zoomRatio;
}

/// Typed Pigeon adapter exposed to the existing camera domain façade.
///
/// Generated Pigeon classes do not escape this service. The legacy channel is
/// reachable only in debug/test builds so old integration harnesses remain
/// useful while production camera traffic is compile-time typed.
class CameraPlatformService {
  CameraPlatformService({pigeon.RanaCameraHostApi? hostApi})
    : _hostApi = hostApi ?? pigeon.RanaCameraHostApi();

  static const MethodChannel _debugLegacyChannel = MethodChannel(
    'com.rana.app/camera_control',
  );

  /// Explicit opt-in for legacy Method/EventChannel test harnesses.
  @visibleForTesting
  static bool useLegacyChannelsForTests = false;

  final pigeon.RanaCameraHostApi _hostApi;
  CameraPreviewRegistration? _previewRegistration;

  // Registration is an event with generation semantics, not a plain property.
  // ignore: use_setters_to_change_properties
  void registerPlatformView(CameraPreviewRegistration registration) {
    _previewRegistration = registration;
  }

  void unregisterPlatformView(int platformViewId) {
    if (_previewRegistration?.platformViewId == platformViewId) {
      _previewRegistration = null;
    }
  }

  Future<T> _call<T>({
    required Future<T> Function() pigeonCall,
    required Future<T> Function() debugLegacyCall,
  }) async {
    if (kDebugMode && useLegacyChannelsForTests) {
      return debugLegacyCall();
    }
    try {
      return await pigeonCall();
    } on PlatformException catch (error) {
      if (!kDebugMode || error.code != 'channel-error') rethrow;
      return debugLegacyCall();
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'CameraPlatformService',
        'Unexpected Pigeon bridge failure',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initializeCamera() async {
    final registration = _previewRegistration;
    if (registration == null) {
      if (kDebugMode && useLegacyChannelsForTests) {
        return _legacyMap('initializeCamera');
      }
      throw PlatformException(
        code: 'CAMERA_NOT_READY',
        message: 'Camera preview not initialized',
      );
    }
    return _call(
      pigeonCall: () async => operationResultToMap(
        await _hostApi.initializeCamera(
          pigeon.InitializeCameraRequest(
            platformViewId: registration.platformViewId,
            aspectRatio: registration.aspectRatio,
            lens: registration.lens,
            flashMode: registration.flashMode,
            zoomRatio: registration.zoomRatio,
          ),
        ),
      ),
      debugLegacyCall: () => _legacyMap('initializeCamera'),
    );
  }

  Future<Map<String, dynamic>> getOutputCapabilities() => _call(
    pigeonCall: () async {
      final result = await _hostApi.getOutputCapabilities();
      return <String, dynamic>{
        'isHeicSupported': result.isHeicSupported,
        'unavailableReason': result.unavailableReason,
      };
    },
    debugLegacyCall: () => _legacyMap('getOutputCapabilities'),
  );

  Future<Map<String, dynamic>> getPermissionCapabilities() => _call(
    pigeonCall: () async {
      final result = await _hostApi.getPermissionCapabilities();
      return <String, dynamic>{
        'requiresLegacyStorageForCapture':
            result.requiresLegacyStorageForCapture,
        'galleryReadPermission': result.galleryReadPermission,
      };
    },
    debugLegacyCall: () => _legacyMap('getPermissionCapabilities'),
  );

  Future<Map<String, dynamic>> selectPreset(
    String presetId,
    Map<String, dynamic> params,
  ) {
    final recipe = RenderRecipeV1.fromMap(<String, dynamic>{
      ...params,
      'presetId': presetId,
    });
    return _call(
      pigeonCall: () async => operationResultToMap(
        await _hostApi.applyRecipe(recipeToPigeon(recipe)),
      ),
      debugLegacyCall: () => _legacyMap('selectPreset', <String, dynamic>{
        'presetId': presetId,
        'params': params,
      }),
    );
  }

  Future<Map<String, dynamic>> executeCapture(Map<String, dynamic> params) =>
      _call(
        pigeonCall: () async => captureResultToMap(
          await _hostApi.executeCapture(_captureRequest(params)),
        ),
        debugLegacyCall: () => _legacyMap('executeCapture', params),
      );

  Future<Map<String, dynamic>> beginCapture(Map<String, dynamic> params) =>
      _call(
        pigeonCall: () async {
          final result = await _hostApi.beginCapture(_captureRequest(params));
          return <String, dynamic>{
            'status': result.status,
            'captureId': result.captureId,
          };
        },
        debugLegacyCall: () => _legacyMap('beginCapture', params),
      );

  pigeon.CaptureRequestMessage _captureRequest(Map<String, dynamic> params) =>
      pigeon.CaptureRequestMessage(
        recipe: recipeToPigeon(RenderRecipeV1.fromMap(params)),
        filmRollId: params['filmRollId'] as String?,
      );

  Future<Uint8List> loadCapturedImageBytes(
    String uri, {
    int? targetSize,
  }) async {
    final startedAt = DateTime.now();
    final result = await _call(
      pigeonCall: () => _hostApi.loadCapturedImageBytes(uri, targetSize),
      debugLegacyCall: () async =>
          await _debugLegacyChannel.invokeMethod<Uint8List>(
            'loadCapturedImageBytes',
            <String, dynamic>{'uri': uri, 'targetSize': targetSize},
          ) ??
          Uint8List(0),
    );
    AppLogger.i(
      'RanaCaptureTimeline',
      'event=image_bytes_loaded uri=$uri targetSize=$targetSize '
          'elapsedMs=${DateTime.now().difference(startedAt).inMilliseconds}',
    );
    return result;
  }

  Future<void> openMediaInGallery(String uri) => _call(
    pigeonCall: () => _hostApi.openMediaInGallery(uri),
    debugLegacyCall: () => _debugLegacyChannel.invokeMethod<void>(
      'openMediaInGallery',
      <String, dynamic>{'uri': uri},
    ),
  );

  Future<Map<String, dynamic>> setFlashMode(String flashMode) => _call(
    pigeonCall: () async =>
        operationResultToMap(await _hostApi.setFlashMode(flashMode)),
    debugLegacyCall: () =>
        _legacyMap('setFlashMode', <String, dynamic>{'flashMode': flashMode}),
  );

  Future<Map<String, dynamic>> toggleLens(String currentLens) => _call(
    pigeonCall: () async =>
        operationResultToMap(await _hostApi.toggleLens(currentLens)),
    debugLegacyCall: () =>
        _legacyMap('toggleLens', <String, dynamic>{'lens': currentLens}),
  );

  Future<Map<String, dynamic>> setAspectRatio(String aspectRatio) => _call(
    pigeonCall: () async =>
        operationResultToMap(await _hostApi.setAspectRatio(aspectRatio)),
    debugLegacyCall: () => _legacyMap('setAspectRatio', <String, dynamic>{
      'aspectRatio': aspectRatio,
    }),
  );

  Future<Map<String, dynamic>> releaseCamera() => _call(
    pigeonCall: () async =>
        operationResultToMap(await _hostApi.releaseCamera()),
    debugLegacyCall: () => _legacyMap('releaseCamera'),
  );

  Future<List<FilmRollCaptureRecord>> listFilmRollCaptures(String filmRollId) =>
      _call(
        pigeonCall: () async =>
            (await _hostApi.listFilmRollCaptures(filmRollId))
                .map(
                  (record) => FilmRollCaptureRecord(
                    mediaUri: record.mediaUri,
                    capturedAt: DateTime.fromMillisecondsSinceEpoch(
                      record.capturedAtEpochMs,
                    ),
                  ),
                )
                .toList(growable: false),
        debugLegacyCall: () async {
          final result = await _debugLegacyChannel
              .invokeListMethod<Map<dynamic, dynamic>>(
                'listFilmRollCaptures',
                <String, dynamic>{'filmRollId': filmRollId},
              );
          return (result ?? const <Map<dynamic, dynamic>>[])
              .map(FilmRollCaptureRecord.fromChannelMap)
              .toList(growable: false);
        },
      );

  Stream<Map<String, dynamic>> get statusStream {
    if (kDebugMode && useLegacyChannelsForTests) {
      return const EventChannel(
        'com.rana.app/camera_status',
      ).receiveBroadcastStream().map(
        (event) => Map<String, dynamic>.from(event as Map<dynamic, dynamic>),
      );
    }
    final hub = _CameraFlutterEventHub.instance..activate();
    return hub.stream;
  }

  Future<Map<String, dynamic>> setZoomRatio(double zoomRatio) => _call(
    pigeonCall: () async =>
        operationResultToMap(await _hostApi.setZoomRatio(zoomRatio)),
    debugLegacyCall: () =>
        _legacyMap('setZoomRatio', <String, dynamic>{'zoomRatio': zoomRatio}),
  );

  Future<void> setFocusAndMetering(double x, double y) => _call(
    pigeonCall: () => _hostApi.setFocusAndMetering(x, y),
    debugLegacyCall: () => _debugLegacyChannel.invokeMethod<void>(
      'setFocusAndMetering',
      <String, dynamic>{'x': x, 'y': y},
    ),
  );

  Future<void> cancelFocusAndMetering() => _call(
    pigeonCall: _hostApi.cancelFocusAndMetering,
    debugLegacyCall: () =>
        _debugLegacyChannel.invokeMethod<void>('cancelFocusAndMetering'),
  );

  Future<CaptureStyleMetadata?> getCaptureStyleMetadata(String uri) => _call(
    pigeonCall: () async {
      final result = await _hostApi.getCaptureStyleMetadata(uri);
      return result == null ? null : metadataFromPigeon(result);
    },
    debugLegacyCall: () async {
      final result = await _debugLegacyChannel
          .invokeMethod<Map<dynamic, dynamic>>(
            'getCaptureStyleMetadata',
            <String, dynamic>{'uri': uri},
          );
      return result == null ? null : CaptureStyleMetadata.fromMap(result);
    },
  );

  Future<Map<String, CaptureStyleMetadata>> getCaptureStyleMetadataBatch(
    List<String> uris,
  ) async {
    if (uris.isEmpty) return const <String, CaptureStyleMetadata>{};
    return _call(
      pigeonCall: () async => <String, CaptureStyleMetadata>{
        for (final metadata in await _hostApi.getCaptureStyleMetadataBatch(
          uris,
        ))
          metadata.mediaUri: metadataFromPigeon(metadata),
      },
      debugLegacyCall: () async {
        final result = await _debugLegacyChannel
            .invokeListMethod<Map<dynamic, dynamic>>(
              'getCaptureStyleMetadataBatch',
              <String, dynamic>{'uris': uris},
            );
        return <String, CaptureStyleMetadata>{
          for (final item in result ?? const <Map<dynamic, dynamic>>[])
            CaptureStyleMetadata.fromMap(item).mediaUri:
                CaptureStyleMetadata.fromMap(item),
        };
      },
    );
  }

  Future<Map<String, dynamic>> _legacyMap(
    String method, [
    Object? arguments,
  ]) async {
    final result = await _debugLegacyChannel
        .invokeMethod<Map<dynamic, dynamic>>(method, arguments);
    return Map<String, dynamic>.from(result ?? <dynamic, dynamic>{});
  }
}

final class _CameraFlutterEventHub implements pigeon.RanaCameraFlutterApi {
  _CameraFlutterEventHub._();

  static final _CameraFlutterEventHub instance = _CameraFlutterEventHub._();
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _events.stream;

  void activate() => pigeon.RanaCameraFlutterApi.setUp(this);

  @override
  void onPreviewMetrics(pigeon.PreviewMetricsMessage event) {
    CameraTelemetry.instance.record('preview_average_fps', event.fps);
    _events.add(<String, dynamic>{
      'type': 'status_update',
      'fps': event.fps,
      'active': event.active,
      'timestamp': event.timestampEpochMs,
      'firstFrame': event.firstFrame,
    });
  }

  @override
  void onCaptureProgress(pigeon.CaptureProgressMessage event) {
    _events.add(<String, dynamic>{
      'type': 'capture_progress',
      'captureId': event.captureId,
      'phase': event.phase,
      'elapsedMs': event.elapsedMs,
    });
  }

  @override
  void onCaptureCompleted(pigeon.CaptureCompletedMessage event) {
    _events.add(<String, dynamic>{
      'type': 'capture_completed',
      'captureId': event.captureId,
      'uri': event.uri,
      ...captureResultToMap(event.output),
      'elapsedMs': event.elapsedMs,
    });
  }

  @override
  void onCaptureFailure(pigeon.CaptureFailureMessage event) {
    _events.add(<String, dynamic>{
      'type': 'capture_failed',
      'captureId': event.captureId,
      'errorCode': event.code,
      'message': event.message,
      'elapsedMs': event.elapsedMs,
    });
  }

  @override
  void onRendererError(pigeon.RendererErrorMessage event) {
    _events.add(<String, dynamic>{
      'type': 'renderer_error',
      'errorCode': event.code,
      'message': event.message,
    });
  }

  @override
  void onTelemetry(pigeon.TelemetryMessage event) {
    CameraTelemetry.instance.record(
      event.name,
      event.value,
      monotonicTimestampUs: event.monotonicTimestampUs,
    );
    _events.add(<String, dynamic>{
      'type': 'telemetry',
      'name': event.name,
      'timestampUs': event.monotonicTimestampUs,
      'value': event.value,
    });
  }
}
