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
class BookingFlowEndToEndTest {

    @Before
    fun setUp() {
        BookMySpaceRepository.logout()
    }

    @Test
    fun testCompleteOwnerUploadToBookingAndPaymentFlow() {
        runBlocking {
            // 1. Owner Upload: Create a new venue with rich media
            val testCategory = BookMySpaceRepository.categories.value.first()
            val customVenue = Venue(
                id = "venue_test_${UUID.randomUUID().toString().take(8)}",
                name = "Champions Arena & Studio",
                category = testCategory,
                featuredImageUrl = "https://images.unsplash.com/photo-1546519638-68e109498ffc",
                images = listOf(
                    VenueImage(id = "img_1", url = "https://images.unsplash.com/photo-1546519638-68e109498ffc", isCover = true),
                    VenueImage(id = "img_2", url = "https://images.unsplash.com/photo-1534438327276-14e5300c3a48")
                ),
                videos = listOf(
                    VenueVideo(id = "v1", title = "Walkthrough Tour", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
                ),
                virtual3dTour = Venue3dWalkthrough(id = "t1", title = "3D VR", tourUrl = "https://my.matterport.com/show/?m=sample3d"),
                pricingBaseAmount = 1000.0,
                city = "Hyderabad",
                state = "Telangana",
                addressLine1 = "HITEC City, Hyderabad",
                avgRating = 4.9,
                ratingCount = 42
            )
            BookMySpaceRepository.addVenue(customVenue)

            val retrievedVenue = BookMySpaceRepository.venues.value.firstOrNull { it.id == customVenue.id }
            assertNotNull("Venue should be stored in repository", retrievedVenue)
            assertEquals("Champions Arena & Studio", retrievedVenue?.name)
            assertEquals(2, retrievedVenue?.images?.size)
            assertNotNull("Videos must be present", retrievedVenue?.videos)
            assertNotNull("3D Tour must be present", retrievedVenue?.virtual3dTour)

            // 2. Data-driven Categories: Ensure all categories are available
            val categories = BookMySpaceRepository.categories.value
            assertTrue("Categories list should not be empty", categories.isNotEmpty())
            assertTrue("Categories should include test category slug", categories.any { it.slug == testCategory.slug })

            // 3. User Login & Dynamic Profile Validation
            BookMySpaceRepository.loginWithEmailAndPassword("customer.dev@bookmyspace.app", "user123")
            val user = BookMySpaceRepository.authUser.value
            assertNotNull("Auth user should exist", user)
            assertEquals(UserRole.USER, user?.role)

            // 4. Slot Selection & Booking Creation with Advance Payment Option
            val baseAmount = 1000.0
            val taxAmount = baseAmount * 0.18 // 180.0
            val grandTotal = baseAmount + taxAmount // 1180.0
            val advanceAmount = grandTotal * 0.25 // 295.0
            val remainingBalance = grandTotal - advanceAmount // 885.0

            val newBooking = Booking(
                id = "booking_test_${UUID.randomUUID().toString().take(8)}",
                venueId = customVenue.id,
                venueName = customVenue.name,
                venueImageUrl = customVenue.coverImageUrl,
                userId = user?.id ?: "guest",
                userName = user?.fullName ?: "Customer",
                userPhone = user?.phone ?: "9876543210",
                bookingDate = "2026-08-25",
                date = "2026-08-25",
                startTime = "06:00 PM",
                endTime = "07:00 PM",
                slotLabel = "06:00 PM - 07:00 PM",
                baseAmount = baseAmount,
                taxAmount = taxAmount,
                totalAmount = grandTotal,
                totalPrice = grandTotal,
                status = BookingStatus.PENDING,
                paymentStatus = "PENDING",
                isAdvancePayment = true,
                advanceAmountPaid = advanceAmount,
                remainingBalanceDue = remainingBalance,
                paymentPlan = "ADVANCE_SPLIT"
            )
            BookMySpaceRepository.addBooking(newBooking)

            val pendingBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == newBooking.id }
            assertNotNull("Booking should be persisted in pending state", pendingBooking)
            assertEquals(BookingStatus.PENDING, pendingBooking?.status)
            assertTrue(pendingBooking?.isAdvancePayment == true)
            assertEquals(295.0, pendingBooking?.advanceAmountPaid ?: 0.0, 0.01)
            assertEquals(885.0, pendingBooking?.remainingBalanceDue ?: 0.0, 0.01)

            // 5. Payment Execution: Confirm Payment with Advance Amount & Save Transaction
            val txId = "pay_test_advance_12345"
            val paymentMethod = "Razorpay UPI / Instant"
            BookMySpaceRepository.confirmBookingPayment(
                bookingId = newBooking.id,
                paymentId = txId,
                paymentMethod = paymentMethod,
                isAdvancePayment = true,
                advanceAmountPaid = advanceAmount,
                remainingBalanceDue = remainingBalance,
                paymentPlan = "ADVANCE_SPLIT"
            )

            // 6. Verification: Booking enters PENDING_OWNER_APPROVAL state
            val awaitingApprovalBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == newBooking.id }
            assertNotNull("Booking must exist after payment confirmation", awaitingApprovalBooking)
            assertEquals(BookingStatus.PENDING_OWNER_APPROVAL, awaitingApprovalBooking?.status)
            assertEquals(txId, awaitingApprovalBooking?.paymentId)
            assertEquals(true, awaitingApprovalBooking?.isAdvancePayment)
            assertEquals(295.0, awaitingApprovalBooking?.advanceAmountPaid ?: 0.0, 0.01)
            assertEquals(885.0, awaitingApprovalBooking?.remainingBalanceDue ?: 0.0, 0.01)
            assertEquals("ADVANCE_SPLIT", awaitingApprovalBooking?.paymentPlan)

            // 7. Owner Review & Approval: Transition from PENDING_OWNER_APPROVAL to CONFIRMED
            val approvalResult = BookMySpaceRepository.approveBookingRequest(
                bookingId = newBooking.id,
                actorRole = UserRole.VENUE_OWNER,
                actorUserId = customVenue.ownerId
            )
            assertTrue("Owner approval should succeed", approvalResult.isSuccess)

            val confirmedBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == newBooking.id }
            assertNotNull("Booking must exist after owner approval", confirmedBooking)
            assertEquals(BookingStatus.CONFIRMED, confirmedBooking?.status)
            assertNotNull("Final order ID should be generated upon approval", confirmedBooking?.finalOrderId)
            assertNotNull("QR pass token should be generated upon approval", confirmedBooking?.qrCodeToken)
        }
    }

    @Test
    fun testFullPaymentFlowCalculationAndPersistence() {
        runBlocking {
            BookMySpaceRepository.loginWithEmailAndPassword("customer.dev@bookmyspace.app", "user123")
            val user = BookMySpaceRepository.authUser.value
            val baseAmount = 800.0
            val taxAmount = baseAmount * 0.18 // 144.0
            val grandTotal = baseAmount + taxAmount // 944.0

            val fullBooking = Booking(
                id = "booking_full_${UUID.randomUUID().toString().take(8)}",
                venueId = "venue_1",
                venueName = "Gachibowli Stadium",
                userId = user?.id ?: "guest",
                userName = user?.fullName ?: "Customer",
                userPhone = user?.phone ?: "9876543210",
                bookingDate = "2026-08-26",
                date = "2026-08-26",
                startTime = "07:00 AM",
                endTime = "08:00 AM",
                slotLabel = "07:00 AM - 08:00 AM",
                baseAmount = baseAmount,
                taxAmount = taxAmount,
                totalAmount = grandTotal,
                totalPrice = grandTotal,
                status = BookingStatus.PENDING,
                paymentStatus = "PENDING",
                isAdvancePayment = false,
                advanceAmountPaid = 0.0,
                remainingBalanceDue = 0.0,
                paymentPlan = "FULL"
            )
            BookMySpaceRepository.addBooking(fullBooking)

            val txId = "pay_full_998877"
            BookMySpaceRepository.confirmBookingPayment(
                bookingId = fullBooking.id,
                paymentId = txId,
                paymentMethod = "Credit Card (Visa)",
                isAdvancePayment = false,
                advanceAmountPaid = 0.0,
                remainingBalanceDue = 0.0,
                paymentPlan = "FULL"
            )

            // Booking is initially PENDING_OWNER_APPROVAL
            val pendingApproval = BookMySpaceRepository.bookings.value.firstOrNull { it.id == fullBooking.id }
            assertNotNull(pendingApproval)
            assertEquals(BookingStatus.PENDING_OWNER_APPROVAL, pendingApproval?.status)
            assertEquals(false, pendingApproval?.isAdvancePayment)
            assertEquals(0.0, pendingApproval?.remainingBalanceDue ?: 0.0, 0.01)
            assertEquals("FULL", pendingApproval?.paymentPlan)

            // Owner approves the booking
            val approveResult = BookMySpaceRepository.approveBookingRequest(
                bookingId = fullBooking.id,
                actorRole = UserRole.ADMIN
            )
            assertTrue(approveResult.isSuccess)

            val confirmed = BookMySpaceRepository.bookings.value.firstOrNull { it.id == fullBooking.id }
            assertNotNull(confirmed)
            assertEquals(BookingStatus.CONFIRMED, confirmed?.status)
            assertTrue(!confirmed?.finalOrderId.isNullOrBlank())
        }
    }

    @Test
    fun testOwnerRejectionAndRefundFlow() {
        runBlocking {
            val user = BookMySpaceRepository.authUser.value
            val rejectBooking = Booking(
                id = "booking_reject_${UUID.randomUUID().toString().take(8)}",
                venueId = "venue_1",
                venueName = "Gachibowli Stadium",
                userId = user?.id ?: "guest",
                userName = "Test User",
                userPhone = "9876543210",
                bookingDate = "2026-08-27",
                date = "2026-08-27",
                startTime = "08:00 PM",
                endTime = "09:00 PM",
                slotLabel = "08:00 PM - 09:00 PM",
                baseAmount = 1000.0,
                taxAmount = 180.0,
                totalAmount = 1180.0,
                totalPrice = 1180.0,
                status = BookingStatus.PENDING_OWNER_APPROVAL,
                isPaid = true,
                paymentStatus = "SUCCESS",
                isAdvancePayment = true,
                advanceAmountPaid = 295.0,
                remainingBalanceDue = 885.0
            )
            BookMySpaceRepository.addBooking(rejectBooking)

            // Owner rejects booking
            val rejectResult = BookMySpaceRepository.rejectBookingRequest(
                bookingId = rejectBooking.id,
                reason = "Venue under unscheduled court maintenance",
                actorRole = UserRole.ADMIN
            )
            assertTrue("Rejection should succeed", rejectResult.isSuccess)

            val finalState = BookMySpaceRepository.bookings.value.firstOrNull { it.id == rejectBooking.id }
            assertNotNull(finalState)
            assertEquals(BookingStatus.REJECTED, finalState?.status)
            assertEquals("Venue under unscheduled court maintenance", finalState?.rejectionReason)
            assertNotNull("Refund ID must be generated", finalState?.refundId)
            assertTrue(
                "Refund ID must follow standard prefix",
                finalState?.refundId?.startsWith("rfnd_") == true || finalState?.refundId?.startsWith("ref_") == true
            )
        }
    }
}
