package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.discovery.PlaceDiscoveryEngine
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class IndiaDiscoveryAndGeoFilterE2ETest {

    @Test
    fun testEndToEndCascadingLocationSelection() {
        // Step 1: User chooses Country India (IN)
        val states = IndiaLocationMasterData.getStatesForCountry("IN")
        assertTrue(states.size >= 36)

        // Step 2: User selects Andhra Pradesh
        val ap = states.firstOrNull { it.id == "IN-AP" } ?: states.first { it.name.contains("Andhra") }
        val districts = IndiaLocationMasterData.getDistrictsForState(ap.id)
        assertTrue(districts.isNotEmpty())

        // Step 3: User selects Prakasam District
        val prakasam = districts.firstOrNull { it.name.contains("Prakasam") } ?: districts.first()
        val mandals = IndiaLocationMasterData.getMandalsForDistrict(prakasam.id)
        assertTrue(mandals.isNotEmpty())

        // Step 4: User selects Ongole Mandal / Town
        val cities = IndiaLocationMasterData.getCitiesForDistrict(prakasam.id)
        assertTrue(cities.isNotEmpty())

        val ongole = cities.firstOrNull { it.name.contains("Ongole") } ?: cities.first()
        val areas = IndiaLocationMasterData.getAreasForCity(ongole.id)
        assertTrue(areas.isNotEmpty())

        // Step 5: Resolve Nearby Discovery Venues around selected location
        val discoveryPlaces = PlaceDiscoveryEngine.generateLocalizedDiscoveryPlaces(
            lat = ongole.latitude,
            lng = ongole.longitude,
            radiusKm = 20.0,
            categories = listOf("all")
        )
        assertTrue("Discovery engine must return localized venues", discoveryPlaces.isNotEmpty())
        discoveryPlaces.forEach { place ->
            assertTrue(place.name.isNotBlank())
            assertTrue(place.category.isNotBlank())
            assertTrue(place.pricingEstimate.isNotBlank())
        }
    }
}
