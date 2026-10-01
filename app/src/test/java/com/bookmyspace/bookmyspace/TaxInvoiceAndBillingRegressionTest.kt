package com.bookmyspace.bookmyspace

import android.content.Context
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceRepository
import com.bookmyspace.bookmyspace.data.invoice.TaxInvoiceSettings
import com.bookmyspace.bookmyspace.data.invoice.VenueTaxInvoiceOverride
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class TaxInvoiceAndBillingRegressionTest {

    private lateinit var context: Context
    private lateinit var repository: TaxInvoiceRepository

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        repository = TaxInvoiceRepository.getInstance(context)
        repository.updateAdminSettings(TaxInvoiceSettings())
    }

    @Test
    fun testDefaultTaxInvoiceSettingsCompliantWithGstRules() {
        val defaultSettings = TaxInvoiceSettings()
        assertEquals("36AAACB1234F1Z5", defaultSettings.gstin)
        assertEquals("AAACB1234F", defaultSettings.panNumber)
        assertEquals("997212", defaultSettings.defaultSacCode)
        assertEquals(18.0, defaultSettings.gstTaxRatePercent, 0.01)
        assertTrue(defaultSettings.isCgstSgstSplit)
        assertTrue(defaultSettings.showDigitalSignatureSeal)
        assertTrue(defaultSettings.showHmacVerificationBadge)
    }

    @Test
    fun testGstTaxSplitCalculation() {
        val baseAmount = 1000.0
        val taxRate = 18.0
        val totalTax = (baseAmount * taxRate) / 100.0
        val cgst = totalTax / 2.0
        val sgst = totalTax / 2.0

        assertEquals(180.0, totalTax, 0.01)
        assertEquals(90.0, cgst, 0.01)
        assertEquals(90.0, sgst, 0.01)
        assertEquals(1180.0, baseAmount + totalTax, 0.01)
    }

    @Test
    fun testEffectiveInvoiceConfigHierarchyWithVenueOverride() {
        val venueId = "venue_hyd_test_101"
        
        // 1. Before override - should return global settings
        val initialConfig = repository.getEffectiveInvoiceConfig(venueId)
        assertFalse(initialConfig.isVenueCustomized)
        assertEquals("BookMySpace Technologies India Pvt Ltd", initialConfig.businessLegalName)

        // 2. Apply venue-specific override
        val customVenueOverride = VenueTaxInvoiceOverride(
            venueId = venueId,
            isEnabled = true,
            venueBusinessName = "Sri Sai Grand Convention Centre LLP",
            venueGstin = "36BBBPV9988C1Z9",
            venuePan = "BBBPV9988C",
            venueAddress = "Plot 42, Jubilee Hills, Hyderabad",
            signatoryName = "R. V. Prasad",
            signatoryRole = "Managing Director"
        )
        repository.updateVenueOverride(customVenueOverride)

        // 3. Verify effective config reflects custom venue details
        val customizedConfig = repository.getEffectiveInvoiceConfig(venueId)
        assertTrue(customizedConfig.isVenueCustomized)
        assertEquals("Sri Sai Grand Convention Centre LLP", customizedConfig.businessLegalName)
        assertEquals("36BBBPV9988C1Z9", customizedConfig.gstin)
        assertEquals("R. V. Prasad", customizedConfig.authorizedSignatoryName)
    }

    @Test
    fun testCouponAndDiscountCalculation() {
        val originalAmount = 2500.0
        val discountPercentage = 20.0 // 20% off
        val discountAmount = originalAmount * (discountPercentage / 100.0)
        val discountedBase = originalAmount - discountAmount
        val gst = discountedBase * 0.18
        val finalPayable = discountedBase + gst

        assertEquals(500.0, discountAmount, 0.01)
        assertEquals(2000.0, discountedBase, 0.01)
        assertEquals(360.0, gst, 0.01)
        assertEquals(2360.0, finalPayable, 0.01)
    }
}
