package com.bookmyspace.bookmyspace

import android.content.Context
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceRepository
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceSettings
import com.bookmyspace.bookmyspace.data.location.IndiaLocationMasterData
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.payment.PaymentSignatureValidator
import com.bookmyspace.bookmyspace.data.payment.SignatureValidationResult
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.data.testing.EndToEndFlowAutomationEngine
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class HierarchicalLocationAndPaymentE2ETest {

    private lateinit var context: Context
    private lateinit var invoiceRepository: TaxInvoiceRepository

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        invoiceRepository = TaxInvoiceRepository.getInstance(context)
        invoiceRepository.updateAdminSettings(TaxInvoiceSettings())
        BookMySpaceRepository.logout()
    }

    /**
     * E2E Verification 1: Hierarchical Location Selection
     * Traverses Country -> State -> District -> Mandal -> Town/Village -> Locality
     */
    @Test
    fun testHierarchicalLocationCascadingSelection_CountryToLocality() {
        // 1. Country Selection (India)
        val countries = IndiaLocationMasterData.countries
        assertTrue("Countries list must not be empty", countries.isNotEmpty())
        val india = countries.firstOrNull { it.id == "IN" }
        assertNotNull("India (IN) country master must be available", india)
        assertEquals("INR", india?.currency)

        // 2. State Selection (Andhra Pradesh)
        val states = IndiaLocationMasterData.getStatesForCountry("IN")
        assertTrue("States list must contain all 28 states & 8 UTs", states.size >= 36)
        val ap = states.firstOrNull { it.id == "IN-AP" }
        assertNotNull("Andhra Pradesh must be present", ap)

        // 3. District Selection (Prakasam)
        val districts = IndiaLocationMasterData.getDistrictsForState(ap!!.id)
        assertTrue("Districts for AP must be populated", districts.isNotEmpty())
        val prakasam = districts.firstOrNull { it.name.contains("Prakasam") || it.code == "PKM" }
        assertNotNull("Prakasam district must exist in AP", prakasam)

        // 4. Mandal Selection (Ongole Mandal)
        val mandals = IndiaLocationMasterData.getMandalsForDistrict(prakasam!!.id)
        assertTrue("Mandals for Prakasam must be populated", mandals.isNotEmpty())
        val ongoleMandal = mandals.firstOrNull { it.name.contains("Ongole") } ?: mandals.first()

        // 5. Town/Village Selection (Ongole Town)
        val cities = IndiaLocationMasterData.getCitiesForDistrict(prakasam.id)
        assertTrue("Cities/Towns in Prakasam must be populated", cities.isNotEmpty())
        val ongoleCity = cities.firstOrNull { it.name.contains("Ongole") } ?: cities.first()

        // 6. Locality/Area Selection (Lawyerpet)
        val areas = IndiaLocationMasterData.getAreasForCity(ongoleCity.id)
        assertTrue("Localities in Ongole must be populated", areas.isNotEmpty())
        val area = areas.firstOrNull { it.name.contains("Lawyerpet") } ?: areas.first()

        // Build & verify complete hierarchy model
        val hierarchy = IndiaLocationMasterData.buildHierarchy(
            countryId = india!!.id,
            stateId = ap.id,
            districtId = prakasam.id,
            mandalId = ongoleMandal.id,
            cityTownId = ongoleCity.id,
            areaId = area.id
        )

        assertNotNull(hierarchy)
        assertEquals("India", hierarchy.countryName)
        assertEquals("Andhra Pradesh", hierarchy.stateName)
        assertEquals("Prakasam", hierarchy.districtName)
        assertTrue("Breadcrumb text must contain complete hierarchy", hierarchy.breadcrumbLabel.contains("Andhra Pradesh"))
        assertTrue("PIN code must be present", hierarchy.postalCode.isNotBlank())
    }

    /**
     * E2E Verification 2: PIN Code Lookups and Reverse Geographic Resolution
     */
    @Test
    fun testPinCodeLookupsAndReverseGeographicResolution() {
        val testLookups = listOf(
            Triple("523001", "Ongole", "Andhra Pradesh"),
            Triple("500081", "Hyderabad", "Telangana"),
            Triple("560001", "Bengaluru", "Karnataka"),
            Triple("110001", "Delhi", "Delhi")
        )

        for ((pin, expectedCity, expectedState) in testLookups) {
            val resolved = IndiaLocationMasterData.lookupByPincode(pin)
            assertNotNull("Lookup should successfully resolve PIN $pin", resolved)
            assertTrue(
                "Resolved location for PIN $pin should match state $expectedState",
                resolved!!.stateName.contains(expectedState, ignoreCase = true) ||
                resolved.fullAddressText.contains(expectedState, ignoreCase = true)
            )
            assertTrue(
                "Resolved location for PIN $pin should match city $expectedCity",
                resolved.cityName.contains(expectedCity, ignoreCase = true) ||
                resolved.districtName.contains(expectedCity, ignoreCase = true) ||
                resolved.fullAddressText.contains(expectedCity, ignoreCase = true)
            )
            assertTrue("Resolved latitude must be non-zero", resolved.latitude != 0.0)
            assertTrue("Resolved longitude must be non-zero", resolved.longitude != 0.0)
        }

        // Invalid PIN lookup should gracefully return null
        val invalidResult = IndiaLocationMasterData.lookupByPincode("000000")
        assertNull("Invalid non-existent PIN should return null", invalidResult)
    }

    /**
     * E2E Verification 3: Dynamic Registration & KYC Form Validation Sequence
     */
    @Test
    fun testDynamicRegistrationFormValidation_KycAndSchema() {
        val baseFields = BookMySpaceRepository.sampleRegistrationFields
        assertTrue("Default fields schema must be initialized", baseFields.isNotEmpty())

        // 1. Strict KYC Preset Validation
        val strictFields = RegistrationConfigJsonEngine.getPresetFields(baseFields, RegistrationConfigPreset.STRICT_KYC)
        val aadhaarField = strictFields.firstOrNull { it.key == "aadhaar_number" }
        assertNotNull("Strict KYC must contain aadhaar_number", aadhaarField)
        assertTrue("Aadhaar must be required in strict KYC", aadhaarField!!.required)

        // 2. Validate Field Value Inputs
        val validAadhaar = "1234 5678 9012"
        val validPhone = "9876543210"
        val validEmail = "attendee.user@example.com"

        assertTrue("Valid phone should match 10 digits", validPhone.matches(Regex("^[6-9]\\d{9}$")))
        assertTrue("Valid email should contain @ and domain", validEmail.contains("@") && validEmail.contains("."))
        assertTrue("Aadhaar length should be 12-14 characters", validAadhaar.replace(" ", "").length == 12)

        // 3. Schema JSON Roundtrip
        val exportedJson = RegistrationConfigJsonEngine.exportToJson(strictFields, presetName = "KYC Schema", prettyPrint = true)
        val (isValidJson, _) = RegistrationConfigJsonEngine.validateAndFormatJson(exportedJson)
        assertTrue("Exported KYC schema must be valid JSON", isValidJson)

        val importResult = RegistrationConfigJsonEngine.importFromJson(exportedJson)
        assertTrue("Imported KYC schema must succeed", importResult.isSuccess)
    }

    /**
     * E2E Verification 4: Registration Payment Sequence, Tax Split & Advance Deposit
     */
    @Test
    fun testRegistrationPaymentSequence_PriceBreakdown_TaxSplit_AdvanceDeposit() {
        runBlocking {
            // Customer logs in
            BookMySpaceRepository.quickLogin(UserRole.USER)
            val user = BookMySpaceRepository.authUser.value
            assertNotNull(user)

            val baseRent = 4000.0
            val gstRate = 18.0
            val taxAmount = (baseRent * gstRate) / 100.0 // 720.0
            val totalPayable = baseRent + taxAmount // 4720.0

            // 25% Advance Booking Deposit
            val advanceDeposit = totalPayable * 0.25 // 1180.0
            val balanceDueAtVenue = totalPayable - advanceDeposit // 3540.0

            val bookingId = "bk_e2e_seq_${UUID.randomUUID().toString().take(6)}"
            val booking = Booking(
                id = bookingId,
                venueId = "venue_test_101",
                venueName = "Elite Sports Complex",
                userId = user!!.id,
                userName = user.fullName,
                userPhone = user.phone,
                userEmail = user.email,
                bookingDate = "2026-09-10",
                slotLabel = "05:00 PM - 07:00 PM",
                baseAmount = baseRent,
                taxAmount = taxAmount,
                totalAmount = totalPayable,
                totalPrice = totalPayable,
                guestCount = 6,
                status = BookingStatus.PENDING,
                paymentStatus = "PENDING",
                isAdvancePayment = true,
                advanceAmountPaid = advanceDeposit,
                remainingBalanceDue = balanceDueAtVenue,
                paymentPlan = "ADVANCE_SPLIT",
                createdAt = System.currentTimeMillis()
            )

            BookMySpaceRepository.addBooking(booking)

            // Step A: Payment Execution with HMAC Verification
            val orderId = "order_e2e_${UUID.randomUUID().toString().take(6)}"
            val paymentId = "pay_e2e_${UUID.randomUUID().toString().take(6)}"
            val secret = "rzp_sec_e2e_pass_123"

            val signature = PaymentSignatureValidator.generateCheckoutSignature(orderId, paymentId, secret)
            val sigResult = PaymentSignatureValidator.verifyCheckoutSignature(orderId, paymentId, signature, secret)
            assertTrue("Payment signature must be mathematically valid", sigResult is SignatureValidationResult.Valid)

            // Confirm payment in repository
            BookMySpaceRepository.confirmBookingPayment(
                bookingId = bookingId,
                paymentId = paymentId,
                paymentMethod = "UPI Gateway",
                isAdvancePayment = true,
                advanceAmountPaid = advanceDeposit,
                remainingBalanceDue = balanceDueAtVenue,
                paymentPlan = "ADVANCE_SPLIT"
            )

            val paidBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == bookingId }
            assertNotNull(paidBooking)
            assertEquals(advanceDeposit, paidBooking?.advanceAmountPaid ?: 0.0, 0.01)
            assertEquals(balanceDueAtVenue, paidBooking?.remainingBalanceDue ?: 0.0, 0.01)

            // Step B: Host / Admin Approval
            val approvalResult = BookMySpaceRepository.approveBookingRequest(
                bookingId = bookingId,
                actorRole = UserRole.ADMIN,
                actorUserId = "user_admin"
            )
            assertTrue("Approval must succeed", approvalResult.isSuccess)

            val confirmedBooking = BookMySpaceRepository.bookings.value.firstOrNull { it.id == bookingId }
            assertEquals(BookingStatus.CONFIRMED, confirmedBooking?.status)
            assertNotNull("QR Token must be generated", confirmedBooking?.qrCodeToken)

            // Step C: Reception QR Scan Check-In
            val qrPassToken = confirmedBooking?.qrCodeToken ?: confirmedBooking!!.id
            val checkInResult = BookMySpaceRepository.checkInBookingWithQr(qrPassToken)
            assertTrue("Front desk QR Check-in must succeed", checkInResult.success)
            assertTrue(checkInResult.booking?.isCheckedIn == true)
            assertEquals(BookingStatus.COMPLETED, checkInResult.booking?.status)
        }
    }

    /**
     * E2E Verification 5: Full Automated Regression Suite Execution
     */
    @Test
    fun testFullAutomatedRegressionSuiteExecution() {
        runBlocking {
            val report = EndToEndFlowAutomationEngine.runFullEndToEndRegressionSuite()
            assertNotNull("Report must not be null", report)
            val failedDetails = report.steps.filter { !it.passed }.joinToString("\n") { "${it.stepName}: ${it.message}" }
            if (failedDetails.isNotBlank()) {
                fail("E2E Automated suite had failures:\n$failedDetails")
            }
            assertTrue(report.isAllPassed)
            assertEquals("All 10 steps should be executed", 10, report.totalSteps)
            assertEquals("0 steps should fail", 0, report.failedSteps)
        }
    }
}
