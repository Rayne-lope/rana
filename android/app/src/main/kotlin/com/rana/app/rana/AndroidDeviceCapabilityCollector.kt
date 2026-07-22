package com.rana.app.rana

import android.app.ActivityManager
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build

/** Evidence-backed overrides are added only after a recorded physical-device failure. */
internal val defaultDeviceCapabilityOverrides: List<DeviceCapabilityOverride> = emptyList()

internal class AndroidDeviceCapabilityCollector(private val context: Context) {
    fun collect(): DeviceCapabilityInputs {
        val memory = collectMemory()
        val camera = collectCameraInventory()
        return DeviceCapabilityInputs(
            manufacturer = Build.MANUFACTURER.orEmpty(),
            model = Build.MODEL.orEmpty(),
            sdkInt = Build.VERSION.SDK_INT,
            totalMemoryMb = memory.totalMemoryMb,
            appMemoryClassMb = memory.appMemoryClassMb,
            isLowRamDevice = memory.isLowRamDevice,
            thermalStatusSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q,
            cameraHardwareLevel = camera.hardwareLevel,
            rearCameraCount = camera.rearCameraCount,
            physicalRearCameraCount = camera.physicalRearCameraCount,
            logicalMultiCameraSupported = camera.logicalMultiCameraSupported,
            heicSupported = outputCapabilities().isHeicSupported
        )
    }

    private fun collectMemory(): MemoryInventory = runCatching {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(info)
        MemoryInventory(
            totalMemoryMb = bytesToMb(info.totalMem),
            appMemoryClassMb = manager.memoryClass.coerceAtLeast(0),
            isLowRamDevice = manager.isLowRamDevice
        )
    }.getOrDefault(MemoryInventory())

    private fun collectCameraInventory(): CameraInventory = runCatching {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        var rearCameraCount = 0
        var bestHardwareLevel: Int? = null
        var logicalMultiCameraSupported = false
        val physicalRearCameraIds = mutableSetOf<String>()

        for (cameraId in manager.cameraIdList) {
            val characteristics = manager.getCameraCharacteristics(cameraId)
            if (characteristics.get(CameraCharacteristics.LENS_FACING) !=
                CameraCharacteristics.LENS_FACING_BACK
            ) {
                continue
            }
            rearCameraCount += 1
            characteristics.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)?.let { level ->
                if (bestHardwareLevel == null || hardwareRank(level) > hardwareRank(bestHardwareLevel!!)) {
                    bestHardwareLevel = level
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val capabilities = characteristics.get(
                    CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES
                ) ?: intArrayOf()
                if (capabilities.contains(
                        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
                    )
                ) {
                    logicalMultiCameraSupported = true
                }
                physicalRearCameraIds += characteristics.physicalCameraIds
            }
        }

        CameraInventory(
            hardwareLevel = hardwareLevelName(bestHardwareLevel),
            rearCameraCount = rearCameraCount,
            physicalRearCameraCount = physicalRearCameraIds.size,
            logicalMultiCameraSupported = logicalMultiCameraSupported
        )
    }.getOrDefault(CameraInventory())

    private fun bytesToMb(bytes: Long): Int =
        (bytes / (1024L * 1024L)).coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()

    private fun hardwareRank(level: Int): Int = when (level) {
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> 0
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> 1
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL -> 1
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> 2
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> 3
        else -> -1
    }

    private fun hardwareLevelName(level: Int?): String = when (level) {
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> "legacy"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> "limited"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL -> "external"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "full"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "level_3"
        else -> "unknown"
    }
}

private data class MemoryInventory(
    val totalMemoryMb: Int = 0,
    val appMemoryClassMb: Int = 0,
    val isLowRamDevice: Boolean = false
)

private data class CameraInventory(
    val hardwareLevel: String = "unknown",
    val rearCameraCount: Int = 0,
    val physicalRearCameraCount: Int = 0,
    val logicalMultiCameraSupported: Boolean = false
)
