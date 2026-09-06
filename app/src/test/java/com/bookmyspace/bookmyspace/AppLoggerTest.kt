package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.util.AppLogger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AppLoggerTest {

    @Test
    fun testSanitizeTokensAndSecrets() {
        val testInput = "Payment failed with apiKey: secret_api_key_998811 and token: token_sample_abc123"
        val sanitized = AppLogger.sanitize(testInput, forceSanitize = true)
        assertFalse(sanitized.contains("secret_api_key_998811"))
        assertTrue(sanitized.contains("[REDACTED_TOKEN]"))
    }

    @Test
    fun testSanitizeEmailAndPhone() {
        val testInput = "Contact user at john.doe@example.com or phone +1-555-123-4567"
        val sanitized = AppLogger.sanitize(testInput, forceSanitize = true)
        assertFalse(sanitized.contains("john.doe@example.com"))
        assertTrue(sanitized.contains("[REDACTED_EMAIL]"))
        assertFalse(sanitized.contains("+1-555-123-4567"))
        assertTrue(sanitized.contains("[REDACTED_PHONE]"))
    }

    @Test
    fun testLogMethodsExecution() {
        // Verify logging methods handle tags and messages cleanly
        AppLogger.v("TestTag", "Verbose test message")
        AppLogger.d("TestTag", "Debug test message")
        AppLogger.i("TestTag", "Info test message")
        AppLogger.w("TestTag", "Warn test message")
        AppLogger.e("TestTag", "Error test message", RuntimeException("Sample error"))
    }
}
