package com.bookmyspace.bookmyspace

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives the delayed pre-booking reminder that [AndroidPushChannel]
 * scheduled with `AlarmManager` and posts it to the notification shade.
 *
 * This exists because a Dart `Timer` only fires while the process is alive,
 * which is useless for a reminder that is meant to arrive an hour before a
 * booking the user has already closed the app on. Alarms survive that.
 */
class PushAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(PushNotifications.EXTRA_NOTIFICATION_ID, 0)
        val payloadJson =
            intent.getStringExtra(PushNotifications.EXTRA_PAYLOAD_JSON) ?: return

        val message = PushNotifications.PushMessage.fromJson(payloadJson) ?: return
        PushNotifications.show(
            context,
            notificationId,
            PushNotifications.build(context, notificationId, message),
        )
    }
}
