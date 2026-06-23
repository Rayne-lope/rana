import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlParamsState {
  const GlParamsState({
    this.lastPreviewParams,
    this.lastExportParams,
  });

  final Map<String, dynamic>? lastPreviewParams;
  final Map<String, dynamic>? lastExportParams;

  GlParamsState copyWith({
    Map<String, dynamic>? lastPreviewParams,
    Map<String, dynamic>? lastExportParams,
  }) =>
      GlParamsState(
        lastPreviewParams: lastPreviewParams ?? this.lastPreviewParams,
        lastExportParams: lastExportParams ?? this.lastExportParams,
      );
}

final consistencyDebugProvider = StateProvider<GlParamsState>(
  (ref) => const GlParamsState(),
);
