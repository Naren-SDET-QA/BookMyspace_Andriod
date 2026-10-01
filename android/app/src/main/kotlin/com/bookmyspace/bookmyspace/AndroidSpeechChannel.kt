package com.bookmyspace.bookmyspace

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Android counterpart of the iOS `speech_recognition` channel.
 *
 * Exposes the same method names and argument shapes as `AppDelegate.swift`
 * so [SpeechRecognitionService] can drive both platforms through one code
 * path: `isAvailable`, `requestPermission`, `startListening`,
 * `stopListening`, `cancelListening`, plus the `onSpeechResult` /
 * `onSpeechError` / `onSpeechEnd` events.
 *
 * Backed by the platform `SpeechRecognizer` (RecognizerIntent), so it needs
 * no third-party dependency. Runtime `RECORD_AUDIO` permission is requested
 * through the activity like the push channel does.
 */
class AndroidSpeechChannel(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) {
    companion object {
        const val CHANNEL_NAME = "com.bookmyspace.bookmyspace/speech_recognition"

        private const val REQUEST_CODE_RECORD_AUDIO = 0x5A11
    }

    private var methodChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    /** Whether this device actually ships a speech recognition service. */
    private val recognitionAvailable: Boolean
        get() = SpeechRecognizer.isRecognitionAvailable(context)

    private fun recordAudioGranted(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun attach(messenger: BinaryMessenger) {
        methodChannel = MethodChannel(messenger, CHANNEL_NAME).also { channel ->
            channel.setMethodCallHandler(::onMethodCall)
        }
    }

    // -------------------------------------------------------------------------
    // MethodChannel dispatch
    // -------------------------------------------------------------------------

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(
                mapOf(
                    "isAvailable" to recognitionAvailable,
                    "isAuthorized" to recordAudioGranted(),
                ),
            )

            "requestPermission" -> requestPermission(result)

            "startListening" -> startListening(call, result)

            "stopListening" -> {
                stopListening()
                result.success(true)
            }

            "cancelListening" -> {
                cancelListening()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Permission
    // -------------------------------------------------------------------------

    private fun requestPermission(result: MethodChannel.Result) {
        if (recordAudioGranted()) {
            result.success(mapOf("granted" to true))
            return
        }

        // RECORD_AUDIO is install-time below API 23, so an ungranted state can
        // only come from a refusal the user can reverse in settings.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(mapOf("granted" to false))
            return
        }

        val activity = activityProvider()
        if (activity == null || pendingPermissionResult != null) {
            result.success(mapOf("granted" to recordAudioGranted()))
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_CODE_RECORD_AUDIO,
        )
    }

    /** Forwarded from `MainActivity.onRequestPermissionsResult`. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE_RECORD_AUDIO) return
        val pending = pendingPermissionResult ?: return
        pendingPermissionResult = null

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending.success(mapOf("granted" to granted))
    }

    // -------------------------------------------------------------------------
    // Recognition
    // -------------------------------------------------------------------------

    private fun startListening(call: MethodCall, result: MethodChannel.Result) {
        if (!recognitionAvailable) {
            result.error(
                "UNAVAILABLE",
                "Speech recognition is not available on this device",
                null,
            )
            return
        }
        if (!recordAudioGranted()) {
            result.error(
                "PERMISSION_DENIED",
                "Permission denied: RECORD_AUDIO has not been granted",
                null,
            )
            return
        }

        val language = call.argument<String>("language") ?: "en-IN"
        val locale = Locale.forLanguageTag(language)

        cancelListening()

        val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        speechRecognizer = recognizer
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}

            override fun onBeginningOfSpeech() {}

            override fun onRmsChanged(rmsdB: Float) {}

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                methodChannel?.invokeMethod(
                    "onSpeechError",
                    mapOf("error" to describeError(error)),
                )
            }

            override fun onResults(results: Bundle?) {
                val transcript = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull().orEmpty()
                val channel = methodChannel
                channel?.invokeMethod(
                    "onSpeechResult",
                    mapOf("transcript" to transcript, "isFinal" to true),
                )
                channel?.invokeMethod("onSpeechEnd", null)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val transcript = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: return
                methodChannel?.invokeMethod(
                    "onSpeechResult",
                    mapOf("transcript" to transcript, "isFinal" to false),
                )
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        }

        recognizer.startListening(intent)
        result.success(true)
    }

    private fun stopListening() {
        speechRecognizer?.stopListening()
    }

    private fun cancelListening() {
        speechRecognizer?.let { recognizer ->
            recognizer.cancel()
            recognizer.destroy()
        }
        speechRecognizer = null
    }

    private fun describeError(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO ->
            "Audio recording error"
        SpeechRecognizer.ERROR_CLIENT -> "Speech recognition client error"
        SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT ->
            "Speech recognition support cannot be verified on this device"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
            "Permission denied: RECORD_AUDIO has not been granted"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ->
            "Speech recognition language not supported"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
            "Speech recognition language unavailable"
        SpeechRecognizer.ERROR_NETWORK -> "Speech recognition network error"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT ->
            "Speech recognition network timeout"
        SpeechRecognizer.ERROR_NO_MATCH ->
            "No speech match recognized, please try again"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
            "Speech recognizer is busy, please try again"
        SpeechRecognizer.ERROR_SERVER -> "Speech recognition server error"
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED ->
            "Speech recognition server disconnected"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
            "No speech heard, please try again"
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS ->
            "Too many speech recognition requests"
        else -> "Speech recognition error $error"
    }
}
