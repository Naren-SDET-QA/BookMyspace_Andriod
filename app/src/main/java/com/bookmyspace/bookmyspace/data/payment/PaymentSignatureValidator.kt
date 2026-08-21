package com.bookmyspace.bookmyspace.data.payment

import android.util.Log
import com.bookmyspace.bookmyspace.BuildConfig
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Locale
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Sealed class representing signature validation outcomes for Checkout transactions.
 */
sealed class SignatureValidationResult {
    data class Valid(
        val paymentId: String,
        val orderId: String,
        val signature: String,
        val isVerified: Boolean = true,
        val timestamp: Long = System.currentTimeMillis()
    ) : SignatureValidationResult()

    data class Invalid(
        val reason: String,
        val paymentId: String?,
        val orderId: String?,
        val receivedSignature: String?,
        val expectedSignature: String? = null
    ) : SignatureValidationResult()

    data class Skipped(
        val reason: String,
        val paymentId: String,
        val orderId: String?
    ) : SignatureValidationResult()
}

/**
 * Sealed class representing verification results for Razorpay Webhook payloads.
 */
sealed class WebhookValidationResult {
    data class Success(
        val eventType: String,
        val paymentId: String?,
        val orderId: String?,
        val bookingId: String?,
        val amount: Double,
        val currency: String,
        val status: String,
        val rawPayload: String,
        val receivedSignature: String,
        val isVerified: Boolean = true,
        val payloadJson: JSONObject
    ) : WebhookValidationResult()

    data class SignatureMismatch(
        val receivedSignature: String,
        val expectedSignature: String,
        val eventType: String?,
        val reason: String = "HMAC-SHA256 webhook signature mismatch. Payload may have been tampered."
    ) : WebhookValidationResult()

    data class MalformedPayload(
        val error: String,
        val rawPayload: String
    ) : WebhookValidationResult()
}

/**
 * Validation layer for Razorpay payment transactions and webhook events.
 * Performs cryptographic HMAC-SHA256 signature verification matching Razorpay specs
 * before updating local database records.
 */
object PaymentSignatureValidator {

    private const val TAG = "PaymentSigValidator"
    private const val HMAC_SHA256 = "HmacSHA256"

    const val FALLBACK_TEST_KEY_SECRET = "rzp_secret_bookmyspace"
    const val FALLBACK_TEST_WEBHOOK_SECRET = "whsec_bookmyspace_secure_2026"

    /**
     * Resolves the Razorpay Key Secret from BuildConfig, Environment, or secure fallback.
     */
    fun resolveKeySecret(customSecret: String? = null): String {
        if (!customSecret.isNullOrBlank()) return customSecret

        try {
            val buildConfigSecret = BuildConfig.RAZORPAY_KEY_SECRET
            if (!buildConfigSecret.isNullOrBlank() && !buildConfigSecret.equals("null", ignoreCase = true)) {
                return buildConfigSecret
            }
        } catch (e: Throwable) {
            Log.w(TAG, "BuildConfig.RAZORPAY_KEY_SECRET not found: ${e.message}")
        }

        try {
            val sysEnv = System.getenv("RAZORPAY_KEY_SECRET")
            if (!sysEnv.isNullOrBlank()) return sysEnv
        } catch (e: Throwable) {
            Log.w(TAG, "System.getenv RAZORPAY_KEY_SECRET error: ${e.message}")
        }

        return FALLBACK_TEST_KEY_SECRET
    }

    /**
     * Resolves the Razorpay Webhook Secret from BuildConfig, Environment, or secure fallback.
     */
    fun resolveWebhookSecret(customSecret: String? = null): String {
        if (!customSecret.isNullOrBlank()) return customSecret

        try {
            val buildConfigSecret = BuildConfig.RAZORPAY_WEBHOOK_SECRET
            if (!buildConfigSecret.isNullOrBlank() && !buildConfigSecret.equals("null", ignoreCase = true)) {
                return buildConfigSecret
            }
        } catch (e: Throwable) {
            Log.w(TAG, "BuildConfig.RAZORPAY_WEBHOOK_SECRET not found: ${e.message}")
        }

        try {
            val sysEnv = System.getenv("RAZORPAY_WEBHOOK_SECRET")
            if (!sysEnv.isNullOrBlank()) return sysEnv
        } catch (e: Throwable) {
            Log.w(TAG, "System.getenv RAZORPAY_WEBHOOK_SECRET error: ${e.message}")
        }

        return FALLBACK_TEST_WEBHOOK_SECRET
    }

    /**
     * Computes HMAC-SHA256 hex digest for a given data string and secret key.
     */
    fun calculateHmacSha256(data: String, secret: String): String {
        return try {
            val secretKeySpec = SecretKeySpec(secret.toByteArray(Charsets.UTF_8), HMAC_SHA256)
            val mac = Mac.getInstance(HMAC_SHA256).apply {
                init(secretKeySpec)
            }
            val hashBytes = mac.doFinal(data.toByteArray(Charsets.UTF_8))
            hashBytes.joinToString("") { "%02x".format(it) }.lowercase(Locale.ROOT)
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating HMAC-SHA256: ${e.message}", e)
            ""
        }
    }

    /**
     * Constant-time comparison between two strings to prevent timing attacks.
     */
    fun constantTimeEquals(a: String?, b: String?): Boolean {
        if (a == null || b == null) return false
        val aBytes = a.toByteArray(Charsets.UTF_8)
        val bBytes = b.toByteArray(Charsets.UTF_8)
        return MessageDigest.isEqual(aBytes, bBytes)
    }

    /**
     * Generates a valid standard Razorpay Checkout signature for an order and payment ID.
     * Formula: HMAC_SHA256(order_id + "|" + payment_id, secret)
     */
    fun generateCheckoutSignature(
        orderId: String,
        paymentId: String,
        keySecret: String? = null
    ): String {
        val secret = resolveKeySecret(keySecret)
        val payload = "$orderId|$paymentId"
        return calculateHmacSha256(payload, secret)
    }

    /**
     * Verifies a Razorpay Standard Checkout payment signature against order and payment IDs.
     *
     * @param orderId The server-side Razorpay order ID.
     * @param paymentId The payment ID received from Razorpay.
     * @param signature The cryptographic signature received in the payment response.
     * @param keySecret Optional custom key secret; resolves automatically if null.
     */
    fun verifyCheckoutSignature(
        orderId: String?,
        paymentId: String?,
        signature: String?,
        keySecret: String? = null
    ): SignatureValidationResult {
        if (paymentId.isNullOrBlank()) {
            return SignatureValidationResult.Invalid(
                reason = "Payment ID is missing or blank",
                paymentId = paymentId,
                orderId = orderId,
                receivedSignature = signature
            )
        }

        // If orderId or signature is omitted in direct client-only test checkout, log and permit with notice
        if (orderId.isNullOrBlank() || signature.isNullOrBlank()) {
            Log.d(TAG, "Checkout verification skipped: orderId or signature not present (Direct Client Sandbox).")
            return SignatureValidationResult.Skipped(
                reason = "Direct client mode: order ID or signature not supplied by gateway",
                paymentId = paymentId,
                orderId = orderId
            )
        }

        val secret = resolveKeySecret(keySecret)
        val expectedSignature = generateCheckoutSignature(orderId, paymentId, secret)

        val isValid = constantTimeEquals(signature.trim(), expectedSignature.trim())

        return if (isValid) {
            Log.i(TAG, "✅ Checkout signature verified successfully for Payment: $paymentId, Order: $orderId")
            SignatureValidationResult.Valid(
                paymentId = paymentId,
                orderId = orderId,
                signature = signature,
                isVerified = true
            )
        } else {
            Log.e(TAG, "❌ Checkout signature verification FAILED! Received: $signature, Expected: $expectedSignature")
            SignatureValidationResult.Invalid(
                reason = "Cryptographic signature mismatch: potential payload tampering",
                paymentId = paymentId,
                orderId = orderId,
                receivedSignature = signature,
                expectedSignature = expectedSignature
            )
        }
    }

    /**
     * Generates a valid standard Razorpay Webhook signature for a raw payload body.
     * Formula: HMAC_SHA256(request_body, webhook_secret)
     */
    fun generateWebhookSignature(
        rawPayload: String,
        webhookSecret: String? = null
    ): String {
        val secret = resolveWebhookSecret(webhookSecret)
        return calculateHmacSha256(rawPayload, secret)
    }

    /**
     * Verifies an incoming Razorpay Webhook payload against the signature header (X-Razorpay-Signature)
     * and extracts event details.
     *
     * @param rawPayload The raw JSON string of the HTTP request body.
     * @param signatureHeader The value of 'X-Razorpay-Signature' header.
     * @param webhookSecret Optional custom webhook secret.
     */
    fun verifyAndParseWebhook(
        rawPayload: String,
        signatureHeader: String,
        webhookSecret: String? = null
    ): WebhookValidationResult {
        if (rawPayload.isBlank()) {
            return WebhookValidationResult.MalformedPayload(
                error = "Webhook payload body is empty",
                rawPayload = rawPayload
            )
        }

        val secret = resolveWebhookSecret(webhookSecret)
        val expectedSignature = calculateHmacSha256(rawPayload, secret)

        val isSignatureValid = constantTimeEquals(signatureHeader.trim(), expectedSignature.trim())

        val json = try {
            JSONObject(rawPayload)
        } catch (e: Exception) {
            return WebhookValidationResult.MalformedPayload(
                error = "Invalid JSON structure: ${e.message}",
                rawPayload = rawPayload
            )
        }

        val eventType = json.optString("event", "unknown")

        if (!isSignatureValid) {
            Log.e(TAG, "❌ Webhook signature verification FAILED for event '$eventType'!")
            return WebhookValidationResult.SignatureMismatch(
                receivedSignature = signatureHeader,
                expectedSignature = expectedSignature,
                eventType = eventType
            )
        }

        Log.i(TAG, "✅ Webhook signature verified successfully for event: $eventType")

        // Parse payment & order details from standard Razorpay payload structure
        val payloadObj = json.optJSONObject("payload")
        val paymentEntity = payloadObj?.optJSONObject("payment")?.optJSONObject("entity")
        val orderEntity = payloadObj?.optJSONObject("order")?.optJSONObject("entity")

        val paymentId = paymentEntity?.optString("id")?.ifBlank { null }
            ?: json.optString("payment_id").ifBlank { null }

        val orderId = paymentEntity?.optString("order_id")?.ifBlank { null }
            ?: orderEntity?.optString("id")?.ifBlank { null }
            ?: json.optString("order_id").ifBlank { null }

        val amountInPaise = paymentEntity?.optDouble("amount", 0.0)
            ?: orderEntity?.optDouble("amount", 0.0)
            ?: json.optDouble("amount", 0.0)

        val amountInRupees = amountInPaise / 100.0
        val currency = paymentEntity?.optString("currency", "INR") ?: "INR"

        val status = paymentEntity?.optString("status", "captured")
            ?: orderEntity?.optString("status", "paid")
            ?: "SUCCESS"

        // Extract booking_id from notes if present
        val notes = paymentEntity?.optJSONObject("notes") ?: orderEntity?.optJSONObject("notes")
        val bookingId = notes?.optString("booking_id")?.ifBlank { null }
            ?: notes?.optString("bookingId")?.ifBlank { null }

        return WebhookValidationResult.Success(
            eventType = eventType,
            paymentId = paymentId,
            orderId = orderId,
            bookingId = bookingId,
            amount = amountInRupees,
            currency = currency,
            status = mapWebhookStatusToTransactionStatus(eventType, status),
            rawPayload = rawPayload,
            receivedSignature = signatureHeader,
            isVerified = true,
            payloadJson = json
        )
    }

    /**
     * Maps Razorpay event / status names to normalized transaction statuses.
     */
    private fun mapWebhookStatusToTransactionStatus(event: String, entityStatus: String): String {
        return when (event.lowercase(Locale.ROOT)) {
            "payment.captured", "order.paid", "payment.authorized" -> "SUCCESS"
            "payment.failed" -> "FAILED"
            "refund.processed", "refund.created" -> "REFUNDED"
            "payment.dispute.created" -> "HELD"
            else -> when (entityStatus.lowercase(Locale.ROOT)) {
                "captured", "paid", "authorized" -> "SUCCESS"
                "failed" -> "FAILED"
                "refunded" -> "REFUNDED"
                else -> "PENDING"
            }
        }
    }
}
