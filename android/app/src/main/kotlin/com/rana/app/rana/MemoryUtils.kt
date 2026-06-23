package com.rana.app.rana

import android.app.ActivityManager
import android.content.Context
import kotlin.math.max

object MemoryUtils {
    private const val MB = 1024L * 1024L
    const val LOW_MEMORY_MB = 300L
    const val CRITICAL_MEMORY_MB = 150L
    const val DEFAULT_MAX_PROCESSING_DIMENSION = 4096

    data class ProcessingPlan(
        val inSampleSize: Int,
        val qualityReduced: Boolean,
        val skipLut: Boolean,
        val availableMb: Long
    )

    fun calculateSafeInSampleSize(context: Context, targetWidth: Int): Int {
        return calculateMemorySampleSize(getAvailableMemoryMb(context))
            .coerceAtLeast(calculateDimensionSampleSize(targetWidth))
    }

    fun createProcessingPlan(
        context: Context,
        sourceWidth: Int,
        sourceHeight: Int,
        maxProcessingDimension: Int = DEFAULT_MAX_PROCESSING_DIMENSION
    ): ProcessingPlan {
        val availableMb = getAvailableMemoryMb(context)
        val memorySampleSize = calculateMemorySampleSize(availableMb)
        val dimensionSampleSize = calculateDimensionSampleSize(
            max(sourceWidth, sourceHeight),
            maxProcessingDimension
        )
        val inSampleSize = memorySampleSize.coerceAtLeast(dimensionSampleSize)

        return ProcessingPlan(
            inSampleSize = inSampleSize,
            qualityReduced = inSampleSize > 1,
            skipLut = shouldSkipLut(availableMb),
            availableMb = availableMb
        )
    }

    fun calculateMemorySampleSize(availableMb: Long): Int {
        return when {
            availableMb < CRITICAL_MEMORY_MB -> 4
            availableMb < LOW_MEMORY_MB -> 2
            else -> 1
        }
    }

    fun calculateDimensionSampleSize(
        largestDimension: Int,
        maxProcessingDimension: Int = DEFAULT_MAX_PROCESSING_DIMENSION
    ): Int {
        var sampleSize = 1
        while (ceilDivide(largestDimension, sampleSize) > maxProcessingDimension) {
            sampleSize *= 2
        }
        return sampleSize
    }

    fun shouldSkipLut(availableMb: Long): Boolean {
        return availableMb < CRITICAL_MEMORY_MB
    }

    fun getAvailableMemoryMb(context: Context): Long {
        val activityManager = context.getSystemService(
            Context.ACTIVITY_SERVICE
        ) as? ActivityManager ?: return Long.MAX_VALUE
        val memInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memInfo)
        return memInfo.availMem / MB
    }

    private fun ceilDivide(value: Int, divisor: Int): Int {
        return (value + divisor - 1) / divisor
    }
}
