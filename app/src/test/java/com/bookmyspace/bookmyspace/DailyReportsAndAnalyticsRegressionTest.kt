package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.report.BusinessReportEngine
import com.bookmyspace.bookmyspace.data.report.ReportTimeRange
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class DailyReportsAndAnalyticsRegressionTest {

    @Test
    fun testReportGenerationWithEmptyBookings() {
        val summary = BusinessReportEngine.generateReport(
            bookings = emptyList(),
            transactions = emptyList(),
            timeRange = ReportTimeRange.ALL_TIME
        )

        assertEquals(0, summary.totalBookings)
        assertEquals(0.0, summary.totalRevenue, 0.01)
        assertEquals(0, summary.confirmedBookingsCount)
        assertEquals(0, summary.totalGuestsRegistered)
        assertNotNull(summary.formattedMessage)
    }

    @Test
    fun testReportRevenueAggregationAndBreakdown() {
        val now = System.currentTimeMillis()
        val sampleBookings = listOf(
            Booking(
                id = "b1",
                venueId = "venue_1",
                venueName = "Champions Cricket Turf",
                bookingDate = "2026-08-30",
                slotLabel = "06:00 PM - 07:00 PM",
                totalAmount = 1200.0,
                totalPrice = 1200.0,
                status = BookingStatus.CONFIRMED,
                paymentStatus = "PAID",
                paymentMethod = "UPI",
                guestCount = 8,
                createdAt = now
            ),
            Booking(
                id = "b2",
                venueId = "venue_1",
                venueName = "Champions Cricket Turf",
                bookingDate = "2026-08-30",
                slotLabel = "07:00 PM - 08:00 PM",
                totalAmount = 1200.0,
                totalPrice = 1200.0,
                status = BookingStatus.CONFIRMED,
                paymentStatus = "PAID",
                paymentMethod = "CARD",
                guestCount = 6,
                createdAt = now
            ),
            Booking(
                id = "b3",
                venueId = "venue_2",
                venueName = "Grand Kalyana Mandapam",
                bookingDate = "2026-08-30",
                slotLabel = "Full Day",
                totalAmount = 50000.0,
                totalPrice = 50000.0,
                status = BookingStatus.CONFIRMED,
                paymentStatus = "PAY_AT_VENUE",
                paymentMethod = "PAY_AT_VENUE",
                guestCount = 500,
                createdAt = now
            )
        )

        val summary = BusinessReportEngine.generateReport(
            bookings = sampleBookings,
            timeRange = ReportTimeRange.ALL_TIME
        )

        assertEquals(3, summary.totalBookings)
        assertEquals(52400.0, summary.totalRevenue, 0.01)
        assertEquals(2, summary.onlineBookings)
        assertEquals(1, summary.payAtVenueBookings)
        assertEquals(2400.0, summary.onlineSettledRevenue, 0.01)
        assertEquals(50000.0, summary.payAtVenueRevenue, 0.01)
        assertEquals(514, summary.totalGuestsRegistered)
        assertTrue(summary.paymentBreakdowns.isNotEmpty())
    }

    @Test
    fun testCurrencyFormattingINR() {
        val f1 = BusinessReportEngine.formatINR(1200.0)
        val f2 = BusinessReportEngine.formatINR(50000.0)
        val f3 = BusinessReportEngine.formatINR(150000.0)

        assertTrue(f1.startsWith("₹"))
        assertTrue(f1.contains("1,200") || f1.contains("1200"))
        
        assertTrue(f2.startsWith("₹"))
        assertTrue(f2.contains("50,000") || f2.contains("50000"))

        assertTrue(f3.startsWith("₹"))
        assertTrue(f3.contains("1,50,000") || f3.contains("150,000"))
    }
}
