package com.bookmyspace.bookmyspace

import android.content.Context
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceRepository
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceSettings
import com.bookmyspace.bookmyspace.data.invoice.VenueTaxInvoiceOverride
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.report.BusinessReportEngine
import com.bookmyspace.bookmyspace.data.report.ReportTimeRange
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
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
class AdminConfigurationAndDynamicEngineE2ETest {

    private lateinit var context: Context
    private lateinit var invoiceRepository: TaxInvoiceRepository

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        invoiceRepository = TaxInvoiceRepository.getInstance(context)
        invoiceRepository.updateAdminSettings(TaxInvoiceSettings())
        BookMySpaceRepository.logout()
    }

    @Test
    fun testAdminEndToEndConfigurationAndReportsFlow() {
        runBlocking {
            // STEP 1: Admin Authentication
            BookMySpaceRepository.quickLogin(UserRole.ADMIN)
            val adminUser = BookMySpaceRepository.authUser.value
            assertNotNull("Admin should be authenticated", adminUser)
            assertEquals(UserRole.ADMIN, adminUser?.role)

            // STEP 2: Configure Dynamic Registration Schema (JSON Engine)
            val currentFields = BookMySpaceRepository.registrationFields.value
            assertTrue("Base fields must not be empty", currentFields.isNotEmpty())

            val customField = UserRegistrationFieldDefinition(
                id = "field_gstin_${UUID.randomUUID().toString().take(6)}",
                key = "company_gstin",
                label = "Company GSTIN / Tax ID",
                placeholder = "e.g., 36AAACB1234F1Z5",
                fieldType = RegistrationFieldType.TEXT,
                required = false,
                isEnabled = true,
                targetModule = RegistrationTargetModule.ALL,
                displayOrder = currentFields.size + 1
            )

            val updatedFields = currentFields + customField
            val exportedJsonWithCustom = RegistrationConfigJsonEngine.exportToJson(updatedFields, prettyPrint = true)
            val importResult = BookMySpaceRepository.importRegistrationConfigJson(exportedJsonWithCustom)
            assertTrue("Import should succeed", importResult.isSuccess)

            val savedFields = BookMySpaceRepository.registrationFields.value
            assertTrue("Custom field should be saved in schema", savedFields.any { it.key == "company_gstin" })

            // STEP 3: Export to JSON & Validate Roundtrip
            val exportedJson = BookMySpaceRepository.exportRegistrationConfigJson(prettyPrint = true)
            assertTrue(exportedJson.contains("company_gstin"))
            assertTrue(exportedJson.contains("schemaVersion"))

            // STEP 4: Admin Customizes Tax Invoices & GST Details
            val newInvoiceSettings = TaxInvoiceSettings(
                businessLegalName = "BookMySpace Enterprise India Limited",
                gstin = "36AAACB9999F1Z1",
                panNumber = "AAACB9999F",
                defaultSacCode = "997212",
                gstTaxRatePercent = 18.0,
                isCgstSgstSplit = true,
                showDigitalSignatureSeal = true,
                showHmacVerificationBadge = true,
                authorizedSignatoryName = "Chief Financial Officer"
            )
            invoiceRepository.updateAdminSettings(newInvoiceSettings)

            val effectiveConfig = invoiceRepository.getEffectiveInvoiceConfig(null)
            assertEquals("BookMySpace Enterprise India Limited", effectiveConfig.businessLegalName)
            assertEquals("36AAACB9999F1Z1", effectiveConfig.gstin)
            assertEquals("Chief Financial Officer", effectiveConfig.authorizedSignatoryName)

            // STEP 5: Add sample bookings to repository & Generate Live Business Reports
            val sampleBooking = Booking(
                id = "admin_b_${UUID.randomUUID().toString().take(6)}",
                venueId = "venue_hyd_1",
                venueName = "Royal Convention Centre",
                bookingDate = "2026-08-30",
                slotLabel = "09:00 AM - 05:00 PM",
                totalAmount = 45000.0,
                totalPrice = 45000.0,
                status = BookingStatus.CONFIRMED,
                paymentStatus = "PAID",
                paymentMethod = "Razorpay Bank Transfer",
                guestCount = 250,
                createdAt = System.currentTimeMillis()
            )
            BookMySpaceRepository.addBooking(sampleBooking)

            val currentBookings = BookMySpaceRepository.bookings.value
            val reportSummary = BusinessReportEngine.generateReport(
                bookings = currentBookings,
                timeRange = ReportTimeRange.ALL_TIME
            )

            assertTrue("Total bookings in report must be >= 1", reportSummary.totalBookings >= 1)
            assertTrue("Total revenue must be > 0", reportSummary.totalRevenue > 0)
            assertTrue("Formatted WhatsApp/Email summary should be generated", reportSummary.formattedMessage.isNotBlank())
        }
    }
}
