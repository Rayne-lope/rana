import 'package:flutter/foundation.dart';
import 'package:rana/features/render/model/render_recipe.dart';

@immutable
class CaptureStyleMetadata {
  const CaptureStyleMetadata({
    required this.mediaUri,
    required this.presetId,
    required this.undertoneX,
    required this.undertoneY,
    required this.params,
    this.recipeVersion = currentRenderRecipeVersion,
    this.sourceImagePath,
    this.mediaIsRendered = false,
    this.createdAtEpochMs = 0,
    this.updatedAtEpochMs = 0,
    this.filmRollId,
  });

  factory CaptureStyleMetadata.fromMap(Map<dynamic, dynamic> map) =>
      CaptureStyleMetadata(
        mediaUri: map['mediaUri'] as String? ?? '',
        presetId: map['presetId'] as String? ?? 'normal',
        undertoneX: (map['undertoneX'] as num?)?.toDouble() ?? 0.0,
        undertoneY: (map['undertoneY'] as num?)?.toDouble() ?? 0.0,
        params: map['params'] != null
            ? Map<String, dynamic>.from(map['params'] as Map<dynamic, dynamic>)
            : const <String, dynamic>{},
        recipeVersion:
            (map['recipeVersion'] as num?)?.toInt() ??
            currentRenderRecipeVersion,
        sourceImagePath: map['sourceImagePath'] as String?,
        mediaIsRendered: map['mediaIsRendered'] as bool? ?? false,
        createdAtEpochMs: (map['createdAtEpochMs'] as num?)?.toInt() ?? 0,
        updatedAtEpochMs: (map['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
        filmRollId: map['filmRollId'] as String?,
      );

  final String mediaUri;
  final String presetId;
  final double undertoneX;
  final double undertoneY;
  final Map<String, dynamic> params;
  final int recipeVersion;
  final String? sourceImagePath;
  final bool mediaIsRendered;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final String? filmRollId;

  /// Typed recipe reconstructed from current or legacy-v0 metadata.
  RenderRecipeV1 get recipe => RenderRecipeV1.fromMap(<String, dynamic>{
    ...params,
    'recipeVersion': recipeVersion,
    'presetId': params['presetId'] ?? presetId,
    'undertoneX': params['undertoneX'] ?? undertoneX,
    'undertoneY': params['undertoneY'] ?? undertoneY,
  });

  /// Generates a unique key for LRU caching.
  String get cacheKey {
    final paramsHash = recipe.hashCode;
    return '$mediaUri|$presetId|$undertoneX|$undertoneY|'
        '$updatedAtEpochMs|$paramsHash';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureStyleMetadata &&
          runtimeType == other.runtimeType &&
          mediaUri == other.mediaUri &&
          presetId == other.presetId &&
          recipeVersion == other.recipeVersion &&
          undertoneX == other.undertoneX &&
          undertoneY == other.undertoneY &&
          createdAtEpochMs == other.createdAtEpochMs &&
          updatedAtEpochMs == other.updatedAtEpochMs;

  @override
  int get hashCode => Object.hash(
    mediaUri,
    presetId,
    recipeVersion,
    undertoneX,
    undertoneY,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
}
