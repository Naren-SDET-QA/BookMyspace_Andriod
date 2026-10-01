package com.bookmyspace.bookmyspace.data.notification

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.bookmyspace.bookmyspace.MainActivity
import com.bookmyspace.bookmyspace.R
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Data class representing an active scheduled 1-hour pre-booking push reminder.
 */
data class ScheduledReminderInfo(
    val bookingId: String,
    val venueName: String,
    val slotLabel: String,
    val bookingDate: String,
    val scheduledTriggerEpochMs: Long,
    val reminderType: String = "1_HOUR_PRE_SLOT",
    val isActive: Boolean = true
) {
    fun getTimeRemainingFormatted(): String {
        val diffMs = scheduledTriggerEpochMs - System.currentTimeMillis()
        if (diffMs <= 0) return "Triggering soon / Active"
        val hours = diffMs / (1000 * 60 * 60)
        val minutes = (diffMs % (1000 * 60 * 60)) / (1000 * 60)
        return when {
            hours > 24 -> "${hours / 24}d ${hours % 24}h"
            hours > 0 -> "${hours}h ${minutes}m"
            else -> "${minutes}m"
        }
    }
}

/**
 * Central Engine for managing Firebase Cloud Messaging (FCM) push notifications
 * and 1-Hour Pre-Booking Reminder alarms across the BookMySpace ecosystem.
 */
object BookingReminderNotificationManager {

    private const val TAG = "BookingReminderNotif"

    const val CHANNEL_ID_1_HOUR_REMINDERS = "bms_1_hour_booking_reminders_channel"
    const val CHANNEL_NAME_1_HOUR_REMINDERS = "1-Hour Pre-Booking Reminders"
    const val CHANNEL_DESC_1_HOUR_REMINDERS = "Critical push notifications sent 1 hour before booked space slot starts"

    const val CHANNEL_ID_GENERAL_ALERTS = "bms_booking_general_alerts_channel"
    const val CHANNEL_NAME_GENERAL_ALERTS = "Booking Updates & Passes"
    const val CHANNEL_DESC_GENERAL_ALERTS = "General booking confirmations, status updates and QR passes"

    const val CHANNEL_ID_BATCH_AVAILABILITY = "bms_batch_availability_alerts"
    const val CHANNEL_NAME_BATCH_AVAILABILITY = "Batch & Course Availability Alerts"
    const val CHANNEL_DESC_BATCH_AVAILABILITY = "Instant push notifications when spots or batches become available"

    const val ACTION_BOOKING_1_HOUR_REMINDER = "com.bookmyspace.bookmyspace.ACTION_1_HOUR_BOOKING_REMINDER"
    const val EXTRA_BOOKING_ID = "extra_booking_id"
    const val EXTRA_VENUE_NAME = "extra_venue_name"
    const val EXTRA_SLOT_TIME = "extra_slot_time"
    const val EXTRA_BOOKING_DATE = "extra_booking_date"
    const val EXTRA_QR_TOKEN = "extra_qr_token"

    private val scheduledRemindersMap = mutableMapOf<String, ScheduledReminderInfo>()

    /**
     * Initializes notification channels required for Android 8.0+ (Oreo).
     */
    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                .build()

            // 1. High Priority Channel for 1-Hour Pre-Booking Reminders
            val reminderChannel = NotificationChannel(
                CHANNEL_ID_1_HOUR_REMINDERS,
                CHANNEL_NAME_1_HOUR_REMINDERS,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC_1_HOUR_REMINDERS
                enableLights(true)
                lightColor = Color.parseColor("#4338CA")
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                setSound(soundUri, audioAttributes)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }

            // 2. Default Channel for General Booking Updates
            val generalChannel = NotificationChannel(
                CHANNEL_ID_GENERAL_ALERTS,
                CHANNEL_NAME_GENERAL_ALERTS,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = CHANNEL_DESC_GENERAL_ALERTS
                enableLights(true)
                lightColor = Color.parseColor("#4338CA")
                setShowBadge(true)
            }

            // 3. Batch & Course Availability Push Alerts Channel
            val batchChannel = NotificationChannel(
                CHANNEL_ID_BATCH_AVAILABILITY,
                CHANNEL_NAME_BATCH_AVAILABILITY,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC_BATCH_AVAILABILITY
                enableLights(true)
                lightColor = Color.parseColor("#10B981")
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 150, 250)
                setSound(soundUri, audioAttributes)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }

            notificationManager.createNotificationChannels(listOf(reminderChannel, generalChannel, batchChannel))
            Log.d(TAG, "Notification channels registered successfully")
        }
    }

    /**
     * Checks if notification permission is granted on Android 13+ (TIRAMISU).
     */
    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Parses the start time and date of a booking to calculate the exact epoch timestamp 1 hour prior.
     * Supports formats like "10:00 AM", "07:30 PM", "14:00" combined with "2026-08-22", "28 Aug 2026", "22-08-2026".
     */
    fun calculate1HourReminderTimeMillis(dateStr: String, startTimeStr: String): Long {
        val calendar = Calendar.getInstance()
        var dateParsed = false

        val dateFormats = listOf(
            SimpleDateFormat("yyyy-MM-dd", Locale.US),
            SimpleDateFormat("dd MMM yyyy", Locale.US),
            SimpleDateFormat("dd-MM-yyyy", Locale.US),
            SimpleDateFormat("dd/MM/yyyy", Locale.US),
            SimpleDateFormat("MMM dd, yyyy", Locale.US)
        )

        val cleanDate = dateStr.trim()
        for (df in dateFormats) {
            try {
                val parsed = df.parse(cleanDate)
                if (parsed != null) {
                    val dateCal = Calendar.getInstance().apply { time = parsed }
                    calendar.set(Calendar.YEAR, dateCal.get(Calendar.YEAR))
                    calendar.set(Calendar.MONTH, dateCal.get(Calendar.MONTH))
                    calendar.set(Calendar.DAY_OF_MONTH, dateCal.get(Calendar.DAY_OF_MONTH))
                    dateParsed = true
                    break
                }
            } catch (_: Exception) { }
        }

        // If date string contains "Today" or couldn't parse, default to today
        if (!dateParsed) {
            if (cleanDate.contains("Tomorrow", ignoreCase = true)) {
                calendar.add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        // Parse Start Time (e.g., "10:00 AM", "09:30 AM", "07:00 PM", "14:00")
        val cleanTime = startTimeStr.trim()
        val timeFormats = listOf(
            SimpleDateFormat("hh:mm a", Locale.US),
            SimpleDateFormat("h:mm a", Locale.US),
            SimpleDateFormat("hh:mma", Locale.US),
            SimpleDateFormat("HH:mm", Locale.US)
        )

        var timeParsed = false
        for (tf in timeFormats) {
            try {
                val parsedTime = tf.parse(cleanTime)
                if (parsedTime != null) {
                    val timeCal = Calendar.getInstance().apply { time = parsedTime }
                    calendar.set(Calendar.HOUR_OF_DAY, timeCal.get(Calendar.HOUR_OF_DAY))
                    calendar.set(Calendar.MINUTE, timeCal.get(Calendar.MINUTE))
                    calendar.set(Calendar.SECOND, 0)
                    calendar.set(Calendar.MILLISECOND, 0)
                    timeParsed = true
                    break
                }
            } catch (_: Exception) { }
        }

        if (!timeParsed) {
            // Default fallback if time is not standard: set 9:00 AM on the target date
            calendar.set(Calendar.HOUR_OF_DAY, 9)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
        }

        val slotStartEpochMs = calendar.timeInMillis
        // 1 hour before the slot starts = slotStartEpochMs - 3600_000 (1 hour in ms)
        val oneHourBeforeMs = slotStartEpochMs - (60 * 60 * 1000L)
        return oneHourBeforeMs
    }

    /**
     * Schedules a 1-Hour Pre-Booking Reminder for the given booking using AlarmManager.
     */
    fun schedule1HourReminder(context: Context, booking: Booking) {
        if (booking.id.isBlank()) return

        val reminderTimeMs = calculate1HourReminderTimeMillis(
            dateStr = booking.bookingDate.ifBlank { booking.date },
            startTimeStr = booking.startTime.ifBlank { "10:00 AM" }
        )

        val venueName = booking.venueName.ifBlank { "BookMySpace Venue" }
        val slotLabel = booking.slotLabel.ifBlank { "${booking.startTime} - ${booking.endTime}".ifBlank { "Reserved Slot" } }
        val dateLabel = booking.bookingDate.ifBlank { booking.date }

        val info = ScheduledReminderInfo(
            bookingId = booking.id,
            venueName = venueName,
            slotLabel = slotLabel,
            bookingDate = dateLabel,
            scheduledTriggerEpochMs = reminderTimeMs
        )
        scheduledRemindersMap[booking.id] = info

        val now = System.currentTimeMillis()
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        val intent = Intent(context, BookingReminderReceiver::class.java).apply {
            action = ACTION_BOOKING_1_HOUR_REMINDER
            putExtra(EXTRA_BOOKING_ID, booking.id)
            putExtra(EXTRA_VENUE_NAME, venueName)
            putExtra(EXTRA_SLOT_TIME, slotLabel)
            putExtra(EXTRA_BOOKING_DATE, dateLabel)
            putExtra(EXTRA_QR_TOKEN, booking.qrCodeToken.ifBlank { "BMS-PASS-${booking.id.takeLast(6).uppercase()}" })
        }

        val requestCode = booking.id.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (reminderTimeMs > now) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        reminderTimeMs,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        reminderTimeMs,
                        pendingIntent
                    )
                }
                Log.d(TAG, "Scheduled 1-hour pre-booking reminder for booking ${booking.id} at ${Date(reminderTimeMs)}")
            } else {
                Log.d(TAG, "Booking ${booking.id} start time minus 1hr is already in the past, alarm not set in future")
            }
        } catch (e: SecurityException) {
            // Fallback for Android 12+ if exact alarm permission is restricted
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                if (reminderTimeMs > now) reminderTimeMs else now + 5000,
                pendingIntent
            )
            Log.w(TAG, "Exact alarm permission restricted, used standard alarm fallback: ${e.message}")
        }
    }

    /**
     * Cancels any scheduled reminder for the booking.
     */
    fun cancelReminder(context: Context, bookingId: String) {
        scheduledRemindersMap.remove(bookingId)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, BookingReminderReceiver::class.java).apply {
            action = ACTION_BOOKING_1_HOUR_REMINDER
        }
        val requestCode = bookingId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
        Log.d(TAG, "Cancelled 1-hour reminder for booking $bookingId")
    }

    /**
     * Shows a rich Heads-Up Push Notification indicating the user's booking starts in 1 hour.
     */
    fun show1HourReminderNotification(
        context: Context,
        bookingId: String,
        venueName: String,
        slotTime: String,
        bookingDate: String,
        qrCodeToken: String,
        customTitle: String? = null,
        customBody: String? = null
    ) {
        createNotificationChannels(context)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val title = customTitle ?: "⏰ Booking Starts in 1 Hour!"
        val shortBody = customBody ?: "Your reserved space at $venueName starts in 1 hour ($slotTime). Have your check-in pass ready."
        val expandedBody = """
            📍 Venue: $venueName
            🕒 Slot: $slotTime
            📅 Date: $bookingDate
            🎟️ Pass Token: $qrCodeToken
            
            Please arrive 10 minutes early. Present your QR code pass at the reception for seamless biometric & QR check-in.
        """.trimIndent()

        // 1. Content Intent (Tapping notification opens the app to this booking's details/pass)
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_booking_id", bookingId)
            putExtra("from_fcm_notification", true)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            bookingId.hashCode() + 1,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 2. Action: View QR Pass
        val viewPassPendingIntent = PendingIntent.getActivity(
            context,
            bookingId.hashCode() + 2,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 3. Action: Get Directions (Google Maps Intent)
        val mapsUri = Uri.parse("geo:0,0?q=${Uri.encode("$venueName, Hyderabad")}")
        val mapsIntent = Intent(Intent.ACTION_VIEW, mapsUri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val directionsPendingIntent = PendingIntent.getActivity(
            context,
            bookingId.hashCode() + 3,
            mapsIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID_1_HOUR_REMINDERS)
            .setSmallIcon(R.drawable.ic_notification_booking)
            .setContentTitle(title)
            .setContentText(shortBody)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("⏰ 1-Hour Reminder • $venueName")
                    .setSummaryText("BookMySpace Pre-Slot Reminder")
                    .bigText(expandedBody)
            )
            .setColor(ContextCompat.getColor(context, android.R.color.holo_purple))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .addAction(R.drawable.ic_notification_booking, "🎟️ View Pass", viewPassPendingIntent)
            .addAction(R.drawable.ic_notification_booking, "🗺️ Directions", directionsPendingIntent)

        val notificationId = if (bookingId.isNotBlank()) bookingId.hashCode() else (1000..9999).random()
        notificationManager.notify(notificationId, builder.build())
        Log.d(TAG, "Posted 1-Hour pre-booking push notification for booking $bookingId")

        // Also append into in-app notifications stream so user sees it in app
        BookMySpaceRepository.addNotification(
            title = "⏰ 1-Hour Reminder: $venueName",
            message = "Your slot ($slotTime) on $bookingDate starts in 1 hour. Tap to view your QR pass token ($qrCodeToken).",
            type = "booking"
        )
    }

    /**
     * Instantly triggers a 1-Hour Pre-Booking Reminder notification for testing / immediate verification.
     */
    fun trigger1HourReminderNow(context: Context, booking: Booking) {
        val venueName = booking.venueName.ifBlank { "Velocity Pro Arena" }
        val slotTime = booking.slotLabel.ifBlank { "${booking.startTime} - ${booking.endTime}".ifBlank { "10:00 AM - 11:00 AM" } }
        val bookingDate = booking.bookingDate.ifBlank { booking.date.ifBlank { "Today" } }
        val qrToken = booking.qrCodeToken.ifBlank { "BMS-PASS-${booking.id.takeLast(6).uppercase()}" }

        show1HourReminderNotification(
            context = context,
            bookingId = booking.id.ifBlank { "test_bk_${(1000..9999).random()}" },
            venueName = venueName,
            slotTime = slotTime,
            bookingDate = bookingDate,
            qrCodeToken = qrToken,
            customTitle = "⏰ Booking Starts in 1 Hour: $venueName",
            customBody = "Reminder: Your slot ($slotTime) begins in 60 minutes. Your QR pass is ready for check-in."
        )
    }

    /**
     * Simulates receiving a Firebase Cloud Messaging push payload from the cloud backend.
     */
    fun simulateFcmPushPayload(context: Context, booking: Booking? = null) {
        val targetBooking = booking ?: BookMySpaceRepository.bookings.value.firstOrNull() ?: Booking(
            id = "bk_demo_${(1000..9999).random()}",
            venueName = "Huddle Coworking Hub",
            startTime = "11:00 AM",
            endTime = "01:00 PM",
            slotLabel = "11:00 AM - 01:00 PM",
            bookingDate = "22 Aug 2026",
            qrCodeToken = "BMS-PASS-DEMO88"
        )

        show1HourReminderNotification(
            context = context,
            bookingId = targetBooking.id,
            venueName = targetBooking.venueName.ifBlank { "Nexus Workspaces" },
            slotTime = targetBooking.slotLabel.ifBlank { "${targetBooking.startTime} - ${targetBooking.endTime}" },
            bookingDate = targetBooking.bookingDate.ifBlank { targetBooking.date },
            qrCodeToken = targetBooking.qrCodeToken.ifBlank { "BMS-PASS-${targetBooking.id.takeLast(6).uppercase()}" },
            customTitle = "🚀 FCM Push Alert: Slot in 1 Hour",
            customBody = "Firebase Cloud Messaging has triggered your 1-hour pre-booking alert for ${targetBooking.venueName}."
        )
    }

    /**
     * Returns list of currently scheduled reminder records.
     */
    fun getActiveScheduledReminders(): List<ScheduledReminderInfo> {
        return scheduledRemindersMap.values.toList()
    }

    /**
     * Shows an immediate Push Notification when spots open up or batch enrollment commences.
     */
    fun showBatchSpotAvailablePushNotification(
        context: Context,
        classId: String,
        className: String,
        instituteName: String,
        availableSpots: Int = 3
    ) {
        createNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val title = "🎉 Spots Available! $className"
        val body = "$availableSpots spot(s) have just opened up for $className at $instituteName. Tap to book your seat before it fills up!"

        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_class_id", classId)
            putExtra("from_batch_alert", true)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            classId.hashCode() + 10,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID_BATCH_AVAILABILITY)
            .setSmallIcon(R.drawable.ic_notification_booking)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("🎉 Batch Spot Available • $instituteName")
                    .setSummaryText("BookMySpace Instant Batch Alert")
                    .bigText("Great news! $availableSpots spots are now open in $className.\n\n🏛️ Institute: $instituteName\n⚡ Tap to secure your enrollment immediately.")
            )
            .setColor(Color.parseColor("#10B981"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .addAction(R.drawable.ic_notification_booking, "⚡ Book Seat Now", contentPendingIntent)

        notificationManager.notify(classId.hashCode(), builder.build())

        // In-app notifications
        BookMySpaceRepository.addNotification(
            title = "🎉 Spot Opened: $className",
            message = "$availableSpots spots now open at $instituteName. Tap to register your seat.",
            type = "course_alert"
        )
    }

    /**
     * Shows a confirmation notification when user subscribes to 'Notify Me' for full or upcoming batch.
     */
    fun showBatchWaitlistSubscribedNotification(
        context: Context,
        classId: String,
        className: String,
        instituteName: String
    ) {
        createNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val title = "🔔 Alert Active: $className"
        val body = "You're on the priority waitlist for $className at $instituteName. We'll send a push notification the moment seats open."

        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_class_id", classId)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            classId.hashCode() + 11,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID_BATCH_AVAILABILITY)
            .setSmallIcon(R.drawable.ic_notification_booking)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("🔔 Availability Alert Active")
                    .setSummaryText("Priority Waitlist Notification")
                    .bigText("You have successfully subscribed to instant availability alerts for:\n\n📚 $className\n🏛️ $instituteName\n\nAs soon as someone cancels or new seats are added, a high-priority push notification will be delivered to your device.")
            )
            .setColor(Color.parseColor("#4338CA"))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)

        notificationManager.notify(classId.hashCode() + 500, builder.build())

        // In-app notifications
        BookMySpaceRepository.addNotification(
            title = "🔔 Alert Subscribed: $className",
            message = "Priority alert registered for $instituteName. You'll receive a push notification when seats become available.",
            type = "alert_registered"
        )
    }
}
