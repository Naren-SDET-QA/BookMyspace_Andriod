package com.bookmyspace.bookmyspace.util

import android.util.Log
import com.bookmyspace.bookmyspace.BuildConfig

/**
 * Centralized logging utility that prevents sensitive data leaks in production
 * while providing rich observability during development.
 *
 * Rules:
 * - VERBOSE (v) and DEBUG (d) are strictly suppressed in release builds (`BuildConfig.DEBUG == false`).
 * - INFO (i), WARN (w), and ERROR (e) logs are sanitized in production to scrub credentials, tokens,
 *   emails, phone numbers, and payment signatures.
 */
object AppLogger {

    private const val DEFAULT_TAG = "BookMySpace"
    private const val MAX_LOG_LENGTH = 4000

    // Sensitive data regex patterns for automatic redaction
    private val SENSITIVE_PATTERNS = listOf(
        // API Keys & Tokens
        Regex("(?i)(api[_-]?key|access[_-]?token|bearer|authorization|secret|password|client[_-]?secret)[\"':= ]+([a-zA-Z0-9_\\-\\.~+/]{6,})") to "$1: [REDACTED_TOKEN]",
        // Email addresses
        Regex("[a-zA-Z0-9+._%\\-]{1,256}@[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\.[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+") to "[REDACTED_EMAIL]",
        // Phone numbers (10+ digits with country codes)
        Regex("(\\+?\\d{1,3}[-.\\s]?)?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}") to "[REDACTED_PHONE]",
        // Credit / Debit card patterns (13-19 digits)
        Regex("\\b(?:\\d[ -]*?){13,19}\\b") to "[REDACTED_CARD]"
    )

    /**
     * Verbose log - only printed in debug builds
     */
    @JvmStatic
    fun v(tag: String = DEFAULT_TAG, message: String, throwable: Throwable? = null) {
        if (BuildConfig.DEBUG) {
            logChunks(Log.VERBOSE, tag, message, throwable)
        }
    }

    /**
     * Debug log - only printed in debug builds
     */
    @JvmStatic
    fun d(tag: String = DEFAULT_TAG, message: String, throwable: Throwable? = null) {
        if (BuildConfig.DEBUG) {
            logChunks(Log.DEBUG, tag, message, throwable)
        }
    }

    /**
     * Info log - printed in all builds; sanitized in production
     */
    @JvmStatic
    fun i(tag: String = DEFAULT_TAG, message: String, throwable: Throwable? = null) {
        val sanitized = sanitize(message)
        logChunks(Log.INFO, tag, sanitized, throwable)
    }

    /**
     * Warning log - printed in all builds; sanitized in production
     */
    @JvmStatic
    fun w(tag: String = DEFAULT_TAG, message: String, throwable: Throwable? = null) {
        val sanitized = sanitize(message)
        try {
            if (throwable != null) {
                Log.w(tag, sanitized, throwable)
            } else {
                Log.w(tag, sanitized)
            }
        } catch (_: Exception) {
            // Fallback for unmocked JVM environments
        }
    }

    /**
     * Error log - printed in all builds; sanitized in production
     */
    @JvmStatic
    fun e(tag: String = DEFAULT_TAG, message: String, throwable: Throwable? = null) {
        val sanitized = sanitize(message)
        try {
            if (throwable != null) {
                Log.e(tag, sanitized, throwable)
            } else {
                Log.e(tag, sanitized)
            }
        } catch (_: Exception) {
            // Fallback for unmocked JVM environments
        }
    }

    /**
     * Redacts PII and authentication credentials when not in debug mode
     */
    fun sanitize(input: String, forceSanitize: Boolean = false): String {
        if (BuildConfig.DEBUG && !forceSanitize) {
            return input
        }
        var result = input
        for ((regex, replacement) in SENSITIVE_PATTERNS) {
            result = regex.replace(result, replacement)
        }
        return result
    }

    /**
     * Handles Android Logcat 4000 character limit by chunking long messages
     */
    private fun logChunks(priority: Int, tag: String, message: String, throwable: Throwable?) {
        try {
            if (message.length <= MAX_LOG_LENGTH) {
                when (priority) {
                    Log.VERBOSE -> Log.v(tag, message, throwable)
                    Log.DEBUG -> Log.d(tag, message, throwable)
                    Log.INFO -> Log.i(tag, message, throwable)
                    Log.WARN -> Log.w(tag, message, throwable)
                    Log.ERROR -> Log.e(tag, message, throwable)
                }
                return
            }

            var i = 0
            val length = message.length
            while (i < length) {
                var newline = message.indexOf('\n', i)
                newline = if (newline != -1) newline else length
                do {
                    val end = minOf(newline, i + MAX_LOG_LENGTH)
                    val part = message.substring(i, end)
                    when (priority) {
                        Log.VERBOSE -> Log.v(tag, part)
                        Log.DEBUG -> Log.d(tag, part)
                        Log.INFO -> Log.i(tag, part)
                        Log.WARN -> Log.w(tag, part)
                        Log.ERROR -> Log.e(tag, part)
                    }
                    i = end
                } while (i < newline)
                i++
            }
            if (throwable != null) {
                when (priority) {
                    Log.VERBOSE -> Log.v(tag, "Stacktrace: ", throwable)
                    Log.DEBUG -> Log.d(tag, "Stacktrace: ", throwable)
                    Log.INFO -> Log.i(tag, "Stacktrace: ", throwable)
                    Log.WARN -> Log.w(tag, "Stacktrace: ", throwable)
                    Log.ERROR -> Log.e(tag, "Stacktrace: ", throwable)
                }
            }
        } catch (_: Exception) {
            // Fallback for unmocked JVM environments
        }
    }
}
