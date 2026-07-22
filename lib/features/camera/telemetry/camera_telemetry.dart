import 'dart:collection';

import 'package:flutter/foundation.dart';

const Set<String> cameraTelemetryMetricNames = {
  'camera_initialize_ms',
  'camera_bind_ms',
  'first_preview_frame_ms',
  'preview_average_fps',
  'preview_p95_frame_ms',
  'preview_dropped_frame_count',
  'preset_apply_ms',
  'shader_compile_ms',
  'texture_upload_ms',
  'capture_accept_ms',
  'capture_process_ms',
  'capture_save_ms',
  'gallery_thumbnail_decode_ms',
  'gallery_render_ms',
  'memory_java_mb',
  'memory_native_mb',
  'memory_gpu_estimate_mb',
  'thermal_status',
  'active_render_quality_tier',
};

@immutable
final class CameraTelemetrySample {
  const CameraTelemetrySample({
    required this.name,
    required this.monotonicTimestampUs,
    required this.value,
  });

  final String name;
  final int monotonicTimestampUs;
  final double value;
}

@immutable
final class CameraDiagnosticSnapshot {
  const CameraDiagnosticSnapshot({
    required this.samples,
    required this.latestValues,
  });

  final List<CameraTelemetrySample> samples;
  final Map<String, double> latestValues;

  Map<String, Object> toSafeMap() => <String, Object>{
    'samples': [
      for (final sample in samples)
        <String, Object>{
          'name': sample.name,
          'timestampUs': sample.monotonicTimestampUs,
          'value': sample.value,
        },
    ],
    'latestValues': latestValues,
  };
}

/// Debug/beta-only local telemetry with deterministic bounded eviction.
final class CameraTelemetry {
  CameraTelemetry({this.capacity = 256, Stopwatch? clock})
    : assert(capacity > 0, 'Telemetry capacity must be positive.'),
      _clock = clock ?? (Stopwatch()..start());

  static final CameraTelemetry instance = CameraTelemetry();

  final int capacity;
  final Stopwatch _clock;
  final Queue<CameraTelemetrySample> _samples = Queue();

  List<CameraTelemetrySample> get samples =>
      List<CameraTelemetrySample>.unmodifiable(_samples);

  void record(String name, num value, {int? monotonicTimestampUs}) {
    if (!kDebugMode || !cameraTelemetryMetricNames.contains(name)) return;
    final numericValue = value.toDouble();
    if (!numericValue.isFinite) return;
    if (_samples.length == capacity) _samples.removeFirst();
    _samples.addLast(
      CameraTelemetrySample(
        name: name,
        monotonicTimestampUs:
            monotonicTimestampUs ?? _clock.elapsedMicroseconds,
        value: numericValue,
      ),
    );
  }

  CameraDiagnosticSnapshot snapshot() {
    final latest = <String, double>{};
    for (final sample in _samples) {
      latest[sample.name] = sample.value;
    }
    return CameraDiagnosticSnapshot(
      samples: samples,
      latestValues: Map<String, double>.unmodifiable(latest),
    );
  }

  void clear() => _samples.clear();
}
