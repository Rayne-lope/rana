package com.rana.app.rana

internal val IDENTITY_COLOR_MATRIX = floatArrayOf(
    1f, 0f, 0f,
    0f, 1f, 0f,
    0f, 0f, 1f
)

internal const val DEFAULT_GRAIN_SHADOWS_LIMIT = 0.04f
internal const val DEFAULT_GRAIN_HIGHLIGHTS_LIMIT = 0.07f

/**
 * Parameters for offline image processing.
 */
data class OfflineProcessParams(
    val temperature: Float = 0f,
    val saturation: Float = 0f,
    val contrast: Float = 0f,
    val colorMatrix: FloatArray = IDENTITY_COLOR_MATRIX.copyOf(),
    val grain: Float = 0f,
    val vignette: Float = 0f,
    val vignetteColorR: Float = 0f,
    val vignetteColorG: Float = 0f,
    val vignetteColorB: Float = 0f,
    val vignetteRoundness: Float = 0f,
    val lutAssetPath: String? = null,
    val lutStrength: Float = 0f,
    val lightLeakIntensity: Float = 0f,
    val lightLeakVariant: Int = -1,
    val dustIntensity: Float = 0f,
    val dustOffsetX: Float = -1f,
    val dustOffsetY: Float = -1f,
    val bloomThreshold: Float = 0.8f,
    val bloomIntensity: Float = 0f,
    val halationIntensity: Float = 0f,
    val halationRadius: Float = 1f,
    val halationColorR: Float = 1f,
    val halationColorG: Float = 0.35f,
    val halationColorB: Float = 0.15f,
    val lensDistortionStrength: Float = 0f,
    val tone: Float = 0f,
    val color: Float = 0f,
    val textureVal: Float = 0f,
    val styleStrength: Float = 100f,
    val undertoneX: Float = 0f,
    val undertoneY: Float = 0f,
    val grainSize: Float = 1f,
    val grainShadowsLimit: Float = DEFAULT_GRAIN_SHADOWS_LIMIT,
    val grainHighlightsLimit: Float = DEFAULT_GRAIN_HIGHLIGHTS_LIMIT,
    val softness: Float = 0f,
    val chromaticAberrationIntensity: Float = 0f,
    val fade: Float = 0f,
    val highlightRollOff: Float = 0f,
    val shadowRollOff: Float = 0f,
    val filmBorderStyle: Int = 0,
    val dateStampEnable: Boolean = false,
    val shadowsTintR: Float = 0f,
    val shadowsTintG: Float = 0f,
    val shadowsTintB: Float = 0f,
    val highlightsTintR: Float = 0f,
    val highlightsTintG: Float = 0f,
    val highlightsTintB: Float = 0f,
    val outputQuality: OutputQualityProfile = OutputQualityProfile.HIGH_JPEG,
    val aspectRatio: String = "portrait_3_4",
    val presetId: String = "normal",
    val isStyleModified: Boolean = false,
    /** Film roll UUID, or null when shooting without a roll. */
    val filmRollId: String? = null
)

/** Converts the stable recipe into renderer uniforms and capture settings. */
internal fun RenderRecipeV1.toOfflineProcessParams(
    filmRollId: String? = null
): OfflineProcessParams = OfflineProcessParams(
    temperature = temperature,
    saturation = saturation,
    contrast = contrast,
    colorMatrix = colorMatrix.toFloatArray(),
    grain = grain,
    vignette = vignette,
    vignetteColorR = vignetteColor[0],
    vignetteColorG = vignetteColor[1],
    vignetteColorB = vignetteColor[2],
    vignetteRoundness = vignetteRoundness,
    lutAssetPath = lutPath,
    lutStrength = lutStrength,
    lightLeakIntensity = lightLeakIntensity,
    lightLeakVariant = lightLeakVariant,
    dustIntensity = dustIntensity,
    dustOffsetX = dustOffsetX,
    dustOffsetY = dustOffsetY,
    bloomThreshold = bloomThreshold,
    bloomIntensity = bloomIntensity,
    halationIntensity = halationIntensity,
    halationRadius = halationRadius,
    halationColorR = halationColor[0],
    halationColorG = halationColor[1],
    halationColorB = halationColor[2],
    lensDistortionStrength = lensDistortionStrength,
    tone = tone,
    color = color,
    textureVal = texture,
    styleStrength = styleStrength,
    undertoneX = undertoneX,
    undertoneY = undertoneY,
    grainSize = grainSize,
    grainShadowsLimit = grainShadowsLimit,
    grainHighlightsLimit = grainHighlightsLimit,
    softness = softness,
    chromaticAberrationIntensity = chromaticAberrationIntensity,
    fade = fade,
    highlightRollOff = highlightRollOff,
    shadowRollOff = shadowRollOff,
    filmBorderStyle = filmBorderStyle,
    dateStampEnable = dateStampEnable,
    shadowsTintR = shadowsTint[0],
    shadowsTintG = shadowsTint[1],
    shadowsTintB = shadowsTint[2],
    highlightsTintR = highlightsTint[0],
    highlightsTintG = highlightsTint[1],
    highlightsTintB = highlightsTint[2],
    outputQuality = OutputQualityProfile.fromChannelValue(outputQuality),
    aspectRatio = aspectRatio,
    presetId = presetId,
    isStyleModified = isStyleModified,
    filmRollId = filmRollId
)

/** Stable typed payload persisted for later non-destructive rendering. */
internal fun OfflineProcessParams.asRenderRecipe(): RenderRecipeV1 =
    RenderRecipeV1.fromMap(
        mapOf(
            "temperature" to temperature,
            "saturation" to saturation,
            "contrast" to contrast,
            "colorMatrix" to colorMatrix.toList(),
            "grain" to grain,
            "vignette" to vignette,
            "vignetteColorR" to vignetteColorR,
            "vignetteColorG" to vignetteColorG,
            "vignetteColorB" to vignetteColorB,
            "vignetteRoundness" to vignetteRoundness,
            "lutPath" to lutAssetPath,
            "lutStrength" to lutStrength,
            "lightLeakIntensity" to lightLeakIntensity,
            "lightLeakVariant" to lightLeakVariant,
            "dustIntensity" to dustIntensity,
            "dustOffsetX" to dustOffsetX,
            "dustOffsetY" to dustOffsetY,
            "bloomThreshold" to bloomThreshold,
            "bloomIntensity" to bloomIntensity,
            "halationIntensity" to halationIntensity,
            "halationRadius" to halationRadius,
            "halationColorR" to halationColorR,
            "halationColorG" to halationColorG,
            "halationColorB" to halationColorB,
            "lensDistortionStrength" to lensDistortionStrength,
            "tone" to tone,
            "color" to color,
            "textureVal" to textureVal,
            "styleStrength" to styleStrength,
            "undertoneX" to undertoneX,
            "undertoneY" to undertoneY,
            "grainSize" to grainSize,
            "grainShadowsLimit" to grainShadowsLimit,
            "grainHighlightsLimit" to grainHighlightsLimit,
            "softness" to softness,
            "chromaticAberrationIntensity" to chromaticAberrationIntensity,
            "fade" to fade,
            "highlightRollOff" to highlightRollOff,
            "shadowRollOff" to shadowRollOff,
            "filmBorderStyle" to filmBorderStyle,
            "dateStampEnable" to dateStampEnable,
            "shadowsTintR" to shadowsTintR,
            "shadowsTintG" to shadowsTintG,
            "shadowsTintB" to shadowsTintB,
            "highlightsTintR" to highlightsTintR,
            "highlightsTintG" to highlightsTintG,
            "highlightsTintB" to highlightsTintB,
            "outputQuality" to outputQuality.channelValue,
            "aspectRatio" to aspectRatio,
            "presetId" to presetId,
            "isStyleModified" to isStyleModified
        )
    )

internal fun OfflineProcessParams.asMetadataParams(): Map<String, Any?> =
    asRenderRecipe().toMap()

/** Temporary compatibility parser for legacy MethodChannel payloads. */
internal fun offlineProcessParamsFromArguments(arguments: Any?): OfflineProcessParams {
    val args = arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    return RenderRecipeV1.fromMap(args).toOfflineProcessParams(
        filmRollId = args["filmRollId"] as? String
    )
}

/** Converts a human-readable row-major RGB matrix for OpenGL ES upload. */
internal fun colorMatrixForGl(rowMajor: FloatArray): FloatArray {
    val matrix = if (rowMajor.size == 9) rowMajor else IDENTITY_COLOR_MATRIX
    return floatArrayOf(
        matrix[0], matrix[3], matrix[6],
        matrix[1], matrix[4], matrix[7],
        matrix[2], matrix[5], matrix[8]
    )
}

internal fun normalizedHalationRadius(radius: Float): Float =
    if (radius.isFinite()) radius.coerceIn(0.25f, 4f) else 1f

internal fun normalizedHalationColor(component: Float, fallback: Float): Float =
    if (component.isFinite()) component.coerceIn(0f, 1f) else fallback

internal fun normalizedFilmBorderStyle(style: Int): Int =
    if (style in 0..3) style else 0

internal fun normalizedVignetteColor(component: Float): Float =
    if (component.isFinite()) component.coerceIn(0f, 1f) else 0f

internal fun normalizedVignetteRoundness(roundness: Float): Float =
    if (roundness.isFinite()) roundness.coerceIn(0f, 1f) else 0f

internal fun normalizedGrainShadowsLimit(limit: Float): Float =
    if (limit.isFinite()) {
        limit.coerceIn(0f, 0.5f)
    } else {
        DEFAULT_GRAIN_SHADOWS_LIMIT
    }

internal fun normalizedGrainHighlightsLimit(limit: Float): Float =
    if (limit.isFinite()) {
        limit.coerceIn(0f, 0.3f)
    } else {
        DEFAULT_GRAIN_HIGHLIGHTS_LIMIT
    }

internal fun canShareHalationBlur(
    bloomIntensity: Float,
    halationRadius: Float
): Boolean = bloomIntensity > 0f && normalizedHalationRadius(halationRadius) == 1f
