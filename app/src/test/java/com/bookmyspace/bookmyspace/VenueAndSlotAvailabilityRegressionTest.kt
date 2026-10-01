package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class VenueAndSlotAvailabilityRegressionTest {

    @Before
    fun setUp() {
        BookMySpaceRepository.logout()
    }

    @Test
    fun testAllStandardCategoriesConfigured() {
        val categories = BookMySpaceRepository.categories.value
        assertTrue("Categories must not be empty", categories.isNotEmpty())

        val categorySlugs = categories.map { it.slug }
        assertTrue("Should contain marriage/kalyana category", categorySlugs.contains("marriage_hall") || categorySlugs.contains("kalyana_mandapam"))
        assertTrue("Should contain function hall category", categorySlugs.contains("function_hall"))
        assertTrue("Should contain banquet category", categorySlugs.contains("banquet_hall"))
        assertTrue("Should contain resort category", categorySlugs.contains("resort"))
        assertTrue("Should contain PG/hostel category", categorySlugs.contains("pg_hostel"))
    }

    @Test
    fun testVenueFilteringByCategoryAndCity() {
        val allVenues = BookMySpaceRepository.venues.value
        assertTrue("Venues list must not be empty", allVenues.isNotEmpty())

        val weddingVenues = allVenues.filter { it.category?.slug?.contains("marriage") == true || it.category?.slug?.contains("function") == true || it.category?.slug?.contains("kalyana") == true }
        assertTrue("Wedding/Function venues should exist", weddingVenues.isNotEmpty())
        weddingVenues.forEach { venue ->
            assertNotNull(venue.category)
            assertTrue(venue.category!!.slug.isNotBlank())
        }
    }

    @Test
    fun testAddAndRetrieveDynamicVenue() {
        runBlocking {
            val sampleCategory = BookMySpaceRepository.categories.value.first()
            val newVenueId = "reg_test_venue_${UUID.randomUUID().toString().take(6)}"
            val dynamicVenue = Venue(
                id = newVenueId,
                name = "Ongole Mega Sports Arena",
                category = sampleCategory,
                city = "Ongole",
                state = "Andhra Pradesh",
                addressLine1 = "Lawyerpet, Ongole, Andhra Pradesh",
                pricingBaseAmount = 1200.0,
                avgRating = 4.8,
                ratingCount = 29,
                facilities = listOf(
                    VenueFacility("Night Floodlights", true),
                    VenueFacility("Synthetic Turf", true),
                    VenueFacility("Parking", true)
                ),
                featuredImageUrl = "https://images.unsplash.com/photo-1574629810360-7efbbe195018"
            )

            BookMySpaceRepository.addVenue(dynamicVenue)

            val fetched = BookMySpaceRepository.venues.value.firstOrNull { it.id == newVenueId }
            assertNotNull("Added dynamic venue should be retrievable", fetched)
            assertEquals("Ongole Mega Sports Arena", fetched?.name)
            assertEquals("Ongole", fetched?.city)
            assertEquals(3, fetched?.facilities?.size)
        }
    }

    @Test
    fun testSlotTimeGeneration() {
        val startHour = 6 // 06:00 AM
        val endHour = 22 // 10:00 PM
        val slots = (startHour until endHour).map { hour ->
            val startFormatted = String.format("%02d:00 %s", if (hour > 12) hour - 12 else if (hour == 0) 12 else hour, if (hour >= 12) "PM" else "AM")
            val nextHour = hour + 1
            val endFormatted = String.format("%02d:00 %s", if (nextHour > 12) nextHour - 12 else if (nextHour == 0) 12 else nextHour, if (nextHour >= 12) "PM" else "AM")
            "$startFormatted - $endFormatted"
        }

        assertEquals("Should produce 16 1-hour slots from 6 AM to 10 PM", 16, slots.size)
        assertEquals("06:00 AM - 07:00 AM", slots.first())
        assertEquals("09:00 PM - 10:00 PM", slots.last())
    }
}
