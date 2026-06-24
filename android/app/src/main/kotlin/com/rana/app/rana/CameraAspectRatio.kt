package com.rana.app.rana

import android.graphics.Bitmap
import androidx.camera.core.AspectRatio
import java.util.Locale
import kotlin.math.roundToInt

enum class CameraAspectRatio(
    val channelValue: String,
    val label: String,
    val viewfinderRatio: Float,
    val cameraXTargetAspectRatio: Int,
    val captureCropRatio: Float,
) {
    PORTRAIT_3_4(
        channelValue = "portrait_3_4",
        label = "3:4",
        viewfinderRatio = 3f / 4f,
        cameraXTargetAspectRatio = AspectRatio.RATIO_4_3,
        captureCropRatio = 3f / 4f,
    ),
    SQUARE_1_1(
        channelValue = "square_1_1",
        label = "1:1",
        viewfinderRatio = 1f,
        cameraXTargetAspectRatio = AspectRatio.RATIO_4_3,
        captureCropRatio = 1f,
    ),
    PORTRAIT_9_16(
        channelValue = "portrait_9_16",
        label = "9:16",
        viewfinderRatio = 9f / 16f,
        cameraXTargetAspectRatio = AspectRatio.RATIO_16_9,
        captureCropRatio = 9f / 16f,
    );

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

internal fun cropBitmapToAspectRatio(
    bitmap: Bitmap,
    targetAspectRatio: Float,
): Bitmap {
    val bounds = calculateCenterCropBounds(bitmap.width, bitmap.height, targetAspectRatio)
    if (bounds.width == bitmap.width && bounds.height == bitmap.height) {
        return bitmap
    }

    return Bitmap.createBitmap(bitmap, bounds.left, bounds.top, bounds.width, bounds.height)
}
