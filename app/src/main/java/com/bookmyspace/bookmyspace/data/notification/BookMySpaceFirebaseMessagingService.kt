package com.bookmyspace.bookmyspace.data.notification

import android.util.Log
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Firebase Cloud Messaging Service for handling incoming FCM push payloads
 * and refreshed FCM registration tokens for 1-Hour Booking Reminders.
 */
class BookMySpaceFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "BookMySpaceFCM"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "Refreshed FCM registration token: $token")
        BookMySpaceRepository.updateFcmToken(token)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "Received FCM RemoteMessage from: ${remoteMessage.from}")

        val data = remoteMessage.data
        val notification = remoteMessage.notification

        // Extract payload data fields
        val reminderType = data["type"] ?: data["reminder_type"] ?: "1_hour_reminder"
        val bookingId = data["booking_id"] ?: data["bookingId"] ?: ""
        val venueName = data["venue_name"] ?: data["venueName"] ?: "BookMySpace Space"
        val slotTime = data["slot_time"] ?: data["slotTime"] ?: "Upcoming Reserved Slot"
        val bookingDate = data["booking_date"] ?: data["bookingDate"] ?: "Today"
        val qrToken = data["qr_token"] ?: data["qrCodeToken"] ?: "BMS-PASS-QR"

        val title = notification?.title ?: data["title"] ?: "⏰ Booking Starts in 1 Hour: $venueName"
        val body = notification?.body ?: data["body"] ?: "Reminder: Your slot ($slotTime) begins in 1 hour. Tap to view your check-in pass."

        Log.d(TAG, "Processing FCM push notification: title='$title', bookingId='$bookingId'")

        // Display high-priority heads-up reminder notification
        BookingReminderNotificationManager.show1HourReminderNotification(
            context = applicationContext,
            bookingId = bookingId,
            venueName = venueName,
            slotTime = slotTime,
            bookingDate = bookingDate,
            qrCodeToken = qrToken,
            customTitle = title,
            customBody = body
        )
    }
}
