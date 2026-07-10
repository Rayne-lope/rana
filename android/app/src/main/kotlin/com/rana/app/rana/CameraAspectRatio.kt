package com.rana.app.rana

import android.graphics.Bitmap
import android.graphics.Rect
import android.util.Rational
import androidx.camera.core.AspectRatio
import androidx.camera.core.ViewPort
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import java.util.Locale
import kotlin.math.roundToInt

enum class CameraAspectRatio(
    val channelValue: String,
    val label: String,
    val viewfinderRatio: Float,
    val viewportNumerator: Int,
    val viewportDenominator: Int,
) {
    PORTRAIT_3_4(
        channelValue = "portrait_3_4",
        label = "3:4",
        viewfinderRatio = 3f / 4f,
        viewportNumerator = 3,
        viewportDenominator = 4,
    ),
    SQUARE_1_1(
        channelValue = "square_1_1",
        label = "1:1",
        viewfinderRatio = 1f,
        viewportNumerator = 1,
        viewportDenominator = 1,
    ),
    PORTRAIT_9_16(
        channelValue = "portrait_9_16",
        label = "9:16",
        viewfinderRatio = 9f / 16f,
        viewportNumerator = 9,
        viewportDenominator = 16,
    );

    val cameraXTargetAspectRatio: Int
        get() = when (this) {
            PORTRAIT_3_4, SQUARE_1_1 -> AspectRatio.RATIO_4_3
            PORTRAIT_9_16 -> AspectRatio.RATIO_16_9
        }

    val resolutionAspectRatioStrategy: AspectRatioStrategy
        get() = when (this) {
            PORTRAIT_3_4, SQUARE_1_1 ->
                AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY

            PORTRAIT_9_16 ->
                AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY
        }

    fun resolutionSelector(): ResolutionSelector = ResolutionSelector.Builder()
        .setAspectRatioStrategy(resolutionAspectRatioStrategy)
        .build()

    fun viewPort(rotation: Int): ViewPort = ViewPort.Builder(
        Rational(viewportNumerator, viewportDenominator),
        rotation
    )
        .setScaleType(ViewPort.FILL_CENTER)
        .build()

    companion object {
        fun fromChannelValue(value: String?): CameraAspectRatio {
            return when (value?.lowercase(Locale.US)) {
                SQUARE_1_1.channelValue, "1:1", "square", "square_1_1" -> SQUARE_1_1
                PORTRAIT_9_16.channelValue, "9:16", "9_16", "portrait_9_16" -> PORTRAIT_9_16
                else -> PORTRAIT_3_4
            }
        }
    }
}

data class CenterCropBounds(
    val left: Int,
    val top: Int,
    val width: Int,
    val height: Int,
)

data class SampledCropBounds(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
) {
    val width: Int
        get() = right - left

    val height: Int
        get() = bottom - top
}

internal fun calculateCenterCropBounds(
    sourceWidth: Int,
    sourceHeight: Int,
    targetAspectRatio: Float,
): CenterCropBounds {
    if (sourceWidth <= 0 || sourceHeight <= 0 || targetAspectRatio <= 0f) {
        return CenterCropBounds(0, 0, sourceWidth.coerceAtLeast(0), sourceHeight.coerceAtLeast(0))
    }

    val sourceAspectRatio = sourceWidth.toFloat() / sourceHeight.toFloat()
    if (kotlin.math.abs(sourceAspectRatio - targetAspectRatio) < 0.0001f) {
        return CenterCropBounds(0, 0, sourceWidth, sourceHeight)
    }

    return if (sourceAspectRatio > targetAspectRatio) {
        val targetWidth = (sourceHeight * targetAspectRatio).roundToInt().coerceAtLeast(1)
        val left = ((sourceWidth - targetWidth) / 2).coerceAtLeast(0)
        CenterCropBounds(left, 0, targetWidth, sourceHeight)
    } else {
        val targetHeight = (sourceWidth / targetAspectRatio).roundToInt().coerceAtLeast(1)
        val top = ((sourceHeight - targetHeight) / 2).coerceAtLeast(0)
        CenterCropBounds(0, top, sourceWidth, targetHeight)
    }
}

internal fun calculateSampledCropBounds(
    cropLeft: Int,
    cropTop: Int,
    cropRight: Int,
    cropBottom: Int,
    sampleSize: Int,
    bitmapWidth: Int,
    bitmapHeight: Int,
): SampledCropBounds {
    val normalizedSampleSize = sampleSize.coerceAtLeast(1)
    if (bitmapWidth <= 0 || bitmapHeight <= 0) {
        return SampledCropBounds(0, 0, bitmapWidth.coerceAtLeast(0), bitmapHeight.coerceAtLeast(0))
    }

    val left = (cropLeft / normalizedSampleSize).coerceIn(0, bitmapWidth - 1)
    val top = (cropTop / normalizedSampleSize).coerceIn(0, bitmapHeight - 1)
    val right = ((cropRight + normalizedSampleSize - 1) / normalizedSampleSize)
        .coerceIn(left + 1, bitmapWidth)
    val bottom = ((cropBottom + normalizedSampleSize - 1) / normalizedSampleSize)
        .coerceIn(top + 1, bitmapHeight)

    return SampledCropBounds(left, top, right, bottom)
}

internal fun cropBitmapToRect(
    bitmap: Bitmap,
    cropRect: Rect,
): Bitmap {
    val safeLeft = cropRect.left.coerceIn(0, bitmap.width - 1)
    val safeTop = cropRect.top.coerceIn(0, bitmap.height - 1)
    val safeRight = cropRect.right.coerceIn(safeLeft + 1, bitmap.width)
    val safeBottom = cropRect.bottom.coerceIn(safeTop + 1, bitmap.height)

    if (safeLeft == 0 &&
        safeTop == 0 &&
        safeRight == bitmap.width &&
        safeBottom == bitmap.height
    ) {
        return bitmap
    }

    return Bitmap.createBitmap(
        bitmap,
        safeLeft,
        safeTop,
        safeRight - safeLeft,
        safeBottom - safeTop
    )
}
