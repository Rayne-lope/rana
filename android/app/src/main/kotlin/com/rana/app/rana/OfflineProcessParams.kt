package com.rana.app.rana

internal val IDENTITY_COLOR_MATRIX = floatArrayOf(
    1f, 0f, 0f,
    0f, 1f, 0f,
    0f, 0f, 1f
)

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
    val presetId: String = "normal",
    val isStyleModified: Boolean = false
)

/** Stable flat payload persisted for later non-destructive rendering. */
internal fun OfflineProcessParams.asMetadataParams(): Map<String, Any?> = mapOf(
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
    "presetId" to presetId,
    "isStyleModified" to isStyleModified
)

/** Parses MethodChannel arguments while preserving neutral legacy defaults. */
internal fun offlineProcessParamsFromArguments(
    arguments: Any?
): OfflineProcessParams {
    val args = arguments as? Map<*, *>
    fun numberArg(key: String, default: Float = 0f): Float {
        return (args?.get(key) as? Number)?.toFloat() ?: default
    }
    fun colorMatrixArg(): FloatArray {
        val values = args?.get("colorMatrix") as? List<*>
            ?: return IDENTITY_COLOR_MATRIX.copyOf()
        if (values.size != 9 || values.any { it !is Number }) {
            return IDENTITY_COLOR_MATRIX.copyOf()
        }
        val parsed = FloatArray(9) { index ->
            (values[index] as Number).toFloat()
        }
        return if (parsed.all(Float::isFinite)) {
            parsed
        } else {
            IDENTITY_COLOR_MATRIX.copyOf()
        }
    }

    return OfflineProcessParams(
        temperature = numberArg("temperature"),
        saturation = numberArg("saturation"),
        contrast = numberArg("contrast"),
        colorMatrix = colorMatrixArg(),
        grain = numberArg("grain"),
        vignette = numberArg("vignette"),
        vignetteColorR = normalizedVignetteColor(
            numberArg("vignetteColorR")
        ),
        vignetteColorG = normalizedVignetteColor(
            numberArg("vignetteColorG")
        ),
        vignetteColorB = normalizedVignetteColor(
            numberArg("vignetteColorB")
        ),
        vignetteRoundness = normalizedVignetteRoundness(
            numberArg("vignetteRoundness")
        ),
        lutAssetPath = args?.get("lutPath") as? String,
        lutStrength = numberArg("lutStrength"),
        lightLeakIntensity = numberArg("lightLeakIntensity"),
        lightLeakVariant = (args?.get("lightLeakVariant") as? Number)?.toInt() ?: -1,
        dustIntensity = numberArg("dustIntensity"),
        dustOffsetX = numberArg("dustOffsetX", -1f),
        dustOffsetY = numberArg("dustOffsetY", -1f),
        bloomThreshold = numberArg("bloomThreshold", 0.8f),
        bloomIntensity = numberArg("bloomIntensity"),
        halationIntensity = numberArg("halationIntensity"),
        halationRadius = numberArg("halationRadius", 1f),
        halationColorR = normalizedHalationColor(
            numberArg("halationColorR", 1f),
            1f
        ),
        halationColorG = normalizedHalationColor(
            numberArg("halationColorG", 0.35f),
            0.35f
        ),
        halationColorB = normalizedHalationColor(
            numberArg("halationColorB", 0.15f),
            0.15f
        ),
        lensDistortionStrength = numberArg("lensDistortionStrength"),
        tone = numberArg("tone"),
        color = numberArg("color"),
        textureVal = numberArg("textureVal"),
        styleStrength = numberArg("styleStrength", 100f),
        undertoneX = numberArg("undertoneX"),
        undertoneY = numberArg("undertoneY"),
        grainSize = numberArg("grainSize", 1f),
        softness = numberArg("softness"),
        chromaticAberrationIntensity = numberArg("chromaticAberrationIntensity"),
        fade = numberArg("fade"),
        highlightRollOff = numberArg("highlightRollOff"),
        shadowRollOff = numberArg("shadowRollOff"),
        filmBorderStyle = normalizedFilmBorderStyle(
            (args?.get("filmBorderStyle") as? Number)?.toInt() ?: 0
        ),
        dateStampEnable = args?.get("dateStampEnable") as? Boolean ?: false,
        shadowsTintR = numberArg("shadowsTintR"),
        shadowsTintG = numberArg("shadowsTintG"),
        shadowsTintB = numberArg("shadowsTintB"),
        highlightsTintR = numberArg("highlightsTintR"),
        highlightsTintG = numberArg("highlightsTintG"),
        highlightsTintB = numberArg("highlightsTintB"),
        outputQuality = OutputQualityProfile.fromChannelValue(
            args?.get("outputQuality") as? String
        ),
        presetId = args?.get("presetId") as? String ?: "normal",
        isStyleModified = args?.get("isStyleModified") as? Boolean ?: false
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
    if (style in 0..2) style else 0

internal fun normalizedVignetteColor(component: Float): Float =
    if (component.isFinite()) component.coerceIn(0f, 1f) else 0f

internal fun normalizedVignetteRoundness(roundness: Float): Float =
    if (roundness.isFinite()) roundness.coerceIn(0f, 1f) else 0f

internal fun canShareHalationBlur(
    bloomIntensity: Float,
    halationRadius: Float
): Boolean = bloomIntensity > 0f && normalizedHalationRadius(halationRadius) == 1f
