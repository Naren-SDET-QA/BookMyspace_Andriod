package com.bookmyspace.bookmyspace

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * The single place where Android notifications are described and posted.
 *
 * Deliberately built on the plain Android framework plus `androidx.core` only.
 * It needs no Firebase project file, which is what lets the 1-hour
 * pre-booking reminder and the alert fan-out actually reach the notification
 * shade in every build of this app. Remote (server-delivered) push is a
 * separate, opt-in concern handled by [AndroidPushChannel].
 */
internal object PushNotifications {

    const val CHANNEL_ID = "bookmyspace_push"

    private const val CHANNEL_NAME = "BookMySpace Alerts"
    private const val CHANNEL_DESCRIPTION =
        "Booking reminders, check-in passes and waitlist alerts."

    const val EXTRA_PAYLOAD_JSON = "bookmyspace_payload_json"
    const val EXTRA_NOTIFICATION_ID = "bookmyspace_notification_id"
    const val EXTRA_ACTION = "bookmyspace_action"

    /**
     * Everything needed to render one notification. Serialised to JSON so it
     * can ride through an [Intent] to [PushAlarmReceiver] when the reminder is
     * scheduled rather than shown immediately.
     */
    internal data class PushMessage(
        val title: String,
        val body: String,
        val categoryIdentifier: String,
        val data: Map<String, Any?>,
        val actions: List<Pair<String, String>>,
    ) {
        fun toJson(): String {
            val root = JSONObject()
            root.put("title", title)
            root.put("body", body)
            root.put("categoryIdentifier", categoryIdentifier)
            root.put("data", JSONObject().also { dataJson ->
                data.forEach { (key, value) -> if (value != null) dataJson.put(key, value) }
            })
            root.put("actions", JSONArray().also { array ->
                actions.forEach { (action, actionTitle) ->
                    array.put(JSONObject().put("action", action).put("title", actionTitle))
                }
            })
            return root.toString()
        }

        companion object {
            fun fromJson(json: String): PushMessage? = try {
                val root = JSONObject(json)
                val dataObject = root.optJSONObject("data")
                val data = dataObject?.let { obj ->
                    obj.keys().asSequence().associateWith { key ->
                        obj.opt(key).takeIf { it != JSONObject.NULL }
                    }
                } ?: emptyMap()
                val actionsArray = root.optJSONArray("actions")
                val actions = if (actionsArray == null) {
                    emptyList()
                } else {
                    (0 until actionsArray.length()).mapNotNull { index ->
                        val entry = actionsArray.optJSONObject(index) ?: return@mapNotNull null
                        val action = entry.optString("action").takeIf { it.isNotEmpty() }
                            ?: return@mapNotNull null
                        action to entry.optString("title")
                    }
                }
                PushMessage(
                    title = root.optString("title").takeIf { it.isNotEmpty() } ?: "BookMySpace",
                    body = root.optString("body"),
                    categoryIdentifier = root.optString("categoryIdentifier")
                        .takeIf { it.isNotEmpty() } ?: "GENERAL_ALERT",
                    data = data,
                    actions = actions,
                )
            } catch (_: Exception) {
                null
            }
        }
    }

    /** Creates the notification channel once. No-op below API 26. */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableLights(true)
                enableVibration(true)
            },
        )
    }

    fun build(context: Context, notificationId: Int, message: PushMessage): Notification {
        ensureChannel(context)
        val payload = message.toJson()

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(message.title)
            .setContentText(message.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message.body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(tapIntent(context, notificationId, payload, action = null))

        message.actions.forEachIndexed { index, (action, title) ->
            builder.addAction(
                0,
                title,
                tapIntent(context, notificationId, payload, action, requestOffset = index + 1),
            )
        }
        return builder.build()
    }

    /**
     * Opens [MainActivity] with the payload attached. `FLAG_ACTIVITY_SINGLE_TOP`
     * keeps a warm tap on the existing task so `onNewIntent` fires instead of a
     * second activity being created.
     */
    private fun tapIntent(
        context: Context,
        notificationId: Int,
        payload: String,
        action: String?,
        requestOffset: Int = 0,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(EXTRA_PAYLOAD_JSON, payload)
            putExtra(EXTRA_ACTION, action)
        }
        return PendingIntent.getActivity(
            context,
            notificationId * 10 + requestOffset,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun show(context: Context, notificationId: Int, notification: Notification) {
        try {
            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS was not granted. The Dart layer reports the
            // real permission state, so there is nothing to compensate for here.
        }
    }

    fun cancel(context: Context, notificationId: Int) {
        NotificationManagerCompat.from(context).cancel(notificationId)
    }

    fun cancelAll(context: Context) {
        NotificationManagerCompat.from(context).cancelAll()
    }

    /**
     * Converts a stored payload into the map shape Dart expects on
     * `onNotificationClicked` / `getInitialNotification`. The tapped action is
     * injected at read time so one payload serves every button.
     */
    fun toDartMap(json: String, action: String?): Map<String, Any?>? {
        val message = PushMessage.fromJson(json) ?: return null
        return buildMap {
            put("title", message.title)
            put("body", message.body)
            put("data", message.data)
            if (action != null && action.isNotEmpty()) put("action", action)
        }
    }
}
