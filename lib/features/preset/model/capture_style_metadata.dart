import 'package:flutter/foundation.dart';

@immutable
class CaptureStyleMetadata {
  const CaptureStyleMetadata({
    required this.mediaUri,
    required this.presetId,
    required this.undertoneX,
    required this.undertoneY,
    required this.params,
    this.sourceImagePath,
    this.mediaIsRendered = false,
    this.createdAtEpochMs = 0,
    this.updatedAtEpochMs = 0,
    this.filmRollId,
  });

  factory CaptureStyleMetadata.fromMap(Map<dynamic, dynamic> map) {
    return CaptureStyleMetadata(
      mediaUri: map['mediaUri'] as String? ?? '',
      presetId: map['presetId'] as String? ?? 'normal',
      undertoneX: (map['undertoneX'] as num?)?.toDouble() ?? 0.0,
      undertoneY: (map['undertoneY'] as num?)?.toDouble() ?? 0.0,
      params: map['params'] != null
          ? Map<String, dynamic>.from(map['params'] as Map<dynamic, dynamic>)
          : const <String, dynamic>{},
      sourceImagePath: map['sourceImagePath'] as String?,
      mediaIsRendered: map['mediaIsRendered'] as bool? ?? false,
      createdAtEpochMs: (map['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      updatedAtEpochMs: (map['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      filmRollId: map['filmRollId'] as String?,
    );
  }

  final String mediaUri;
  final String presetId;
  final double undertoneX;
  final double undertoneY;
  final Map<String, dynamic> params;
  final String? sourceImagePath;
  final bool mediaIsRendered;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final String? filmRollId;

  /// Generates a unique key for LRU caching.
  String get cacheKey {
    final paramsHash = params.entries
        .map((e) => '${e.key}:${e.value}')
        .join(';');
    return '$mediaUri|$presetId|$undertoneX|$undertoneY|$updatedAtEpochMs|$paramsHash';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureStyleMetadata &&
          runtimeType == other.runtimeType &&
          mediaUri == other.mediaUri &&
          presetId == other.presetId &&
          undertoneX == other.undertoneX &&
          undertoneY == other.undertoneY &&
          createdAtEpochMs == other.createdAtEpochMs &&
          updatedAtEpochMs == other.updatedAtEpochMs;

  @override
  int get hashCode => Object.hash(
        mediaUri,
        presetId,
        undertoneX,
        undertoneY,
        createdAtEpochMs,
        updatedAtEpochMs,
      );
}
