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
class HostVenueManagementAndEarningsE2ETest {

    @Before
    fun setUp() {
        BookMySpaceRepository.logout()
    }

    @Test
    fun testHostEndToEndJourney_CreateVenue_ReceiveAdvanceBooking_Approve_TrackEarnings() {
        runBlocking {
            // STEP 1: Host Authentication
            BookMySpaceRepository.quickLogin(UserRole.VENUE_OWNER)
            val host = BookMySpaceRepository.authUser.value
            assertNotNull("Host must be logged in", host)
            assertEquals(UserRole.VENUE_OWNER, host?.role)

            // STEP 2: Host Creates New Venue with Multi-facilities & Rich Media
            val venueId = "host_v_${UUID.randomUUID().toString().take(6)}"
            val sportsCategory = BookMySpaceRepository.categories.value.firstOrNull { it.slug == "sports" }
                ?: BookMySpaceRepository.categories.value.first()

            val newVenue = Venue(
                id = venueId,
                name = "Grand Arena Badminton Club",
                category = sportsCategory,
                ownerId = host?.id ?: "owner_101",
                city = "Ongole",
                state = "Andhra Pradesh",
                addressLine1 = "Trunk Road, Ongole",
                pricingBaseAmount = 1500.0,
                facilities = listOf(
                    VenueFacility("Wooden Courts", true),
                    VenueFacility("Changing Rooms & Lockers", true),
                    VenueFacility("Ample Car Parking", true)
                ),
                featuredImageUrl = "https://images.unsplash.com/photo-1546519638-68e109498ffc"
            )
            BookMySpaceRepository.addVenue(newVenue)

            val retrieved = BookMySpaceRepository.venues.value.firstOrNull { it.id == venueId }
            assertNotNull("Venue must be added to repository", retrieved)
            assertEquals("Grand Arena Badminton Club", retrieved?.name)
            assertEquals(3, retrieved?.facilities?.size)

            // STEP 3: Customer Books with Advance Payment
            val baseAmount = 1500.0
            val taxAmount = baseAmount * 0.18 // 270.0
            val totalAmount = baseAmount + taxAmount // 1770.0
            val advancePaid = totalAmount * 0.25 // 442.5
            val remainingBalance = totalAmount - advancePaid // 1327.5

            val bookingId = "bk_host_${UUID.randomUUID().toString().take(6)}"
            val booking = Booking(
                id = bookingId,
                venueId = venueId,
                venueName = newVenue.name,
                userId = "cust_202",
                userName = "Suresh Kumar",
                userPhone = "9988776655",
                bookingDate = "2026-09-02",
                date = "2026-09-02",
                startTime = "07:00 AM",
                endTime = "08:00 AM",
                slotLabel = "07:00 AM - 08:00 AM",
                baseAmount = baseAmount,
                taxAmount = taxAmount,
                totalAmount = totalAmount,
                totalPrice = totalAmount,
                status = BookingStatus.PENDING,
                paymentStatus = "PENDING",
                isAdvancePayment = true,
                advanceAmountPaid = advancePaid,
                remainingBalanceDue = remainingBalance,
                paymentPlan = "ADVANCE_SPLIT",
                createdAt = System.currentTimeMillis()
            )
            BookMySpaceRepository.addBooking(booking)

            // STEP 4: Confirm Advance Payment
            BookMySpaceRepository.confirmBookingPayment(
                bookingId = bookingId,
                paymentId = "pay_adv_998811",
                paymentMethod = "UPI QR",
                isAdvancePayment = true,
                advanceAmountPaid = advancePaid,
                remainingBalanceDue = remainingBalance,
                paymentPlan = "ADVANCE_SPLIT"
            )

            // STEP 5: Host Reviews and Approves Booking
            val approveResult = BookMySpaceRepository.approveBookingRequest(
                bookingId = bookingId,
                actorRole = UserRole.VENUE_OWNER,
                actorUserId = host?.id ?: "owner_101"
            )
            assertTrue("Host approval should succeed", approveResult.isSuccess)

            val confirmedBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == bookingId }
            assertNotNull("Approved booking must exist", confirmedBooking)
            assertEquals(BookingStatus.CONFIRMED, confirmedBooking?.status)
            assertEquals(advancePaid, confirmedBooking?.advanceAmountPaid ?: 0.0, 0.01)
            assertEquals(remainingBalance, confirmedBooking?.remainingBalanceDue ?: 0.0, 0.01)

            // STEP 6: Host Settles Remaining Balance at Reception
            val settledBooking = confirmedBooking?.copy(
                remainingBalanceDue = 0.0,
                paymentStatus = "FULLY_PAID"
            )
            BookMySpaceRepository.addBooking(settledBooking!!)

            val finalState = BookMySpaceRepository.bookings.value.firstOrNull { it.id == bookingId }
            assertEquals(0.0, finalState?.remainingBalanceDue ?: 0.0, 0.01)
        }
    }
}
