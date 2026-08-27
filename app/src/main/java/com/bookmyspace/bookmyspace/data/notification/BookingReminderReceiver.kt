package com.bookmyspace.bookmyspace.data.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver triggered by AlarmManager 1 hour before a user's booking starts.
 * Displays the high-priority Heads-Up push notification to the user.
 */
class BookingReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BookingReminderReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "BookingReminderReceiver triggered with action: ${intent.action}")

        val bookingId = intent.getStringExtra(BookingReminderNotificationManager.EXTRA_BOOKING_ID) ?: ""
        val venueName = intent.getStringExtra(BookingReminderNotificationManager.EXTRA_VENUE_NAME) ?: "BookMySpace Venue"
        val slotTime = intent.getStringExtra(BookingReminderNotificationManager.EXTRA_SLOT_TIME) ?: "Upcoming Slot"
        val bookingDate = intent.getStringExtra(BookingReminderNotificationManager.EXTRA_BOOKING_DATE) ?: "Today"
        val qrToken = intent.getStringExtra(BookingReminderNotificationManager.EXTRA_QR_TOKEN) ?: "BMS-PASS"

        if (bookingId.isNotBlank()) {
            Log.d(TAG, "Triggering 1-Hour pre-booking push notification for booking ID: $bookingId")
            BookingReminderNotificationManager.show1HourReminderNotification(
                context = context,
                bookingId = bookingId,
                venueName = venueName,
                slotTime = slotTime,
                bookingDate = bookingDate,
                qrCodeToken = qrToken
            )
        }
    }
}
