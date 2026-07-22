package com.rana.app.rana

internal fun RenderRecipeMessage.toDomainRecipe(): RenderRecipeV1 {
    if (recipeVersion.toInt() != RENDER_RECIPE_VERSION) {
        throw FlutterError(
            "UNSUPPORTED_RECIPE_VERSION",
            "Render recipe version $recipeVersion is not supported.",
            mapOf("recipeVersion" to recipeVersion)
        )
    }

    fun vector(values: List<Double>, size: Int, label: String): List<Float> {
        if (values.size != size || values.any { !it.isFinite() }) {
            throw FlutterError(
                "INVALID_RECIPE",
                "$label must contain $size finite values",
                mapOf("field" to label)
            )
        }
        return values.map(Double::toFloat)
    }

    return RenderRecipeV1(
        temperature = temperature.toFloat().coerceIn(-1f, 1f),
        saturation = saturation.toFloat().coerceIn(-1f, 1f),
        contrast = contrast.toFloat().coerceIn(-1f, 1f),
        colorMatrix = vector(colorMatrix, 9, "colorMatrix"),
        fade = fade.toFloat().coerceIn(0f, 1f),
        grain = grain.toFloat().coerceIn(0f, 1f),
        grainSize = grainSize.toFloat().coerceIn(0.1f, 8f),
        grainShadowsLimit = grainShadowsLimit.toFloat().coerceIn(0f, 0.5f),
        grainHighlightsLimit = grainHighlightsLimit.toFloat().coerceIn(0f, 0.3f),
        vignette = vignette.toFloat().coerceIn(0f, 1f),
        vignetteColor = vector(vignetteColor, 3, "vignetteColor")
            .map { it.coerceIn(0f, 1f) },
        vignetteRoundness = vignetteRoundness.toFloat().coerceIn(0f, 1f),
        lutPath = lutPath?.takeIf(String::isNotEmpty),
        lutStrength = lutStrength.toFloat().coerceIn(0f, 1f),
        lightLeakIntensity = lightLeakIntensity.toFloat().coerceIn(0f, 1f),
        lightLeakVariant = lightLeakVariant.toInt(),
        dustIntensity = dustIntensity.toFloat().coerceIn(0f, 1f),
        dustOffsetX = dustOffsetX.toFloat(),
        dustOffsetY = dustOffsetY.toFloat(),
        bloomThreshold = bloomThreshold.toFloat().coerceIn(0f, 1f),
        bloomIntensity = bloomIntensity.toFloat().coerceIn(0f, 1f),
        halationIntensity = halationIntensity.toFloat().coerceIn(0f, 1f),
        halationRadius = halationRadius.toFloat().coerceIn(0.25f, 4f),
        halationColor = vector(halationColor, 3, "halationColor")
            .map { it.coerceIn(0f, 1f) },
        lensDistortionStrength = lensDistortionStrength.toFloat().coerceIn(0f, 1f),
        chromaticAberrationIntensity =
            chromaticAberrationIntensity.toFloat().coerceIn(0f, 1f),
        highlightRollOff = highlightRollOff.toFloat().coerceIn(0f, 1f),
        shadowRollOff = shadowRollOff.toFloat().coerceIn(0f, 1f),
        filmBorderStyle = normalizedFilmBorderStyle(filmBorderStyle.toInt()),
        dateStampEnable = dateStampEnable,
        shadowsTint = vector(shadowsTint, 3, "shadowsTint"),
        highlightsTint = vector(highlightsTint, 3, "highlightsTint"),
        tone = tone.toFloat().coerceIn(-100f, 100f),
        color = color.toFloat().coerceIn(-100f, 100f),
        texture = texture.toFloat().coerceIn(0f, 100f),
        styleStrength = styleStrength.toFloat().coerceIn(0f, 100f),
        undertoneX = undertoneX.toFloat().coerceIn(-1f, 1f),
        undertoneY = undertoneY.toFloat().coerceIn(-1f, 1f),
        softness = softness.toFloat().coerceIn(0f, 1f),
        outputQuality = outputQuality,
        aspectRatio = aspectRatio,
        presetId = presetId,
        isStyleModified = isStyleModified
    )
}

internal fun RenderRecipeV1.toPigeonMessage(): RenderRecipeMessage = RenderRecipeMessage(
    recipeVersion = RENDER_RECIPE_VERSION.toLong(),
    temperature = temperature.toDouble(),
    saturation = saturation.toDouble(),
    contrast = contrast.toDouble(),
    colorMatrix = colorMatrix.map(Float::toDouble),
    fade = fade.toDouble(),
    grain = grain.toDouble(),
    grainSize = grainSize.toDouble(),
    grainShadowsLimit = grainShadowsLimit.toDouble(),
    grainHighlightsLimit = grainHighlightsLimit.toDouble(),
    vignette = vignette.toDouble(),
    vignetteColor = vignetteColor.map(Float::toDouble),
    vignetteRoundness = vignetteRoundness.toDouble(),
    lutPath = lutPath,
    lutStrength = lutStrength.toDouble(),
    lightLeakIntensity = lightLeakIntensity.toDouble(),
    lightLeakVariant = lightLeakVariant.toLong(),
    dustIntensity = dustIntensity.toDouble(),
    dustOffsetX = dustOffsetX.toDouble(),
    dustOffsetY = dustOffsetY.toDouble(),
    bloomThreshold = bloomThreshold.toDouble(),
    bloomIntensity = bloomIntensity.toDouble(),
    halationIntensity = halationIntensity.toDouble(),
    halationRadius = halationRadius.toDouble(),
    halationColor = halationColor.map(Float::toDouble),
    lensDistortionStrength = lensDistortionStrength.toDouble(),
    chromaticAberrationIntensity = chromaticAberrationIntensity.toDouble(),
    highlightRollOff = highlightRollOff.toDouble(),
    shadowRollOff = shadowRollOff.toDouble(),
    filmBorderStyle = filmBorderStyle.toLong(),
    dateStampEnable = dateStampEnable,
    shadowsTint = shadowsTint.map(Float::toDouble),
    highlightsTint = highlightsTint.map(Float::toDouble),
    tone = tone.toDouble(),
    color = color.toDouble(),
    texture = texture.toDouble(),
    styleStrength = styleStrength.toDouble(),
    undertoneX = undertoneX.toDouble(),
    undertoneY = undertoneY.toDouble(),
    softness = softness.toDouble(),
    outputQuality = outputQuality,
    aspectRatio = aspectRatio,
    presetId = presetId,
    isStyleModified = isStyleModified
)

internal fun RanaCameraEngine.CaptureQualityMetadata?.toPigeonCaptureResult(
    status: String,
    filePath: String?
): CaptureResultMessage = CaptureResultMessage(
    status = status,
    filePath = filePath,
    qualityReduced = this?.qualityReduced ?: false,
    inSampleSize = (this?.inSampleSize ?: 1).toLong(),
    lutSkipped = this?.lutSkipped ?: false,
    requestedOutputQuality =
        this?.requestedOutputQuality ?: OutputQualityProfile.HIGH_JPEG.channelValue,
    actualOutputFormat = this?.actualOutputFormat ?: "jpeg",
    outputMimeType = this?.outputMimeType ?: "image/jpeg",
    outputWidth = (this?.outputWidth ?: 0).toLong(),
    outputHeight = (this?.outputHeight ?: 0).toLong(),
    fileSizeBytes = this?.fileSizeBytes ?: 0L,
    fallbackReason = this?.fallbackReason
)

internal fun CaptureStyleMetadata.toPigeonMessage(): CaptureStyleMetadataMessage {
    val recipe = RenderRecipeV1.fromMap(
        params + mapOf(
            "recipeVersion" to recipeVersion,
            "presetId" to presetId,
            "undertoneX" to undertoneX,
            "undertoneY" to undertoneY
        )
    )
    return CaptureStyleMetadataMessage(
        mediaUri = mediaUri,
        sourceImagePath = sourceImagePath,
        mediaIsRendered = mediaIsRendered,
        recipe = recipe.toPigeonMessage(),
        createdAtEpochMs = createdAtEpochMs,
        updatedAtEpochMs = updatedAtEpochMs,
        filmRollId = filmRollId
    )
}
