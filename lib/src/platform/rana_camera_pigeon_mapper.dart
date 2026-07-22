import 'package:flutter/foundation.dart';
import 'package:rana/features/preset/model/capture_style_metadata.dart';
import 'package:rana/features/render/model/render_recipe.dart';
import 'package:rana/src/platform/rana_camera_api.g.dart' as pigeon;

@internal
pigeon.RenderRecipeMessage recipeToPigeon(RenderRecipeV1 recipe) =>
    pigeon.RenderRecipeMessage(
      recipeVersion: currentRenderRecipeVersion,
      temperature: recipe.temperature,
      saturation: recipe.saturation,
      contrast: recipe.contrast,
      colorMatrix: recipe.colorMatrix,
      fade: recipe.fade,
      grain: recipe.grain,
      grainSize: recipe.grainSize,
      grainShadowsLimit: recipe.grainShadowsLimit,
      grainHighlightsLimit: recipe.grainHighlightsLimit,
      vignette: recipe.vignette,
      vignetteColor: recipe.vignetteColor,
      vignetteRoundness: recipe.vignetteRoundness,
      lutPath: recipe.lutPath,
      lutStrength: recipe.lutStrength,
      lightLeakIntensity: recipe.lightLeakIntensity,
      lightLeakVariant: recipe.lightLeakVariant,
      dustIntensity: recipe.dustIntensity,
      dustOffsetX: recipe.dustOffsetX,
      dustOffsetY: recipe.dustOffsetY,
      bloomThreshold: recipe.bloomThreshold,
      bloomIntensity: recipe.bloomIntensity,
      halationIntensity: recipe.halationIntensity,
      halationRadius: recipe.halationRadius,
      halationColor: recipe.halationColor,
      lensDistortionStrength: recipe.lensDistortionStrength,
      chromaticAberrationIntensity: recipe.chromaticAberrationIntensity,
      highlightRollOff: recipe.highlightRollOff,
      shadowRollOff: recipe.shadowRollOff,
      filmBorderStyle: recipe.filmBorderStyle,
      dateStampEnable: recipe.dateStampEnable,
      shadowsTint: recipe.shadowsTint,
      highlightsTint: recipe.highlightsTint,
      tone: recipe.tone,
      color: recipe.color,
      texture: recipe.texture,
      styleStrength: recipe.styleStrength,
      undertoneX: recipe.undertoneX,
      undertoneY: recipe.undertoneY,
      softness: recipe.softness,
      outputQuality: recipe.outputQuality,
      aspectRatio: recipe.aspectRatio,
      presetId: recipe.presetId,
      isStyleModified: recipe.isStyleModified,
    );

@internal
RenderRecipeV1 recipeFromPigeon(pigeon.RenderRecipeMessage recipe) =>
    RenderRecipeV1.fromMap(<String, dynamic>{
      'recipeVersion': recipe.recipeVersion,
      'temperature': recipe.temperature,
      'saturation': recipe.saturation,
      'contrast': recipe.contrast,
      'colorMatrix': recipe.colorMatrix,
      'fade': recipe.fade,
      'grain': recipe.grain,
      'grainSize': recipe.grainSize,
      'grainShadowsLimit': recipe.grainShadowsLimit,
      'grainHighlightsLimit': recipe.grainHighlightsLimit,
      'vignette': recipe.vignette,
      'vignetteColor': recipe.vignetteColor,
      'vignetteRoundness': recipe.vignetteRoundness,
      'lutPath': recipe.lutPath,
      'lutStrength': recipe.lutStrength,
      'lightLeakIntensity': recipe.lightLeakIntensity,
      'lightLeakVariant': recipe.lightLeakVariant,
      'dustIntensity': recipe.dustIntensity,
      'dustOffsetX': recipe.dustOffsetX,
      'dustOffsetY': recipe.dustOffsetY,
      'bloomThreshold': recipe.bloomThreshold,
      'bloomIntensity': recipe.bloomIntensity,
      'halationIntensity': recipe.halationIntensity,
      'halationRadius': recipe.halationRadius,
      'halationColor': recipe.halationColor,
      'lensDistortionStrength': recipe.lensDistortionStrength,
      'chromaticAberrationIntensity': recipe.chromaticAberrationIntensity,
      'highlightRollOff': recipe.highlightRollOff,
      'shadowRollOff': recipe.shadowRollOff,
      'filmBorderStyle': recipe.filmBorderStyle,
      'dateStampEnable': recipe.dateStampEnable,
      'shadowsTint': recipe.shadowsTint,
      'highlightsTint': recipe.highlightsTint,
      'tone': recipe.tone,
      'color': recipe.color,
      'textureVal': recipe.texture,
      'styleStrength': recipe.styleStrength,
      'undertoneX': recipe.undertoneX,
      'undertoneY': recipe.undertoneY,
      'softness': recipe.softness,
      'outputQuality': recipe.outputQuality,
      'aspectRatio': recipe.aspectRatio,
      'presetId': recipe.presetId,
      'isStyleModified': recipe.isStyleModified,
    });

@internal
Map<String, dynamic> operationResultToMap(
  pigeon.CameraOperationResult result,
) => <String, dynamic>{
  'status': result.status,
  if (result.lens != null) 'lens': result.lens,
  if (result.aspectRatio != null) 'aspectRatio': result.aspectRatio,
  if (result.label != null) 'label': result.label,
  if (result.zoomRatio != null) 'zoomRatio': result.zoomRatio,
  if (result.minZoomRatio != null) 'minZoomRatio': result.minZoomRatio,
  if (result.maxZoomRatio != null) 'maxZoomRatio': result.maxZoomRatio,
  if (result.isLikelyDigitalZoom != null)
    'isLikelyDigitalZoom': result.isLikelyDigitalZoom,
  if (result.shouldWarnDigitalZoom != null)
    'shouldWarnDigitalZoom': result.shouldWarnDigitalZoom,
  if (result.hasTelephotoCandidate != null)
    'hasTelephotoCandidate': result.hasTelephotoCandidate,
  if (result.zoomQualityLabel != null)
    'zoomQualityLabel': result.zoomQualityLabel,
};

@internal
Map<String, dynamic> captureResultToMap(pigeon.CaptureResultMessage result) =>
    <String, dynamic>{
      'status': result.status,
      'filePath': result.filePath,
      'qualityReduced': result.qualityReduced,
      'inSampleSize': result.inSampleSize,
      'lutSkipped': result.lutSkipped,
      'requestedOutputQuality': result.requestedOutputQuality,
      'actualOutputFormat': result.actualOutputFormat,
      'outputMimeType': result.outputMimeType,
      'outputWidth': result.outputWidth,
      'outputHeight': result.outputHeight,
      'fileSizeBytes': result.fileSizeBytes,
      'fallbackReason': result.fallbackReason,
    };

@internal
CaptureStyleMetadata metadataFromPigeon(
  pigeon.CaptureStyleMetadataMessage metadata,
) {
  final recipe = recipeFromPigeon(metadata.recipe);
  return CaptureStyleMetadata(
    mediaUri: metadata.mediaUri,
    sourceImagePath: metadata.sourceImagePath,
    mediaIsRendered: metadata.mediaIsRendered,
    presetId: recipe.presetId,
    undertoneX: recipe.undertoneX,
    undertoneY: recipe.undertoneY,
    params: recipe.toMap(),
    createdAtEpochMs: metadata.createdAtEpochMs,
    updatedAtEpochMs: metadata.updatedAtEpochMs,
    filmRollId: metadata.filmRollId,
  );
}
