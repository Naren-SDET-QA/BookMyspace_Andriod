package com.bookmyspace.bookmyspace.data.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository

/**
 * BroadcastReceiver triggered upon device boot to reschedule all active
 * 1-Hour pre-booking push reminders.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == "android.intent.action.MY_PACKAGE_REPLACED") {
            Log.d("BootReceiver", "Device rebooted or app updated. Rescheduling active booking reminders...")
            BookingReminderNotificationManager.createNotificationChannels(context)

            val activeBookings = BookMySpaceRepository.bookings.value
            activeBookings.forEach { booking ->
                if (booking.status.name == "CONFIRMED") {
                    BookingReminderNotificationManager.schedule1HourReminder(context, booking)
                }
            }
        }
    }
}
