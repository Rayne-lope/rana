package com.rana.app.rana

/**
 * Parameters for offline image processing.
 */
data class OfflineProcessParams(
    val temperature: Float = 0f,
    val saturation: Float = 0f,
    val contrast: Float = 0f,
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
    val dateStampEnable: Boolean = false,
    val shadowsTintR: Float = 0f,
    val shadowsTintG: Float = 0f,
    val shadowsTintB: Float = 0f,
    val highlightsTintR: Float = 0f,
    val highlightsTintG: Float = 0f,
    val highlightsTintB: Float = 0f
)

/** Parses MethodChannel arguments while preserving neutral legacy defaults. */
internal fun offlineProcessParamsFromArguments(
    arguments: Any?
): OfflineProcessParams {
    val args = arguments as? Map<*, *>
    fun numberArg(key: String, default: Float = 0f): Float {
        return (args?.get(key) as? Number)?.toFloat() ?: default
    }

    return OfflineProcessParams(
        temperature = numberArg("temperature"),
        saturation = numberArg("saturation"),
        contrast = numberArg("contrast"),
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
        dateStampEnable = args?.get("dateStampEnable") as? Boolean ?: false,
        shadowsTintR = numberArg("shadowsTintR"),
        shadowsTintG = numberArg("shadowsTintG"),
        shadowsTintB = numberArg("shadowsTintB"),
        highlightsTintR = numberArg("highlightsTintR"),
        highlightsTintG = numberArg("highlightsTintG"),
        highlightsTintB = numberArg("highlightsTintB")
    )
}
