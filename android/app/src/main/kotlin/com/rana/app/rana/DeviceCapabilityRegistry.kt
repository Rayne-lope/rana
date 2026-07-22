package com.rana.app.rana

import java.util.Locale

internal const val DEVICE_CAPABILITY_SCHEMA_VERSION = 1

internal enum class DevicePerformanceClass(val wireValue: String) {
    HIGH("high"),
    BALANCED("balanced"),
    COMPATIBILITY("compatibility"),
    SAFE("safe")
}

internal data class PerformanceBudget(
    val targetPreviewFps: Int,
    val minimumPreviewFps: Int,
    val maxP95FrameMs: Double,
    val maxDroppedFramePercent: Double,
    val minimumFreeMemoryMb: Int,
    val glCacheBudgetMb: Int,
    val maxPreviewLongEdge: Int
)

internal data class DeviceCapabilityInputs(
    val manufacturer: String = "unknown",
    val model: String = "unknown",
    val sdkInt: Int = 0,
    val totalMemoryMb: Int = 0,
    val appMemoryClassMb: Int = 0,
    val isLowRamDevice: Boolean = false,
    val gpuRenderer: String? = null,
    val thermalStatusSupported: Boolean = false,
    val cameraHardwareLevel: String = "unknown",
    val rearCameraCount: Int = 0,
    val physicalRearCameraCount: Int = 0,
    val logicalMultiCameraSupported: Boolean = false,
    val heicSupported: Boolean = false,
    val recentRendererFailureCount: Int = 0
)

internal data class DeviceCapabilityOverride(
    val manufacturer: String,
    val model: String,
    val minimumSdk: Int = 0,
    val maximumSdk: Int = Int.MAX_VALUE,
    val performanceClass: DevicePerformanceClass,
    val reason: String
) {
    fun matches(inputs: DeviceCapabilityInputs): Boolean =
        normalize(manufacturer) == normalize(inputs.manufacturer) &&
            normalize(model) == normalize(inputs.model) &&
            inputs.sdkInt in minimumSdk..maximumSdk
}

internal data class DeviceCapabilityProfile(
    val schemaVersion: Int,
    val manufacturer: String,
    val model: String,
    val sdkInt: Int,
    val totalMemoryMb: Int,
    val appMemoryClassMb: Int,
    val isLowRamDevice: Boolean,
    val gpuRenderer: String?,
    val thermalStatusSupported: Boolean,
    val cameraHardwareLevel: String,
    val rearCameraCount: Int,
    val physicalRearCameraCount: Int,
    val logicalMultiCameraSupported: Boolean,
    val heicSupported: Boolean,
    val recentRendererFailureCount: Int,
    val performanceClass: DevicePerformanceClass,
    val decisionReason: String,
    val budget: PerformanceBudget
) {
    fun toSafeLogValue(): String =
        "schemaVersion=$schemaVersion manufacturer=${auditValue(manufacturer)} " +
            "model=${auditValue(model)} sdkInt=$sdkInt totalMemoryMb=$totalMemoryMb " +
            "appMemoryClassMb=$appMemoryClassMb lowRam=$isLowRamDevice " +
            "gpu=${auditValue(gpuRenderer ?: "unknown")} " +
            "thermalSupported=$thermalStatusSupported " +
            "cameraHardwareLevel=${auditValue(cameraHardwareLevel)} " +
            "rearCameras=$rearCameraCount physicalRearCameras=$physicalRearCameraCount " +
            "logicalMultiCamera=$logicalMultiCameraSupported heic=$heicSupported " +
            "rendererFailures=$recentRendererFailureCount " +
            "performanceClass=${performanceClass.wireValue} " +
            "decisionReason=${auditValue(decisionReason)} " +
            "targetFps=${budget.targetPreviewFps} minimumFps=${budget.minimumPreviewFps} " +
            "maxP95Ms=${budget.maxP95FrameMs} " +
            "maxDroppedPercent=${budget.maxDroppedFramePercent} " +
            "minimumFreeMemoryMb=${budget.minimumFreeMemoryMb} " +
            "glCacheBudgetMb=${budget.glCacheBudgetMb} " +
            "maxPreviewLongEdge=${budget.maxPreviewLongEdge}"
}

/**
 * Session-scoped capability registry. Selection is pure and Android collection lives separately.
 */
internal class DeviceCapabilityRegistry(
    initialInputs: DeviceCapabilityInputs,
    private val overrides: List<DeviceCapabilityOverride> = emptyList()
) {
    private var inputs = initialInputs.copy(
        manufacturer = normalizedOrUnknown(initialInputs.manufacturer),
        model = normalizedOrUnknown(initialInputs.model),
        cameraHardwareLevel = normalizedOrUnknown(initialInputs.cameraHardwareLevel),
        recentRendererFailureCount = initialInputs.recentRendererFailureCount.coerceAtLeast(0)
    )
    private var latestGpuGeneration = Long.MIN_VALUE

    @Synchronized
    fun updateCollectedInputs(collected: DeviceCapabilityInputs): DeviceCapabilityProfile {
        inputs = collected.copy(
            gpuRenderer = inputs.gpuRenderer ?: collected.gpuRenderer,
            recentRendererFailureCount = inputs.recentRendererFailureCount
        )
        return resolve(inputs, overrides)
    }

    @Synchronized
    fun updateGpuRenderer(renderer: String?, generation: Long): DeviceCapabilityProfile {
        if (generation < latestGpuGeneration) return resolve(inputs, overrides)
        latestGpuGeneration = generation
        inputs = inputs.copy(gpuRenderer = renderer?.trim()?.takeIf(String::isNotEmpty))
        return resolve(inputs, overrides)
    }

    @Synchronized
    fun recordRendererFailure(): DeviceCapabilityProfile {
        inputs = inputs.copy(
            recentRendererFailureCount = if (
                inputs.recentRendererFailureCount == Int.MAX_VALUE
            ) {
                Int.MAX_VALUE
            } else {
                inputs.recentRendererFailureCount + 1
            }
        )
        return resolve(inputs, overrides)
    }

    @Synchronized
    fun snapshot(): DeviceCapabilityProfile = resolve(inputs, overrides)

    companion object {
        fun resolve(
            inputs: DeviceCapabilityInputs,
            overrides: List<DeviceCapabilityOverride> = emptyList()
        ): DeviceCapabilityProfile {
            val matchedOverride = overrides.firstOrNull { it.matches(inputs) }
            val selection = matchedOverride?.let {
                it.performanceClass to "override:${auditValue(normalizedOrUnknown(it.reason))}"
            } ?: classify(inputs)
            return DeviceCapabilityProfile(
                schemaVersion = DEVICE_CAPABILITY_SCHEMA_VERSION,
                manufacturer = normalizedOrUnknown(inputs.manufacturer),
                model = normalizedOrUnknown(inputs.model),
                sdkInt = inputs.sdkInt.coerceAtLeast(0),
                totalMemoryMb = inputs.totalMemoryMb.coerceAtLeast(0),
                appMemoryClassMb = inputs.appMemoryClassMb.coerceAtLeast(0),
                isLowRamDevice = inputs.isLowRamDevice,
                gpuRenderer = inputs.gpuRenderer?.trim()?.takeIf(String::isNotEmpty),
                thermalStatusSupported = inputs.thermalStatusSupported,
                cameraHardwareLevel = normalizedOrUnknown(inputs.cameraHardwareLevel),
                rearCameraCount = inputs.rearCameraCount.coerceAtLeast(0),
                physicalRearCameraCount = inputs.physicalRearCameraCount.coerceAtLeast(0),
                logicalMultiCameraSupported = inputs.logicalMultiCameraSupported,
                heicSupported = inputs.heicSupported,
                recentRendererFailureCount = inputs.recentRendererFailureCount.coerceAtLeast(0),
                performanceClass = selection.first,
                decisionReason = selection.second,
                budget = budgetFor(selection.first)
            )
        }

        fun budgetFor(performanceClass: DevicePerformanceClass): PerformanceBudget =
            when (performanceClass) {
                DevicePerformanceClass.HIGH -> PerformanceBudget(30, 28, 40.0, 3.0, 512, 96, 1920)
                DevicePerformanceClass.BALANCED ->
                    PerformanceBudget(30, 26, 45.0, 5.0, 384, 64, 1600)
                DevicePerformanceClass.COMPATIBILITY ->
                    PerformanceBudget(24, 22, 55.0, 8.0, 256, 32, 1280)
                DevicePerformanceClass.SAFE ->
                    PerformanceBudget(24, 20, 66.7, 12.0, 192, 16, 960)
            }

        private fun classify(inputs: DeviceCapabilityInputs): Pair<DevicePerformanceClass, String> {
            val gpu = inputs.gpuRenderer?.trim()?.lowercase(Locale.US)
            val softwareGpu = gpu != null && listOf("swiftshader", "llvmpipe", "software")
                .any(gpu::contains)
            return when {
                inputs.isLowRamDevice -> DevicePerformanceClass.SAFE to "low_ram_device"
                inputs.totalMemoryMb in 1 until 3072 ->
                    DevicePerformanceClass.SAFE to "total_memory_below_3gb"
                inputs.sdkInt in 1 until 26 -> DevicePerformanceClass.SAFE to "sdk_below_26"
                inputs.cameraHardwareLevel.equals("legacy", ignoreCase = true) ->
                    DevicePerformanceClass.SAFE to "legacy_camera_hardware"
                softwareGpu -> DevicePerformanceClass.SAFE to "software_gpu"
                inputs.recentRendererFailureCount >= 2 ->
                    DevicePerformanceClass.SAFE to "repeated_renderer_failure"
                hasIncompleteCriticalInputs(inputs) ->
                    DevicePerformanceClass.COMPATIBILITY to "incomplete_capabilities"
                inputs.totalMemoryMb < 4096 ->
                    DevicePerformanceClass.COMPATIBILITY to "total_memory_below_4gb"
                inputs.sdkInt < 29 -> DevicePerformanceClass.COMPATIBILITY to "sdk_below_29"
                inputs.totalMemoryMb >= 8192 &&
                    inputs.sdkInt >= 31 &&
                    inputs.cameraHardwareLevel.lowercase(Locale.US) in setOf("full", "level_3") ->
                    DevicePerformanceClass.HIGH to "high_capability_device"
                else -> DevicePerformanceClass.BALANCED to "balanced_capability_device"
            }
        }

        private fun hasIncompleteCriticalInputs(inputs: DeviceCapabilityInputs): Boolean =
            inputs.sdkInt <= 0 ||
                inputs.totalMemoryMb <= 0 ||
                inputs.appMemoryClassMb <= 0 ||
                inputs.gpuRenderer.isNullOrBlank() ||
                inputs.cameraHardwareLevel.isBlank() ||
                inputs.cameraHardwareLevel.equals("unknown", ignoreCase = true)
    }
}

private fun normalize(value: String): String = value.trim().lowercase(Locale.US)

private fun normalizedOrUnknown(value: String): String = value.trim().ifEmpty { "unknown" }

private fun auditValue(value: String): String = value.replace(Regex("[^A-Za-z0-9._-]"), "_")
