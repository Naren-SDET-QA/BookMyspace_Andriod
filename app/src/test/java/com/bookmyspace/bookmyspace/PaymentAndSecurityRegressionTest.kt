package com.bookmyspace.bookmyspace

import com.bookmyspace.bookmyspace.data.payment.PaymentSignatureValidator
import com.bookmyspace.bookmyspace.data.payment.SignatureValidationResult
import com.bookmyspace.bookmyspace.data.payment.WebhookValidationResult
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PaymentAndSecurityRegressionTest {

    private val testSecret = "test_rzp_secret_998877"

    @Test
    fun testHmacSha256CalculationConsistency() {
        val payload = "order_999|pay_888"
        val signature1 = PaymentSignatureValidator.calculateHmacSha256(payload, testSecret)
        val signature2 = PaymentSignatureValidator.calculateHmacSha256(payload, testSecret)

        assertNotNull(signature1)
        assertTrue(signature1.isNotBlank())
        assertEquals("HMAC-SHA256 calculation must be deterministic", signature1, signature2)
    }

    @Test
    fun testConstantTimeComparisonTimingAttackProtection() {
        val s1 = "a1b2c3d4e5f6"
        val s2 = "a1b2c3d4e5f6"
        val s3 = "a1b2c3d4e5f7"

        assertTrue(PaymentSignatureValidator.constantTimeEquals(s1, s2))
        assertFalse(PaymentSignatureValidator.constantTimeEquals(s1, s3))
        assertFalse(PaymentSignatureValidator.constantTimeEquals(s1, null))
        assertFalse(PaymentSignatureValidator.constantTimeEquals(null, s2))
    }

    @Test
    fun testRazorpayCheckoutSignatureVerification() {
        val orderId = "order_EK98127319"
        val paymentId = "pay_AB12893712"
        
        // Generate valid signature
        val validSig = PaymentSignatureValidator.generateCheckoutSignature(orderId, paymentId, testSecret)
        
        // Verify valid
        val validResult = PaymentSignatureValidator.verifyCheckoutSignature(orderId, paymentId, validSig, testSecret)
        assertTrue("Valid signature must pass cryptographic verification", validResult is SignatureValidationResult.Valid)
        assertTrue("SignatureValidationResult.Valid must be verified", (validResult as SignatureValidationResult.Valid).isVerified)

        // Verify invalid
        val invalidResult = PaymentSignatureValidator.verifyCheckoutSignature(orderId, paymentId, "tampered_signature_xyz", testSecret)
        assertTrue("Tampered signature must be rejected", invalidResult is SignatureValidationResult.Invalid)
    }

    @Test
    fun testWebhookSignatureVerification() {
        val webhookPayload = """{"event": "payment.captured", "payload": {"payment": {"entity": {"id": "pay_test_101", "amount": 150000}}}}"""
        val webhookSecret = "whsec_test_secret_123"

        val generatedSig = PaymentSignatureValidator.generateWebhookSignature(webhookPayload, webhookSecret)
        assertTrue(generatedSig.isNotBlank())

        val webhookResult = PaymentSignatureValidator.verifyAndParseWebhook(webhookPayload, generatedSig, webhookSecret)
        assertTrue("Webhook payload with valid signature must verify successfully", webhookResult is WebhookValidationResult.Success)
        val success = webhookResult as WebhookValidationResult.Success
        assertTrue(success.isVerified)
        assertEquals("pay_test_101", success.paymentId)
        assertEquals(1500.0, success.amount, 0.01)

        val mismatchResult = PaymentSignatureValidator.verifyAndParseWebhook(webhookPayload, generatedSig, "different_secret")
        assertTrue("Webhook with mismatched secret must fail verification", mismatchResult is WebhookValidationResult.SignatureMismatch)
    }
}
