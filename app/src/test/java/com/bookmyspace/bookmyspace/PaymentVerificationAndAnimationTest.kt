package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.payment.PaymentSignatureValidator
import com.bookmyspace.bookmyspace.data.payment.SignatureValidationResult
import com.bookmyspace.bookmyspace.data.payment.WebhookValidationResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PaymentVerificationAndAnimationTest {

    @Test
    fun testPaymentSignatureVerification_ValidSignatureMatches() {
        val orderId = "order_N123456789"
        val paymentId = "pay_P987654321"
        val secret = "test_secret_key_123"

        val generatedSignature = PaymentSignatureValidator.generateCheckoutSignature(orderId, paymentId, secret)
        assertNotNull("Signature should be generated", generatedSignature)
        assertTrue("Signature should not be empty", generatedSignature.isNotEmpty())

        val result = PaymentSignatureValidator.verifyCheckoutSignature(
            orderId = orderId,
            paymentId = paymentId,
            signature = generatedSignature,
            keySecret = secret
        )
        assertTrue("Signature verification should succeed for authentic payload", result is SignatureValidationResult.Valid)
        val valid = result as SignatureValidationResult.Valid
        assertEquals(paymentId, valid.paymentId)
        assertEquals(orderId, valid.orderId)
        assertTrue(valid.isVerified)
    }

    @Test
    fun testPaymentSignatureVerification_TamperedPayloadFails() {
        val orderId = "order_N123456789"
        val paymentId = "pay_P987654321"
        val secret = "test_secret_key_123"

        val validSignature = PaymentSignatureValidator.generateCheckoutSignature(orderId, paymentId, secret)

        // Tamper with order ID
        val tamperedOrderResult = PaymentSignatureValidator.verifyCheckoutSignature(
            orderId = "order_TAMPERED",
            paymentId = paymentId,
            signature = validSignature,
            keySecret = secret
        )
        assertTrue("Verification must fail on tampered order ID", tamperedOrderResult is SignatureValidationResult.Invalid)

        // Tamper with payment ID
        val tamperedPaymentResult = PaymentSignatureValidator.verifyCheckoutSignature(
            orderId = orderId,
            paymentId = "pay_TAMPERED",
            signature = validSignature,
            keySecret = secret
        )
        assertTrue("Verification must fail on tampered payment ID", tamperedPaymentResult is SignatureValidationResult.Invalid)

        // Wrong secret key
        val wrongSecretResult = PaymentSignatureValidator.verifyCheckoutSignature(
            orderId = orderId,
            paymentId = paymentId,
            signature = validSignature,
            keySecret = "wrong_secret"
        )
        assertTrue("Verification must fail on wrong secret key", wrongSecretResult is SignatureValidationResult.Invalid)
    }

    @Test
    fun testWebhookSignatureVerification_ValidWebhookPayload() {
        val rawWebhookJson = """
            {
                "event": "payment.captured",
                "payload": {
                    "payment": {
                        "entity": {
                            "id": "pay_TEST12345",
                            "order_id": "order_TEST67890",
                            "amount": 250000,
                            "currency": "INR",
                            "status": "captured",
                            "notes": {
                                "booking_id": "b_xyz999"
                            }
                        }
                    }
                }
            }
        """.trimIndent()
        val webhookSecret = "webhook_secret_secure_xyz"

        val generatedSignature = PaymentSignatureValidator.generateWebhookSignature(rawWebhookJson, webhookSecret)
        val webhookResult = PaymentSignatureValidator.verifyAndParseWebhook(
            rawPayload = rawWebhookJson,
            signatureHeader = generatedSignature,
            webhookSecret = webhookSecret
        )

        assertTrue("Valid webhook payload should succeed", webhookResult is WebhookValidationResult.Success)
        val success = webhookResult as WebhookValidationResult.Success
        assertEquals("payment.captured", success.eventType)
        assertEquals("pay_TEST12345", success.paymentId)
        assertEquals("order_TEST67890", success.orderId)
        assertEquals("b_xyz999", success.bookingId)
        assertEquals(2500.0, success.amount, 0.01)
        assertEquals("SUCCESS", success.status)
        assertTrue(success.isVerified)
    }

    @Test
    fun testWebhookSignatureVerification_TamperedWebhookPayloadFails() {
        val rawWebhookJson = """{"event":"payment.captured","payload":{}}"""
        val webhookSecret = "webhook_secret_secure_xyz"
        val invalidSignature = "invalid_tampered_signature_hex"

        val webhookResult = PaymentSignatureValidator.verifyAndParseWebhook(
            rawPayload = rawWebhookJson,
            signatureHeader = invalidSignature,
            webhookSecret = webhookSecret
        )

        assertTrue("Tampered webhook signature should mismatch", webhookResult is WebhookValidationResult.SignatureMismatch)
    }
}
