package com.bookmyspace.bookmyspace

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

/**
 * Android counterpart of the iOS `apns_push` channel.
 *
 * It exposes the same method names and argument shapes as `AppDelegate.swift`
 * so [PushNotificationService] can drive both platforms through one code path.
 *
 * Two capabilities live here and they are deliberately kept apart:
 *
 *  * **Local notifications** — permission state, channel creation, immediate
 *    display, delayed display via `AlarmManager`, and cancellation. These work
 *    in every build because they need nothing but the Android SDK.
 *  * **Remote push** — a server delivering a message to this device. That
 *    needs an FCM project file *and* a sender, neither of which this repository
 *    has. [remotePushConfigured] reports that truthfully instead of assuming.
 */
class AndroidPushChannel(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) {

    companion object {
        const val CHANNEL_NAME = "com.bookmyspace.bookmyspace/android_push"

        private const val REQUEST_CODE_POST_NOTIFICATIONS = 0x9A71
        private const val PREFS = "bookmyspace_push"
        private const val KEY_HAS_REQUESTED = "has_requested_notification_permission"

        private val nextNotificationId = AtomicInteger(1000)
    }

    private var methodChannel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var initialPayload: Map<String, Any?>? = null

    private val prefs by lazy { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }

    /** True when the firebase-messaging classes are actually on the classpath. */
    private val firebaseMessagingAvailable: Boolean by lazy {
        try {
            Class.forName("com.google.firebase.messaging.FirebaseMessaging")
            true
        } catch (_: Throwable) {
            false
        }
    }

    fun attach(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, CHANNEL_NAME).also { channel ->
            channel.setMethodCallHandler(::onMethodCall)
        }
        PushNotifications.ensureChannel(context)
    }

    // -------------------------------------------------------------------------
    // MethodChannel dispatch
    // -------------------------------------------------------------------------

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> result.success(permissionStatusMap())

            "requestPermission" -> requestPermission(result)

            "getToken" -> result.success(tokenMap())

            "showNotification" -> showNotification(call, result)

            "cancelNotification" -> {
                cancelNotification(call)
                result.success(true)
            }

            // Android has no app-icon badge, so clearing the badge means
            // clearing the shade. Same intent as the iOS `clearBadge`.
            "clearBadge" -> {
                PushNotifications.cancelAll(context)
                result.success(true)
            }

            "cancelAll" -> {
                PushNotifications.cancelAll(context)
                result.success(true)
            }

            "unregister" -> {
                PushNotifications.cancelAll(context)
                result.success(true)
            }

            "getInitialNotification" -> {
                val payload = initialPayload
                initialPayload = null
                result.success(payload)
            }

            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Permission
    // -------------------------------------------------------------------------

    private fun notificationsEnabled(): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    /**
     * Below API 33 there is no runtime notification permission to ask for, so
     * the OS-level toggle *is* the answer and `notDetermined` would be a lie.
     * At API 33+ the only way to tell "never asked" from "asked and refused" is
     * to remember that we asked.
     */
    private fun currentStatus(): String = when {
        notificationsEnabled() -> "granted"
        prefs.getBoolean(KEY_HAS_REQUESTED, false) -> "denied"
        else -> "notDetermined"
    }

    private fun permissionStatusMap(): Map<String, Any> = mapOf(
        "status" to currentStatus(),
        "remotePushConfigured" to remotePushConfigured(),
    )

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            val granted = notificationsEnabled()
            result.success(
                mapOf(
                    "granted" to granted,
                    "status" to if (granted) "granted" else "denied",
                    "remotePushConfigured" to remotePushConfigured(),
                ),
            )
            return
        }

        if (notificationsEnabled()) {
            result.success(
                mapOf(
                    "granted" to true,
                    "status" to "granted",
                    "remotePushConfigured" to remotePushConfigured(),
                ),
            )
            return
        }

        val activity = activityProvider()
        if (activity == null || pendingPermissionResult != null) {
            // Cannot present the dialog (no activity, or one is already open).
            // Report the real state rather than an assumed grant.
            result.success(
                mapOf(
                    "granted" to false,
                    "status" to currentStatus(),
                    "remotePushConfigured" to remotePushConfigured(),
                ),
            )
            return
        }

        pendingPermissionResult = result
        prefs.edit().putBoolean(KEY_HAS_REQUESTED, true).apply()
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE_POST_NOTIFICATIONS,
        )
    }

    /** Forwarded from `MainActivity.onRequestPermissionsResult`. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE_POST_NOTIFICATIONS) return
        val pending = pendingPermissionResult ?: return
        pendingPermissionResult = null

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending.success(
            mapOf(
                "granted" to granted,
                "status" to currentStatus(),
                "remotePushConfigured" to remotePushConfigured(),
            ),
        )
    }

    // -------------------------------------------------------------------------
    // Remote push transport
    // -------------------------------------------------------------------------

    /**
     * Whether a *server* could deliver a message to this device.
     *
     * Local notifications work regardless of this answer, which is why it is
     * reported separately instead of being folded into the permission status.
     * It is checked rather than hardcoded so that adding a Firebase project
     * file plus the messaging dependency flips it automatically.
     */
    private fun remotePushConfigured(): Boolean {
        if (!firebaseMessagingAvailable) return false
        val resourceId =
            context.resources.getIdentifier("google_app_id", "string", context.packageName)
        if (resourceId == 0) return false
        return runCatching { context.getString(resourceId) }
            .getOrNull()
            ?.isNotEmpty() == true
    }

    private fun tokenMap(): Map<String, Any?> = mapOf(
        // Always empty: obtaining an FCM registration token needs the
        // firebase-messaging dependency and a project file, neither of which
        // this build carries. `remotePushConfigured` tells Dart why.
        "token" to "",
        "remotePushConfigured" to remotePushConfigured(),
    )

    // -------------------------------------------------------------------------
    // Display
    // -------------------------------------------------------------------------

    private fun showNotification(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val id = (args["id"] as? String)?.takeIf { it.isNotEmpty() }
            ?: "bms_${nextNotificationId.incrementAndGet()}"
        val message = PushNotifications.PushMessage(
            title = (args["title"] as? String)?.takeIf { it.isNotEmpty() } ?: "BookMySpace",
            body = args["body"] as? String ?: "",
            categoryIdentifier = (args["categoryIdentifier"] as? String)
                ?.takeIf { it.isNotEmpty() } ?: "GENERAL_ALERT",
            data = toAnyMap(args["data"]),
            actions = toActions(args["actions"]),
        )
        val notificationId = id.hashCode()
        val delaySeconds = (args["delaySeconds"] as? Number)?.toDouble() ?: 0.0

        if (delaySeconds > 0) {
            scheduleDelayed(notificationId, message, delaySeconds)
            result.success(mapOf("id" to id, "status" to "scheduled"))
            return
        }

        PushNotifications.show(
            context,
            notificationId,
            PushNotifications.build(context, notificationId, message),
        )
        result.success(mapOf("id" to id, "status" to "shown"))
    }

    private fun scheduleDelayed(
        notificationId: Int,
        message: PushNotifications.PushMessage,
        delaySeconds: Double,
    ) {
        val triggerAt = System.currentTimeMillis() + (delaySeconds * 1000L).toLong()
        val intent = Intent(context, PushAlarmReceiver::class.java).apply {
            putExtra(PushNotifications.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(PushNotifications.EXTRA_PAYLOAD_JSON, message.toJson())
        }
        val pending = PendingIntent.getBroadcast(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        // Inexact on purpose. A "your slot starts in an hour" reminder tolerates
        // a few minutes of drift, and asking for exact alarms would mean
        // requesting SCHEDULE_EXACT_ALARM, which Play restricts to alarm-clock
        // style apps. setAndAllowWhileIdle also fires in Doze.
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
    }

    private fun cancelNotification(call: MethodCall) {
        val args = call.arguments as? Map<*, *> ?: return
        val id = args["id"] as? String ?: return
        val notificationId = id.hashCode()

        // Intent equality ignores extras, so a bare intent matches the one the
        // alarm was registered with.
        val pending = PendingIntent.getBroadcast(
            context,
            notificationId,
            Intent(context, PushAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pending != null) {
            (context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)?.cancel(pending)
            pending.cancel()
        }
        PushNotifications.cancel(context, notificationId)
    }

    // -------------------------------------------------------------------------
    // Tap handling, called from MainActivity
    // -------------------------------------------------------------------------

    /**
     * Cold start. Dart has not registered its method-call handler yet, so the
     * payload is stashed for `getInitialNotification` to collect.
     */
    fun captureInitialIntent(intent: Intent?) {
        val payloadJson = intent?.getStringExtra(PushNotifications.EXTRA_PAYLOAD_JSON) ?: return
        initialPayload = PushNotifications.toDartMap(
            payloadJson,
            intent.getStringExtra(PushNotifications.EXTRA_ACTION),
        )
    }

    /** Warm tap, while the engine and Dart handler are already live. */
    fun dispatchTap(intent: Intent?) {
        val payloadJson = intent?.getStringExtra(PushNotifications.EXTRA_PAYLOAD_JSON) ?: return
        val payload = PushNotifications.toDartMap(
            payloadJson,
            intent.getStringExtra(PushNotifications.EXTRA_ACTION),
        ) ?: return

        val channel = methodChannel
        if (channel == null) {
            initialPayload = payload
        } else {
            channel.invokeMethod("onNotificationClicked", payload)
        }
    }

    // -------------------------------------------------------------------------
    // Argument coercion
    // -------------------------------------------------------------------------

    private fun toAnyMap(value: Any?): Map<String, Any?> =
        (value as? Map<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value }
            ?: emptyMap()

    private fun toActions(value: Any?): List<Pair<String, String>> {
        val list = value as? List<*> ?: return emptyList()
        return list.mapNotNull { entry ->
            val map = entry as? Map<*, *> ?: return@mapNotNull null
            val action = map["action"]?.toString()?.takeIf { it.isNotEmpty() }
                ?: return@mapNotNull null
            action to (map["title"]?.toString() ?: action)
        }
    }
}
