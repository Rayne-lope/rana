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
    val lutAssetPath: String? = null,
    val lutStrength: Float = 0f,
    val lightLeakIntensity: Float = 0f,
    val lightLeakVariant: Int = -1,
    val dustIntensity: Float = 0f,
    val bloomThreshold: Float = 0.8f,
    val bloomIntensity: Float = 0f,
    val halationIntensity: Float = 0f,
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
        lutAssetPath = args?.get("lutPath") as? String,
        lutStrength = numberArg("lutStrength"),
        lightLeakIntensity = numberArg("lightLeakIntensity"),
        lightLeakVariant = (args?.get("lightLeakVariant") as? Number)?.toInt() ?: -1,
        dustIntensity = numberArg("dustIntensity"),
        bloomThreshold = numberArg("bloomThreshold", 0.8f),
        bloomIntensity = numberArg("bloomIntensity"),
        halationIntensity = numberArg("halationIntensity"),
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
