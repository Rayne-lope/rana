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
    val undertoneY: Float = 0f
)
