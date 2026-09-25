package com.bookmyspace.bookmyspace.util

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

/**
 * State representation of the Voice Speech Recognition Engine.
 */
sealed class VoiceRecognitionState {
    object Idle : VoiceRecognitionState()
    object Initializing : VoiceRecognitionState()
    object ReadyToSpeak : VoiceRecognitionState()
    data class Listening(val partialText: String = "", val rmsLevel: Float = 0f) : VoiceRecognitionState()
    data class Success(val recognizedText: String, val alternatives: List<String> = emptyList()) : VoiceRecognitionState()
    data class Error(val message: String, val errorCode: Int = -1) : VoiceRecognitionState()
    object PermissionRequired : VoiceRecognitionState()
}

/**
 * High-performance, production-ready native Voice Recognition Engine
 * using Android's native SpeechRecognizer with live RMS audio level monitoring,
 * partial transcript streaming, and multi-language support.
 */
class VoiceRecognitionHelper(private val context: Context) {

    companion object {
        private const val TAG = "VoiceRecognitionHelper"

        fun isPermissionGranted(context: Context): Boolean {
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        }

        fun isRecognitionAvailable(context: Context): Boolean {
            return SpeechRecognizer.isRecognitionAvailable(context)
        }
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private val _state = MutableStateFlow<VoiceRecognitionState>(VoiceRecognitionState.Idle)
    val state: StateFlow<VoiceRecognitionState> = _state.asStateFlow()

    private val _rmsAudioLevel = MutableStateFlow(0f)
    val rmsAudioLevel: StateFlow<Float> = _rmsAudioLevel.asStateFlow()

    private var currentPartialText = ""

    init {
        initSpeechRecognizer()
    }

    private fun initSpeechRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.w(TAG, "SpeechRecognizer is not available on this device.")
            return
        }

        try {
            speechRecognizer?.destroy()
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(createRecognitionListener())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing SpeechRecognizer: ${e.message}", e)
        }
    }

    private fun createRecognitionListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.d(TAG, "onReadyForSpeech")
                _state.value = VoiceRecognitionState.ReadyToSpeak
            }

            override fun onBeginningOfSpeech() {
                Log.d(TAG, "onBeginningOfSpeech")
                currentPartialText = ""
                _state.value = VoiceRecognitionState.Listening(partialText = "", rmsLevel = 0f)
            }

            override fun onRmsChanged(rmsdB: Float) {
                // Normalize rmsdB (-2 to 10 dB typical range) to 0.0f..1.0f for UI visualizers
                val normalized = ((rmsdB + 2f) / 12f).coerceIn(0.05f, 1.0f)
                _rmsAudioLevel.value = normalized
                val currentState = _state.value
                if (currentState is VoiceRecognitionState.Listening) {
                    _state.value = currentState.copy(rmsLevel = normalized)
                }
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                Log.d(TAG, "onEndOfSpeech")
                _rmsAudioLevel.value = 0f
            }

            override fun onError(error: Int) {
                _rmsAudioLevel.value = 0f
                val errorMessage = when (error) {
                    SpeechRecognizer.ERROR_AUDIO -> "Audio recording error. Please check microphone."
                    SpeechRecognizer.ERROR_CLIENT -> "Client-side recognition error. Please try again."
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission required."
                    SpeechRecognizer.ERROR_NETWORK -> "Network error during voice search."
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout. Please check your internet connection."
                    SpeechRecognizer.ERROR_NO_MATCH -> "No speech recognized. Please speak closer to the mic."
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Voice recognizer is busy. Resetting..."
                    SpeechRecognizer.ERROR_SERVER -> "Voice server error. Please try again."
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech detected. Tap microphone to speak."
                    else -> "Speech recognition error ($error). Please try again."
                }
                Log.w(TAG, "Recognition error: $errorMessage ($error)")

                if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                    _state.value = VoiceRecognitionState.PermissionRequired
                } else if (error == SpeechRecognizer.ERROR_NO_MATCH && currentPartialText.isNotBlank()) {
                    // Fallback to partial text if available
                    _state.value = VoiceRecognitionState.Success(currentPartialText)
                } else {
                    _state.value = VoiceRecognitionState.Error(errorMessage, error)
                }
            }

            override fun onResults(results: Bundle?) {
                _rmsAudioLevel.value = 0f
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    val primaryMatch = matches[0]
                    Log.d(TAG, "onResults recognized: '$primaryMatch'")
                    _state.value = VoiceRecognitionState.Success(
                        recognizedText = primaryMatch,
                        alternatives = matches.drop(1)
                    )
                } else if (currentPartialText.isNotBlank()) {
                    _state.value = VoiceRecognitionState.Success(currentPartialText)
                } else {
                    _state.value = VoiceRecognitionState.Error("No matching speech detected.")
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    val text = matches[0]
                    currentPartialText = text
                    _state.value = VoiceRecognitionState.Listening(partialText = text, rmsLevel = _rmsAudioLevel.value)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    /**
     * Start listening to live microphone audio.
     */
    fun startListening(
        preferredLanguage: String? = null,
        prompt: String = "Speak venue name, type, budget or amenities..."
    ) {
        if (!isPermissionGranted(context)) {
            _state.value = VoiceRecognitionState.PermissionRequired
            return
        }

        if (speechRecognizer == null) {
            initSpeechRecognizer()
        }

        _state.value = VoiceRecognitionState.Initializing
        currentPartialText = ""
        _rmsAudioLevel.value = 0f

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)

            val localeCode = preferredLanguage ?: LocalizedStrings.currentLanguage.value.code
            val speechLocale = when (localeCode) {
                "hi" -> "hi-IN"
                "te" -> "te-IN"
                "ta" -> "ta-IN"
                "kn" -> "kn-IN"
                "ml" -> "ml-IN"
                "mr" -> "mr-IN"
                "bn" -> "bn-IN"
                else -> Locale.getDefault().toLanguageTag()
            }
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, speechLocale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, speechLocale)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        }

        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start SpeechRecognizer: ${e.message}", e)
            _state.value = VoiceRecognitionState.Error("Failed to start microphone: ${e.localizedMessage}")
        }
    }

    /**
     * Stop listening and process audio buffer.
     */
    fun stopListening() {
        try {
            speechRecognizer?.stopListening()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping SpeechRecognizer: ${e.message}", e)
        }
        _rmsAudioLevel.value = 0f
    }

    /**
     * Cancel current speech session and return to Idle.
     */
    fun cancel() {
        try {
            speechRecognizer?.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Error canceling SpeechRecognizer: ${e.message}", e)
        }
        _rmsAudioLevel.value = 0f
        _state.value = VoiceRecognitionState.Idle
    }

    /**
     * Release all native microphone and SpeechRecognizer resources.
     */
    fun destroy() {
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error destroying SpeechRecognizer: ${e.message}", e)
        }
        _rmsAudioLevel.value = 0f
        _state.value = VoiceRecognitionState.Idle
    }
}
