import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlParamsState {
  const GlParamsState({
    this.lastPreviewParams,
    this.lastExportParams,
    this.lastCapturedPreviewParams,
  });

  final Map<String, dynamic>? lastPreviewParams;
  final Map<String, dynamic>? lastExportParams;
  final Map<String, dynamic>? lastCapturedPreviewParams;

  GlParamsState copyWith({
    Map<String, dynamic>? lastPreviewParams,
    Map<String, dynamic>? lastExportParams,
    Map<String, dynamic>? lastCapturedPreviewParams,
  }) =>
      GlParamsState(
        lastPreviewParams: lastPreviewParams ?? this.lastPreviewParams,
        lastExportParams: lastExportParams ?? this.lastExportParams,
        lastCapturedPreviewParams:
            lastCapturedPreviewParams ?? this.lastCapturedPreviewParams,
      );
}

final consistencyDebugProvider = StateProvider<GlParamsState>(
  (ref) => const GlParamsState(),
);
