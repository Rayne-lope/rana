package com.rana.app.rana

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TelephotoLensSwitchingTest {
    @Test
    fun `sensor normalized focal length selects telephoto`() {
        val topology = buildBackCameraTopology(
            logicalCameraId = "0",
            physicalLenses = listOf(
                PhysicalLensDescriptor("0a", 4f, 6f, true),
                PhysicalLensDescriptor("0b", 6f, 3f, false)
            )
        )

        assertTrue(topology.hasTelephotoCandidate)
        assertEquals("0b", topology.telephotoLens?.cameraId)
        assertEquals(3f, topology.telephotoOpticalRatio ?: 0f, 0.0001f)
    }

    @Test
    fun `insufficient optical spread is not telephoto`() {
        val topology = buildBackCameraTopology(
            logicalCameraId = "0",
            physicalLenses = listOf(
                PhysicalLensDescriptor("0a", 4f, 6f, true),
                PhysicalLensDescriptor("0b", 5f, 6f, false)
            )
        )

        assertFalse(topology.hasTelephotoCandidate)
    }

    @Test
    fun `raw focal ratio is used when sensor metadata is unavailable`() {
        val topology = buildBackCameraTopology(
            logicalCameraId = "0",
            physicalLenses = listOf(
                PhysicalLensDescriptor("0a", 4f, null, true),
                PhysicalLensDescriptor("0b", 8f, null, false)
            )
        )

        assertEquals("0b", topology.telephotoLens?.cameraId)
        assertEquals(2f, topology.telephotoOpticalRatio ?: 0f, 0.0001f)
    }

    @Test
    fun `switch decision uses hysteresis around optical ratio`() {
        val topology = buildBackCameraTopology(
            logicalCameraId = "0",
            physicalLenses = listOf(
                PhysicalLensDescriptor("0a", 4f, 6f, true),
                PhysicalLensDescriptor("0b", 6f, 3f, false)
            )
        )

        val enter = decideLensSwitch(
            requestedZoomRatio = 3f,
            currentOutputTarget = LensOutputTarget.LOGICAL_WIDE,
            topology = topology,
            blockedPhysicalCameraIds = emptySet()
        )
        val hold = decideLensSwitch(
            requestedZoomRatio = 2.8f,
            currentOutputTarget = LensOutputTarget.PHYSICAL_TELE,
            topology = topology,
            blockedPhysicalCameraIds = emptySet()
        )
        val exit = decideLensSwitch(
            requestedZoomRatio = 2.7f,
            currentOutputTarget = LensOutputTarget.PHYSICAL_TELE,
            topology = topology,
            blockedPhysicalCameraIds = emptySet()
        )

        assertEquals(LensOutputTarget.PHYSICAL_TELE, enter.outputTarget)
        assertEquals(LensOutputTarget.PHYSICAL_TELE, hold.outputTarget)
        assertEquals(LensOutputTarget.LOGICAL_WIDE, exit.outputTarget)
    }

    @Test
    fun `telephoto local zoom is relative to optical ratio`() {
        val decision = LensSwitchDecision(
            outputTarget = LensOutputTarget.PHYSICAL_TELE,
            physicalCameraId = "0b",
            telephotoOpticalRatio = 2.5f
        )

        assertEquals(1.2f, localZoomRatioFor(3f, decision), 0.0001f)
    }

    @Test
    fun `blocked physical camera falls back to logical output`() {
        val topology = buildBackCameraTopology(
            logicalCameraId = "0",
            physicalLenses = listOf(
                PhysicalLensDescriptor("0a", 4f, 6f, true),
                PhysicalLensDescriptor("0b", 6f, 3f, false)
            )
        )

        val decision = decideLensSwitch(
            requestedZoomRatio = 3f,
            currentOutputTarget = LensOutputTarget.LOGICAL_WIDE,
            topology = topology,
            blockedPhysicalCameraIds = setOf("0b")
        )

        assertEquals(LensOutputTarget.LOGICAL_WIDE, decision.outputTarget)
    }

    @Test
    fun `telephoto beyond user zoom ceiling stays logical`() {
        val topology = buildBackCameraTopology(
            logicalCameraId = "0",
            physicalLenses = listOf(
                PhysicalLensDescriptor("0a", 4f, 6f, true),
                PhysicalLensDescriptor("0b", 8f, 3f, false)
            )
        )

        val decision = decideLensSwitch(
            requestedZoomRatio = 3f,
            currentOutputTarget = LensOutputTarget.LOGICAL_WIDE,
            topology = topology,
            blockedPhysicalCameraIds = emptySet()
        )

        assertEquals(LensOutputTarget.LOGICAL_WIDE, decision.outputTarget)
    }
}
