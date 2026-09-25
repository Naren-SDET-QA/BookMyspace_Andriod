package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PlugAndPlayFeaturesTest {

    @Before
    fun setup() {
        BookMySpaceRepository.resetFeaturesToDefault()
    }

    @Test
    fun testAllStandardFeaturesRegistered() {
        val features = BookMySpaceRepository.featureConfigs.value
        assertTrue("Should have at least 24 registered features", features.size >= 24)
        
        // Verify key features exist
        assertTrue(features.any { it.key == AppFeatureKey.MAP_DISCOVERY })
        assertTrue(features.any { it.key == AppFeatureKey.UNIFIED_KYC_REGISTRATION })
        assertTrue(features.any { it.key == AppFeatureKey.ADDONS_AND_CATERING })
        assertTrue(features.any { it.key == AppFeatureKey.AI_SMART_COPILOT })
        assertTrue(features.any { it.key == AppFeatureKey.QR_CODE_PASSES })
        assertTrue(features.any { it.key == AppFeatureKey.MULTI_GATEWAY_PAYMENTS })
    }

    @Test
    fun testToggleFeatureState() {
        BookMySpaceRepository.toggleFeature(AppFeatureKey.VOICE_SEARCH, false)
        assertFalse("Voice search should be disabled", BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.VOICE_SEARCH))

        BookMySpaceRepository.toggleFeature(AppFeatureKey.VOICE_SEARCH, true)
        assertTrue("Voice search should be enabled", BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.VOICE_SEARCH))
    }

    @Test
    fun testPresetsApplication() {
        // Minimalist mode
        BookMySpaceRepository.applyFeaturePreset(FeaturePreset.MINIMALIST_SPEED)
        assertFalse(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.AI_SMART_COPILOT))
        assertFalse(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.ADDONS_AND_CATERING))
        assertTrue(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.MULTI_GATEWAY_PAYMENTS))

        // Full Suite mode
        BookMySpaceRepository.applyFeaturePreset(FeaturePreset.FULL_SUITE)
        assertTrue(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.AI_SMART_COPILOT))
        assertTrue(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.ADDONS_AND_CATERING))
        assertTrue(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.MAP_DISCOVERY))
    }

    @Test
    fun testParameterCustomization() {
        BookMySpaceRepository.setFeatureParam(AppFeatureKey.MAP_DISCOVERY, "defaultRadiusKm", "25")
        val radius = BookMySpaceRepository.getFeatureParam(AppFeatureKey.MAP_DISCOVERY, "defaultRadiusKm", "10")
        assertEquals("25", radius)
    }

    @Test
    fun testJsonExportAndImport() {
        val exportedJson = BookMySpaceRepository.exportFeaturesJson()
        assertNotNull(exportedJson)
        assertTrue(exportedJson.contains("feat_map_discovery"))

        // Modify and reimport
        BookMySpaceRepository.toggleFeature(AppFeatureKey.MAP_DISCOVERY, false)
        assertFalse(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.MAP_DISCOVERY))

        val importResult = BookMySpaceRepository.importFeaturesJson(exportedJson)
        assertTrue(importResult)
        assertTrue(BookMySpaceRepository.isFeatureEnabled(AppFeatureKey.MAP_DISCOVERY))
    }
}
