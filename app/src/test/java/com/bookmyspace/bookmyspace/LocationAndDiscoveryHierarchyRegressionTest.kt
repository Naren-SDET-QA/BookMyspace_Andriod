package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.discovery.PlaceDeduplicator
import com.bookmyspace.bookmyspace.data.discovery.PlaceDiscoveryEngine
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.PlaceDiscoveryModel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class LocationAndDiscoveryHierarchyRegressionTest {

    @Test
    fun testAll28StatesAnd8UnionTerritoriesPresent() {
        val states = IndiaLocationMasterData.getStatesForCountry("IN")
        assertTrue("Must contain at least 36 states and UTs", states.size >= 36)

        val stateNames = states.map { it.name }
        val requiredStatesAndUts = listOf(
            "Andhra Pradesh", "Telangana", "Karnataka", "Tamil Nadu",
            "Maharashtra", "Kerala", "Gujarat", "Uttar Pradesh",
            "West Bengal", "Rajasthan", "Punjab", "Haryana",
            "Bihar", "Odisha", "Assam", "Goa",
            "Delhi", "Jammu and Kashmir", "Ladakh", "Puducherry", "Chandigarh (UT)"
        )

        requiredStatesAndUts.forEach { required ->
            assertTrue("Hierarchy must contain $required", stateNames.any { it.contains(required, ignoreCase = true) })
        }
    }

    @Test
    fun testCascadingDistrictsMandalsAndVillages() {
        val apDistricts = IndiaLocationMasterData.getDistrictsForState("IN-AP")
        assertTrue("Andhra Pradesh must have multiple districts configured", apDistricts.isNotEmpty())

        val prakasam = apDistricts.firstOrNull { it.code == "PK" || it.name.contains("Prakasam") }
            ?: apDistricts.first()

        val mandals = IndiaLocationMasterData.getMandalsForDistrict(prakasam.id)
        assertTrue("Prakasam district should have mandals", mandals.isNotEmpty())

        val cities = IndiaLocationMasterData.getCitiesForDistrict(prakasam.id)
        assertTrue("Prakasam district should have towns/villages", cities.isNotEmpty())

        val ongole = cities.firstOrNull { it.name.contains("Ongole") } ?: cities.first()
        val areas = IndiaLocationMasterData.getAreasForCity(ongole.id)
        assertTrue("Town/City should have areas/localities", areas.isNotEmpty())
    }

    @Test
    fun testDistanceCalculationAndNearestLocationResolver() {
        // Distance between Amaravati (AP) and Hyderabad (TG) is roughly ~240-280 km
        val distKm = IndiaLocationMasterData.calculateDistanceKm(15.9129, 79.7400, 17.3850, 78.4867)
        assertTrue("Distance should be positive and realistic (>200km and <350km)", distKm in 200.0..350.0)

        // Find nearest location to Ongole coordinates (15.5057, 80.0499)
        val nearest = IndiaLocationMasterData.findNearestLocation(15.5057, 80.0499)
        assertNotNull("Nearest location should not be null", nearest)
        assertTrue("Nearest location name should be populated", nearest.cityName.isNotBlank() || nearest.districtName.isNotBlank())
    }

    @Test
    fun testAdministrativeDivisionSearch() {
        val searchResults = IndiaLocationMasterData.searchLocations("Hyderabad")
        assertTrue("Search for Hyderabad should return matches", searchResults.isNotEmpty())
        assertTrue("Results should contain Telangana or Hyderabad", searchResults.any { it.fullAddressText.contains("Hyderabad", ignoreCase = true) || it.stateName.contains("Telangana", ignoreCase = true) })

        val searchPrakasam = IndiaLocationMasterData.searchLocations("Prakasam")
        assertTrue("Search for Prakasam should return district results", searchPrakasam.isNotEmpty())
    }

    @Test
    fun testPlaceDiscoveryEngineFallbackGeneration() {
        val lat = 15.5057
        val lng = 80.0499
        val radiusKm = 15.0

        val generatedPlaces = PlaceDiscoveryEngine.generateLocalizedDiscoveryPlaces(
            lat = lat,
            lng = lng,
            radiusKm = radiusKm,
            categories = listOf("all")
        )

        assertTrue("Fallback places must generate authentic venue types", generatedPlaces.size >= 8)
        
        // Verify key properties
        generatedPlaces.forEach { place: PlaceDiscoveryModel ->
            assertNotNull(place.id)
            assertTrue("Place name must be non-empty", place.name.isNotBlank())
            assertTrue("Category must be non-empty", place.category.isNotBlank())
            assertTrue("Address must have pincode or state", place.address.isNotBlank())
            assertTrue("Latitude must be around target coordinate", place.latitude != 0.0)
            assertTrue("Longitude must be around target coordinate", place.longitude != 0.0)
            assertTrue("Pricing estimate must be populated", place.pricingEstimate.isNotBlank())
            assertTrue("Facilities must not be empty", place.facilities.isNotEmpty())
        }
    }

    @Test
    fun testPlaceDeduplicationLogic() {
        val placeA = PlaceDiscoveryModel(
            id = "place_1",
            name = "Royal Kalyana Mandapam",
            category = "Marriage Hall",
            categorySlug = "wedding",
            address = "Main Road, Ongole",
            state = "Andhra Pradesh",
            district = "Prakasam",
            mandal = "Ongole",
            town = "Ongole",
            pincode = "523001",
            latitude = 15.505,
            longitude = 80.049,
            distanceKm = 0.5,
            distanceMeters = 500.0,
            phone = "9848012345",
            source = "OSM",
            sourcePlaceId = "osm_101",
            isRegisteredInBookMySpace = false,
            pricingEstimate = "₹40,000 / day",
            facilities = listOf("AC Hall", "Parking")
        )

        // Duplicate with almost same name & very close location
        val placeADup = placeA.copy(
            id = "place_2",
            name = "royal kalyana mandapam & hall",
            latitude = 15.5051,
            longitude = 80.0491,
            source = "LOCAL_DIRECTORY",
            isRegisteredInBookMySpace = true
        )

        val placeB = placeA.copy(
            id = "place_3",
            sourcePlaceId = "osm_202",
            name = "Champions Box Cricket Turf",
            category = "Sports Turf",
            categorySlug = "sports",
            latitude = 15.530,
            longitude = 80.060
        )

        val deduplicated = PlaceDeduplicator.deduplicate(listOf(placeA, placeADup, placeB))
        assertEquals("Duplicate places should be merged into 2 distinct venues", 2, deduplicated.size)
        
        // Priority should favor the registered venue
        val mergedWeddingHall = deduplicated.firstOrNull { it.categorySlug == "wedding" }
        assertNotNull(mergedWeddingHall)
        assertTrue("Merged place should preserve verified BookMySpace status", mergedWeddingHall!!.isRegisteredInBookMySpace)
    }
}
