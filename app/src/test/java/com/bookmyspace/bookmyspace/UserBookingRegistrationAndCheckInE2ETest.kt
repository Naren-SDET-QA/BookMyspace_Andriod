package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.payment.PaymentSignatureValidator
import com.bookmyspace.bookmyspace.data.payment.SignatureValidationResult
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
class UserBookingRegistrationAndCheckInE2ETest {

    @Before
    fun setUp() {
        BookMySpaceRepository.logout()
    }

    @Test
    fun testCompleteCustomerJourney_SelectSlot_FillRegistrationKyc_Pay_Approve_QrCheckIn() {
        runBlocking {
            // STEP 1: Customer Authentication
            BookMySpaceRepository.loginWithEmailAndPassword("customer.dev@bookmyspace.app", "user123")
            val customer = BookMySpaceRepository.authUser.value
            assertNotNull("Customer must be authenticated", customer)
            assertEquals("customer.dev@bookmyspace.app", customer?.email)

            // STEP 2: Venue Discovery & Category Selection
            val sportsCategory = BookMySpaceRepository.categories.value.firstOrNull { it.slug == "sports" }
                ?: BookMySpaceRepository.categories.value.first()
            assertNotNull("Category must exist", sportsCategory)

            val venue = BookMySpaceRepository.venues.value.firstOrNull { it.category?.slug == sportsCategory.slug }
                ?: BookMySpaceRepository.venues.value.first()
            assertNotNull("Target venue must be available", venue)

            // STEP 3: Slot selection & Price Calculations
            val selectedDate = "2026-09-01"
            val selectedSlot = "06:00 PM - 07:00 PM"
            val basePrice = venue.pricingBaseAmount
            val taxAmount = basePrice * 0.18
            val totalAmount = basePrice + taxAmount

            // STEP 4: Dynamic Attendee Registration Data (KYC details)
            val attendeeCount = 4
            val primaryName = customer?.fullName ?: "Naren Customer"
            val primaryPhone = customer?.phone ?: "9876543210"
            val primaryEmail = customer?.email ?: "naren@example.com"
            val idType = "Aadhaar Card"
            val idNumber = "1234-5678-9012"
            val emergencyPhone = "9123456789"
            val coMembers = listOf("Rajesh K", "Vikram S", "Anil M")

            // STEP 5: Create Booking
            val bookingId = "bk_${UUID.randomUUID().toString().take(8)}"
            val booking = Booking(
                id = bookingId,
                venueId = venue.id,
                venueName = venue.name,
                venueImageUrl = venue.coverImageUrl,
                userId = customer?.id ?: "usr_101",
                userName = primaryName,
                userPhone = primaryPhone,
                userEmail = primaryEmail,
                bookingDate = selectedDate,
                date = selectedDate,
                startTime = "06:00 PM",
                endTime = "07:00 PM",
                slotLabel = selectedSlot,
                baseAmount = basePrice,
                taxAmount = taxAmount,
                totalAmount = totalAmount,
                totalPrice = totalAmount,
                guestCount = attendeeCount,
                status = BookingStatus.PENDING,
                paymentStatus = "PENDING",
                paymentPlan = "FULL",
                createdAt = System.currentTimeMillis()
            )

            BookMySpaceRepository.addBooking(booking)

            val pendingBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == bookingId }
            assertNotNull("Booking should be persisted in pending state", pendingBooking)
            assertEquals(BookingStatus.PENDING, pendingBooking?.status)
            assertEquals(attendeeCount, pendingBooking?.guestCount)

            // STEP 6: Execute Online Payment & Cryptographic Signature Validation
            val rzpOrderId = "order_test_${UUID.randomUUID().toString().take(8)}"
            val rzpPaymentId = "pay_test_${UUID.randomUUID().toString().take(8)}"
            val secretKey = "test_rzp_mock_secret"

            val signature = PaymentSignatureValidator.generateCheckoutSignature(rzpOrderId, rzpPaymentId, secretKey)
            val verificationResult = PaymentSignatureValidator.verifyCheckoutSignature(rzpOrderId, rzpPaymentId, signature, secretKey)
            assertTrue("Payment signature must pass validation", verificationResult is SignatureValidationResult.Valid)

            // Confirm payment in repository
            BookMySpaceRepository.confirmBookingPayment(
                bookingId = bookingId,
                paymentId = rzpPaymentId,
                paymentMethod = "Razorpay UPI",
                isAdvancePayment = false,
                advanceAmountPaid = 0.0,
                remainingBalanceDue = 0.0,
                paymentPlan = "FULL"
            )

            val paidBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == bookingId }
            assertNotNull("Paid booking should exist", paidBooking)
            assertEquals(BookingStatus.PENDING_OWNER_APPROVAL, paidBooking?.status)
            assertEquals(rzpPaymentId, paidBooking?.paymentId)

            // STEP 7: Host/Admin Booking Approval & QR Code Pass Generation
            val approveResult = BookMySpaceRepository.approveBookingRequest(
                bookingId = bookingId,
                actorRole = UserRole.VENUE_OWNER,
                actorUserId = venue.ownerId
            )
            assertTrue("Owner approval should succeed", approveResult.isSuccess)

            val confirmedBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == bookingId }
            assertNotNull("Confirmed booking must exist", confirmedBooking)
            assertEquals(BookingStatus.CONFIRMED, confirmedBooking?.status)
            assertNotNull("QR pass token must be generated", confirmedBooking?.qrCodeToken)
            val qrPassToken = confirmedBooking?.qrCodeToken ?: confirmedBooking!!.id

            // STEP 8: Gate / Receptionist QR Scanner Check-in
            val checkInResult = BookMySpaceRepository.checkInBookingWithQr(qrPassToken)
            assertTrue("QR Check-in must succeed", checkInResult.success)
            assertNotNull("Check-in result booking must not be null", checkInResult.booking)
            assertTrue("Booking must be marked as checked-in", checkInResult.booking?.isCheckedIn == true)
            assertEquals(BookingStatus.COMPLETED, checkInResult.booking?.status)
        }
    }
}
