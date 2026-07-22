package com.rana.app.rana

internal const val RENDER_RECIPE_VERSION = 1

internal class UnsupportedRenderRecipeVersionException(
    val recipeVersion: Int
) : IllegalArgumentException(
    "UNSUPPORTED_RECIPE_VERSION: Render recipe version $recipeVersion is not supported."
)

/** Stable immutable recipe used on both live and offline render paths. */
internal data class RenderRecipeV1(
    val temperature: Float = 0f,
    val saturation: Float = 0f,
    val contrast: Float = 0f,
    val colorMatrix: List<Float> = IDENTITY_COLOR_MATRIX.toList(),
    val fade: Float = 0f,
    val grain: Float = 0f,
    val grainSize: Float = 1f,
    val grainShadowsLimit: Float = DEFAULT_GRAIN_SHADOWS_LIMIT,
    val grainHighlightsLimit: Float = DEFAULT_GRAIN_HIGHLIGHTS_LIMIT,
    val vignette: Float = 0f,
    val vignetteColor: List<Float> = listOf(0f, 0f, 0f),
    val vignetteRoundness: Float = 0f,
    val lutPath: String? = null,
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
    val halationColor: List<Float> = listOf(1f, 0.35f, 0.15f),
    val lensDistortionStrength: Float = 0f,
    val chromaticAberrationIntensity: Float = 0f,
    val highlightRollOff: Float = 0f,
    val shadowRollOff: Float = 0f,
    val filmBorderStyle: Int = 0,
    val dateStampEnable: Boolean = false,
    val shadowsTint: List<Float> = listOf(0f, 0f, 0f),
    val highlightsTint: List<Float> = listOf(0f, 0f, 0f),
    val tone: Float = 0f,
    val color: Float = 0f,
    val texture: Float = 0f,
    val styleStrength: Float = 100f,
    val undertoneX: Float = 0f,
    val undertoneY: Float = 0f,
    val softness: Float = 0f,
    val outputQuality: String = "high_jpeg",
    val aspectRatio: String = "portrait_3_4",
    val presetId: String = "normal",
    val isStyleModified: Boolean = false
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "recipeVersion" to RENDER_RECIPE_VERSION,
        "temperature" to temperature,
        "saturation" to saturation,
        "contrast" to contrast,
        "colorMatrix" to colorMatrix,
        "fade" to fade,
        "grain" to grain,
        "grainSize" to grainSize,
        "grainShadowsLimit" to grainShadowsLimit,
        "grainHighlightsLimit" to grainHighlightsLimit,
        "vignette" to vignette,
        "vignetteColorR" to vignetteColor[0],
        "vignetteColorG" to vignetteColor[1],
        "vignetteColorB" to vignetteColor[2],
        "vignetteRoundness" to vignetteRoundness,
        "lutPath" to lutPath,
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
        "halationColorR" to halationColor[0],
        "halationColorG" to halationColor[1],
        "halationColorB" to halationColor[2],
        "lensDistortionStrength" to lensDistortionStrength,
        "chromaticAberrationIntensity" to chromaticAberrationIntensity,
        "highlightRollOff" to highlightRollOff,
        "shadowRollOff" to shadowRollOff,
        "filmBorderStyle" to filmBorderStyle,
        "dateStampEnable" to dateStampEnable,
        "shadowsTintR" to shadowsTint[0],
        "shadowsTintG" to shadowsTint[1],
        "shadowsTintB" to shadowsTint[2],
        "highlightsTintR" to highlightsTint[0],
        "highlightsTintG" to highlightsTint[1],
        "highlightsTintB" to highlightsTint[2],
        "tone" to tone,
        "color" to color,
        "textureVal" to texture,
        "styleStrength" to styleStrength,
        "undertoneX" to undertoneX,
        "undertoneY" to undertoneY,
        "softness" to softness,
        "outputQuality" to outputQuality,
        "aspectRatio" to aspectRatio,
        "presetId" to presetId,
        "isStyleModified" to isStyleModified
    )

    companion object {
        fun fromMap(source: Map<*, *>): RenderRecipeV1 {
            val version = (source["recipeVersion"] as? Number)?.toInt() ?: 0
            if (version != 0 && version != RENDER_RECIPE_VERSION) {
                throw UnsupportedRenderRecipeVersionException(version)
            }

            fun number(key: String, fallback: Float): Float =
                (source[key] as? Number)?.toFloat()?.takeIf(Float::isFinite) ?: fallback
            fun unit(key: String, fallback: Float): Float =
                number(key, fallback).coerceIn(0f, 1f)
            fun vector(key: String, size: Int, fallback: List<Float>): List<Float> {
                val values = source[key] as? List<*> ?: return fallback
                if (values.size != size) return fallback
                return values.map { item ->
                    (item as? Number)?.toFloat()?.takeIf(Float::isFinite)
                        ?: return fallback
                }
            }
            fun rgb(aggregate: String, prefix: String, fallback: List<Float>): List<Float> {
                if (source[aggregate] is List<*>) return vector(aggregate, 3, fallback)
                return listOf(
                    number("${prefix}R", fallback[0]),
                    number("${prefix}G", fallback[1]),
                    number("${prefix}B", fallback[2])
                )
            }

            return RenderRecipeV1(
                temperature = number("temperature", 0f).coerceIn(-1f, 1f),
                saturation = number("saturation", 0f).coerceIn(-1f, 1f),
                contrast = number("contrast", 0f).coerceIn(-1f, 1f),
                colorMatrix = vector("colorMatrix", 9, IDENTITY_COLOR_MATRIX.toList()),
                fade = unit("fade", 0f),
                grain = unit("grain", 0f),
                grainSize = number("grainSize", 1f).coerceIn(0.1f, 8f),
                grainShadowsLimit = number(
                    "grainShadowsLimit",
                    DEFAULT_GRAIN_SHADOWS_LIMIT
                ).coerceIn(0f, 0.5f),
                grainHighlightsLimit = number(
                    "grainHighlightsLimit",
                    DEFAULT_GRAIN_HIGHLIGHTS_LIMIT
                ).coerceIn(0f, 0.3f),
                vignette = unit("vignette", 0f),
                vignetteColor = rgb(
                    "vignetteColor",
                    "vignetteColor",
                    listOf(0f, 0f, 0f)
                ).map { it.coerceIn(0f, 1f) },
                vignetteRoundness = unit("vignetteRoundness", 0f),
                lutPath = (source["lutPath"] as? String)?.takeIf(String::isNotEmpty),
                lutStrength = unit("lutStrength", 0f),
                lightLeakIntensity = unit("lightLeakIntensity", 0f),
                lightLeakVariant = (source["lightLeakVariant"] as? Number)?.toInt() ?: -1,
                dustIntensity = unit("dustIntensity", 0f),
                dustOffsetX = number("dustOffsetX", -1f),
                dustOffsetY = number("dustOffsetY", -1f),
                bloomThreshold = unit("bloomThreshold", 0.8f),
                bloomIntensity = unit("bloomIntensity", 0f),
                halationIntensity = unit("halationIntensity", 0f),
                halationRadius = number("halationRadius", 1f).coerceIn(0.25f, 4f),
                halationColor = rgb(
                    "halationColor",
                    "halationColor",
                    listOf(1f, 0.35f, 0.15f)
                ).map { it.coerceIn(0f, 1f) },
                lensDistortionStrength = unit("lensDistortionStrength", 0f),
                chromaticAberrationIntensity = unit("chromaticAberrationIntensity", 0f),
                highlightRollOff = unit("highlightRollOff", 0f),
                shadowRollOff = unit("shadowRollOff", 0f),
                filmBorderStyle = normalizedFilmBorderStyle(
                    (source["filmBorderStyle"] as? Number)?.toInt() ?: 0
                ),
                dateStampEnable = source["dateStampEnable"] as? Boolean ?: false,
                shadowsTint = rgb("shadowsTint", "shadowsTint", listOf(0f, 0f, 0f)),
                highlightsTint = rgb(
                    "highlightsTint",
                    "highlightsTint",
                    listOf(0f, 0f, 0f)
                ),
                tone = number("tone", 0f).coerceIn(-100f, 100f),
                color = number("color", 0f).coerceIn(-100f, 100f),
                texture = number("textureVal", 0f).coerceIn(0f, 100f),
                styleStrength = number("styleStrength", 100f).coerceIn(0f, 100f),
                undertoneX = number("undertoneX", 0f).coerceIn(-1f, 1f),
                undertoneY = number("undertoneY", 0f).coerceIn(-1f, 1f),
                softness = unit("softness", 0f),
                outputQuality = source["outputQuality"] as? String ?: "high_jpeg",
                aspectRatio = source["aspectRatio"] as? String ?: "portrait_3_4",
                presetId = source["presetId"] as? String ?: "normal",
                isStyleModified = source["isStyleModified"] as? Boolean ?: false
            )
        }
    }
}

/** Capture/storage identity, intentionally excluded from the visual recipe. */
internal data class CaptureContext(
    val captureId: String,
    val filmRollId: String? = null,
    val actualOutputUri: String? = null,
    val actualOutputFormat: String? = null
)
