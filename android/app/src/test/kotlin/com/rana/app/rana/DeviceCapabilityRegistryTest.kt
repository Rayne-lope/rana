package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceCapabilityRegistryTest {
    @Test
    fun `incomplete capabilities use conservative compatibility profile`() {
        val profile = DeviceCapabilityRegistry.resolve(DeviceCapabilityInputs())

        assertEquals(DevicePerformanceClass.COMPATIBILITY, profile.performanceClass)
        assertEquals("incomplete_capabilities", profile.decisionReason)
        assertEquals(24, profile.budget.targetPreviewFps)
    }

    @Test
    fun `high capability device receives high budget`() {
        val profile = DeviceCapabilityRegistry.resolve(completeInputs(totalMemoryMb = 8192))

        assertEquals(DevicePerformanceClass.HIGH, profile.performanceClass)
        assertEquals(96, profile.budget.glCacheBudgetMb)
        assertEquals(1920, profile.budget.maxPreviewLongEdge)
    }

    @Test
    fun `typical modern device receives balanced budget`() {
        val profile = DeviceCapabilityRegistry.resolve(
            completeInputs(totalMemoryMb = 6144, cameraHardwareLevel = "limited")
        )

        assertEquals(DevicePerformanceClass.BALANCED, profile.performanceClass)
        assertEquals(30, profile.budget.targetPreviewFps)
    }

    @Test
    fun `safe conditions take precedence over otherwise high inputs`() {
        val cases = listOf(
            completeInputs(isLowRamDevice = true),
            completeInputs(totalMemoryMb = 2048),
            completeInputs(sdkInt = 25),
            completeInputs(cameraHardwareLevel = "legacy"),
            completeInputs(gpuRenderer = "Google SwiftShader"),
            completeInputs(recentRendererFailureCount = 2)
        )

        assertTrue(
            cases.all {
                DeviceCapabilityRegistry.resolve(it).performanceClass ==
                    DevicePerformanceClass.SAFE
            }
        )
    }

    @Test
    fun `evidence override matches normalized identity and sdk range`() {
        val override = DeviceCapabilityOverride(
            manufacturer = " Xiaomi ",
            model = "14T PRO",
            minimumSdk = 34,
            maximumSdk = 36,
            performanceClass = DevicePerformanceClass.COMPATIBILITY,
            reason = "verified thermal quirk"
        )

        val matched = DeviceCapabilityRegistry.resolve(
            completeInputs(manufacturer = "xiaomi", model = "14t pro", sdkInt = 35),
            listOf(override)
        )
        val unmatched = DeviceCapabilityRegistry.resolve(
            completeInputs(manufacturer = "xiaomi", model = "14t pro", sdkInt = 33),
            listOf(override)
        )

        assertEquals(DevicePerformanceClass.COMPATIBILITY, matched.performanceClass)
        assertEquals("override:verified_thermal_quirk", matched.decisionReason)
        assertEquals(DevicePerformanceClass.HIGH, unmatched.performanceClass)
    }

    @Test
    fun `stale gpu generation cannot replace newer renderer`() {
        val registry = DeviceCapabilityRegistry(completeInputs(gpuRenderer = null))

        registry.updateGpuRenderer("Adreno 740", generation = 9)
        registry.updateGpuRenderer("stale software renderer", generation = 8)

        assertEquals("Adreno 740", registry.snapshot().gpuRenderer)
        assertEquals(DevicePerformanceClass.HIGH, registry.snapshot().performanceClass)
    }

    @Test
    fun `asynchronous collection preserves renderer state`() {
        val registry = DeviceCapabilityRegistry(
            DeviceCapabilityInputs(manufacturer = "Google", model = "Pixel", sdkInt = 35)
        )
        registry.updateGpuRenderer("Adreno 740", generation = 1)
        registry.recordRendererFailure()

        val profile = registry.updateCollectedInputs(completeInputs(gpuRenderer = null))

        assertEquals("Adreno 740", profile.gpuRenderer)
        assertEquals(1, profile.recentRendererFailureCount)
        assertEquals(DevicePerformanceClass.HIGH, profile.performanceClass)
    }

    @Test
    fun `two renderer failures force safe profile for the session`() {
        val registry = DeviceCapabilityRegistry(completeInputs())

        registry.recordRendererFailure()
        assertEquals(DevicePerformanceClass.HIGH, registry.snapshot().performanceClass)
        registry.recordRendererFailure()

        assertEquals(DevicePerformanceClass.SAFE, registry.snapshot().performanceClass)
        assertEquals("repeated_renderer_failure", registry.snapshot().decisionReason)
    }

    @Test
    fun `budgets reduce resources monotonically and stay valid`() {
        val budgets = listOf(
            DevicePerformanceClass.HIGH,
            DevicePerformanceClass.BALANCED,
            DevicePerformanceClass.COMPATIBILITY,
            DevicePerformanceClass.SAFE
        ).map(DeviceCapabilityRegistry::budgetFor)

        assertTrue(budgets.all { it.targetPreviewFps > 0 })
        assertTrue(budgets.all { it.minimumPreviewFps in 1..it.targetPreviewFps })
        assertTrue(budgets.all { it.maxP95FrameMs.isFinite() && it.maxP95FrameMs > 0 })
        assertTrue(budgets.zipWithNext().all { (higher, lower) ->
            higher.glCacheBudgetMb >= lower.glCacheBudgetMb &&
                higher.maxPreviewLongEdge >= lower.maxPreviewLongEdge
        })
    }

    @Test
    fun `safe audit output contains only capability fields`() {
        val output = DeviceCapabilityRegistry.resolve(completeInputs()).toSafeLogValue()

        assertTrue(output.contains("performanceClass=high"))
        assertFalse(output.contains("content://", ignoreCase = true))
        assertFalse(output.contains("captureId", ignoreCase = true))
        assertFalse(output.contains("filmRollId", ignoreCase = true))
        assertFalse(output.contains("imageData", ignoreCase = true))
        assertNull(DeviceCapabilityRegistry.resolve(completeInputs(gpuRenderer = null)).gpuRenderer)
    }

    private fun completeInputs(
        manufacturer: String = "Google",
        model: String = "Pixel",
        sdkInt: Int = 35,
        totalMemoryMb: Int = 8192,
        appMemoryClassMb: Int = 512,
        isLowRamDevice: Boolean = false,
        gpuRenderer: String? = "Adreno 740",
        cameraHardwareLevel: String = "full",
        recentRendererFailureCount: Int = 0
    ) = DeviceCapabilityInputs(
        manufacturer = manufacturer,
        model = model,
        sdkInt = sdkInt,
        totalMemoryMb = totalMemoryMb,
        appMemoryClassMb = appMemoryClassMb,
        isLowRamDevice = isLowRamDevice,
        gpuRenderer = gpuRenderer,
        thermalStatusSupported = true,
        cameraHardwareLevel = cameraHardwareLevel,
        rearCameraCount = 2,
        physicalRearCameraCount = 2,
        logicalMultiCameraSupported = true,
        heicSupported = true,
        recentRendererFailureCount = recentRendererFailureCount
    )
}
