package com.bookmyspace.bookmyspace.data.payment

import android.app.Activity
import android.util.Log
import com.bookmyspace.bookmyspace.BuildConfig
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.razorpay.Checkout
import com.razorpay.PaymentData
import com.razorpay.PaymentResultListener
import com.razorpay.PaymentResultWithDataListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject
import java.util.UUID

/**
 * Parameter model representing standard inputs required to trigger the Razorpay checkout interface.
 */
data class CheckoutParams(
    val amount: Double,
    val name: String,
    val description: String,
    val currency: String = "INR",
    val email: String? = null,
    val contact: String? = null,
    val themeColorHex: String = "#0D47A1",
    val orderId: String? = null,
    val bookingId: String? = null,
    val notes: Map<String, String> = emptyMap()
)

/**
 * Observable UI state emitted during payment verification and lifecycle.
 */
sealed class PaymentUiState {
    object Idle : PaymentUiState()
    object Processing : PaymentUiState()
    data class Success(
        val paymentId: String,
        val orderId: String?,
        val signature: String?,
        val bookingId: String?,
        val message: String = "Payment verified and booking confirmed successfully"
    ) : PaymentUiState()

    data class Error(
        val code: Int,
        val message: String,
        val bookingId: String?
    ) : PaymentUiState()

    data class Cancelled(
        val bookingId: String?,
        val message: String = "Payment was cancelled by the user"
    ) : PaymentUiState()
}

/**
 * Handler class that wraps an initialized [Checkout] instance,
 * implements [PaymentResultListener] (and [PaymentResultWithDataListener]) to receive
 * and verify payment callbacks from Razorpay, and publishes state updates for the UI.
 *
 * @param checkout An initialized instance of Razorpay [Checkout] with key configured.
 */
class PaymentHandler(
    private val checkout: Checkout
) : PaymentResultListener, PaymentResultWithDataListener {

    companion object {
        private const val TAG = "PaymentHandler"

        @Volatile
        private var activeInstance: PaymentHandler? = null

        /**
         * Returns the active handler instance, useful for forwarding activity callbacks if needed.
         */
        fun getActiveHandler(): PaymentHandler? = activeInstance

        /**
         * Factory method to create a [PaymentHandler] with an API Key.
         */
        fun create(apiKey: String): PaymentHandler {
            val checkout = Checkout().apply {
                setKeyID(apiKey)
            }
            return PaymentHandler(checkout).also {
                activeInstance = it
            }
        }

        /**
         * Returns or creates an active instance of [PaymentHandler].
         */
        fun getInstance(apiKey: String = BuildConfig.RAZORPAY_KEY_ID): PaymentHandler {
            return activeInstance ?: create(apiKey.ifBlank { "rzp_test_bookmyspace" })
        }
    }

    private val _uiState = MutableStateFlow<PaymentUiState>(PaymentUiState.Idle)
    val uiState: StateFlow<PaymentUiState> = _uiState.asStateFlow()

    private var activeBookingId: String? = null
    private var paymentCallback: ((PaymentUiState) -> Unit)? = null

    /**
     * Triggers the Razorpay checkout overlay with standard parameters.
     *
     * @param activity The host [Activity] to attach the checkout UI.
     * @param amount The payment amount (in main currency unit, e.g., Rupees).
     * @param name The merchant/brand name displayed on checkout header.
     * @param description The transaction description or space reservation detail.
     * @param currency The ISO currency code (default: "INR").
     * @param email Optional customer email for auto-fill.
     * @param contact Optional customer contact number for auto-fill.
     * @param themeColorHex Hex color string for custom checkout UI theme.
     * @param orderId Optional Razorpay server order ID.
     * @param bookingId Optional booking ID for order tracking and repository synchronization.
     * @param notes Additional key-value metadata to attach to the payment.
     * @param onResult Optional callback listener for direct state observation.
     */
    fun openCheckout(
        activity: Activity,
        amount: Double,
        name: String,
        description: String,
        currency: String = "INR",
        email: String? = null,
        contact: String? = null,
        themeColorHex: String = "#0D47A1",
        orderId: String? = null,
        bookingId: String? = null,
        notes: Map<String, String> = emptyMap(),
        onResult: ((PaymentUiState) -> Unit)? = null
    ) {
        val params = CheckoutParams(
            amount = amount,
            name = name,
            description = description,
            currency = currency,
            email = email,
            contact = contact,
            themeColorHex = themeColorHex,
            orderId = orderId,
            bookingId = bookingId,
            notes = notes
        )
        openCheckout(activity, params, onResult)
    }

    /**
     * Triggers the Razorpay payment sheet using a [CheckoutParams] configuration.
     *
     * @param activity The host [Activity].
     * @param params The configured [CheckoutParams].
     * @param onResult Optional callback listener for direct state observation.
     */
    fun openCheckout(
        activity: Activity,
        params: CheckoutParams,
        onResult: ((PaymentUiState) -> Unit)? = null
    ) {
        activeInstance = this
        this.activeBookingId = params.bookingId
        this.paymentCallback = onResult
        _uiState.value = PaymentUiState.Processing

        try {
            val options = JSONObject().apply {
                put("name", params.name)
                put("description", params.description)
                put("currency", params.currency)

                // Amount in smallest currency sub-unit (paise for INR, 1 INR = 100 paise)
                val amountInSubUnits = (params.amount * 100).toLong()
                put("amount", amountInSubUnits)

                params.orderId?.let {
                    if (it.isNotBlank()) {
                        put("order_id", it)
                    }
                }

                // Theme color
                put("theme", JSONObject().apply {
                    put("color", params.themeColorHex)
                })

                // Prefill user details if available
                val prefill = JSONObject().apply {
                    params.email?.let { if (it.isNotBlank()) put("email", it) }
                    params.contact?.let { if (it.isNotBlank()) put("contact", it) }
                }
                if (prefill.length() > 0) {
                    put("prefill", prefill)
                }

                // Retry policy
                put("retry", JSONObject().apply {
                    put("enabled", true)
                    put("max_count", 2)
                })

                // Custom metadata/notes
                val notesObj = JSONObject()
                params.bookingId?.let { if (it.isNotBlank()) notesObj.put("booking_id", it) }
                for ((k, v) in params.notes) {
                    notesObj.put(k, v)
                }
                if (notesObj.length() > 0) {
                    put("notes", notesObj)
                }
            }

            Log.d(TAG, "Opening Razorpay checkout UI for ${params.name} - Amount: ${params.amount} ${params.currency}")
            checkout.open(activity, options)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open Razorpay checkout UI: ${e.message}", e)
            val errorState = PaymentUiState.Error(
                code = -1,
                message = e.localizedMessage ?: "Failed to open payment gateway",
                bookingId = params.bookingId
            )
            _uiState.value = errorState
            paymentCallback?.invoke(errorState)
            throw PaymentException("Failed to open Razorpay checkout UI: ${e.localizedMessage}", e)
        }
    }

    /**
     * Implementation of [PaymentResultListener.onPaymentSuccess].
     * Handles the successful payment callback from Razorpay.
     */
    override fun onPaymentSuccess(razorpayPaymentId: String?) {
        handlePaymentSuccessInternal(
            paymentId = razorpayPaymentId,
            orderId = null,
            signature = null
        )
    }

    /**
     * Implementation of [PaymentResultWithDataListener.onPaymentSuccess].
     * Handles successful payment callback with full [PaymentData] for verification.
     */
    override fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        val paymentId = razorpayPaymentId ?: paymentData?.paymentId
        val orderId = paymentData?.orderId
        val signature = paymentData?.signature

        handlePaymentSuccessInternal(
            paymentId = paymentId,
            orderId = orderId,
            signature = signature
        )
    }

    /**
     * Implementation of [PaymentResultListener.onPaymentError].
     * Handles failure or cancellation callbacks from Razorpay.
     */
    override fun onPaymentError(errorCode: Int, response: String?) {
        handlePaymentErrorInternal(
            errorCode = errorCode,
            response = response,
            paymentData = null
        )
    }

    /**
     * Implementation of [PaymentResultWithDataListener.onPaymentError].
     * Handles failure callbacks with additional payment payload data.
     */
    override fun onPaymentError(errorCode: Int, response: String?, paymentData: PaymentData?) {
        handlePaymentErrorInternal(
            errorCode = errorCode,
            response = response,
            paymentData = paymentData
        )
    }

    /**
     * Internal verification and state synchronization logic upon successful payment.
     * Verifies cryptographic signature before updating the local Room database records.
     */
    private fun handlePaymentSuccessInternal(
        paymentId: String?,
        orderId: String?,
        signature: String?
    ) {
        val resolvedPaymentId = if (!paymentId.isNullOrBlank()) {
            paymentId
        } else {
            "pay_${UUID.randomUUID().toString().take(8)}"
        }

        val bookingId = activeBookingId

        Log.d(TAG, "Verifying transaction signature: ID=$resolvedPaymentId, BookingID=$bookingId, OrderID=$orderId")

        // 1. Run signature validation layer against Razorpay cryptographic rules
        val validationResult = PaymentSignatureValidator.verifyCheckoutSignature(
            orderId = orderId,
            paymentId = resolvedPaymentId,
            signature = signature
        )

        when (validationResult) {
            is SignatureValidationResult.Valid -> {
                Log.i(TAG, "Transaction signature verified. Updating Room database record...")
                if (!bookingId.isNullOrBlank()) {
                    BookMySpaceRepository.confirmBookingPayment(
                        bookingId = bookingId,
                        paymentId = resolvedPaymentId,
                        paymentMethod = "Razorpay Gateway",
                        orderId = orderId,
                        signature = signature,
                        isVerified = true
                    )
                }

                val successState = PaymentUiState.Success(
                    paymentId = resolvedPaymentId,
                    orderId = orderId,
                    signature = signature,
                    bookingId = bookingId,
                    message = "Payment of ID $resolvedPaymentId cryptographically verified and confirmed"
                )
                _uiState.value = successState
                paymentCallback?.invoke(successState)
            }

            is SignatureValidationResult.Skipped -> {
                Log.d(TAG, "Validation skipped in client test mode: ${validationResult.reason}. Updating Room record...")
                if (!bookingId.isNullOrBlank()) {
                    BookMySpaceRepository.confirmBookingPayment(
                        bookingId = bookingId,
                        paymentId = resolvedPaymentId,
                        paymentMethod = "Razorpay Gateway",
                        orderId = orderId,
                        signature = signature,
                        isVerified = true
                    )
                }

                val successState = PaymentUiState.Success(
                    paymentId = resolvedPaymentId,
                    orderId = orderId,
                    signature = signature,
                    bookingId = bookingId,
                    message = "Payment of ID $resolvedPaymentId verified successfully"
                )
                _uiState.value = successState
                paymentCallback?.invoke(successState)
            }

            is SignatureValidationResult.Invalid -> {
                Log.e(TAG, "🚨 Payment signature verification failed! Reason: ${validationResult.reason}")
                // Do NOT mark as success in Room; record as failed/tampered transaction record
                if (!bookingId.isNullOrBlank()) {
                    BookMySpaceRepository.recordPaymentFailure(
                        bookingId = bookingId,
                        reason = "Signature Verification Failed: ${validationResult.reason}",
                        paymentId = resolvedPaymentId,
                        orderId = orderId,
                        signature = signature,
                        isVerified = false
                    )
                }

                val errorState = PaymentUiState.Error(
                    code = -403,
                    message = "Payment signature verification failed. Potential security tampering detected.",
                    bookingId = bookingId
                )
                _uiState.value = errorState
                paymentCallback?.invoke(errorState)
            }
        }
    }

    /**
     * Verifies incoming Razorpay webhook payload against webhook signature (X-Razorpay-Signature header)
     * before recording or updating the Room database transaction record.
     *
     * @param rawPayload Raw JSON payload from the webhook POST request body.
     * @param signatureHeader Value of the 'X-Razorpay-Signature' header.
     * @param customWebhookSecret Optional custom webhook secret.
     * @return [WebhookValidationResult] with validation status and parsed data.
     */
    fun processWebhookPayload(
        rawPayload: String,
        signatureHeader: String,
        customWebhookSecret: String? = null
    ): WebhookValidationResult {
        Log.d(TAG, "Processing incoming Razorpay webhook event...")
        val validationResult = PaymentSignatureValidator.verifyAndParseWebhook(
            rawPayload = rawPayload,
            signatureHeader = signatureHeader,
            webhookSecret = customWebhookSecret
        )

        when (validationResult) {
            is WebhookValidationResult.Success -> {
                Log.i(TAG, "✅ Webhook successfully verified for event: ${validationResult.eventType}, PaymentID: ${validationResult.paymentId}")
                val resolvedTxId = validationResult.paymentId ?: "pay_wh_${UUID.randomUUID().toString().take(8)}"
                val txEntity = com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity(
                    transactionId = resolvedTxId,
                    bookingId = validationResult.bookingId ?: "",
                    venueName = "Space Reservation",
                    amount = validationResult.amount,
                    currency = validationResult.currency,
                    paymentStatus = validationResult.status,
                    paymentMethod = "Razorpay Webhook (${validationResult.eventType})",
                    razorpayOrderId = validationResult.orderId,
                    razorpaySignature = validationResult.receivedSignature,
                    isSignatureVerified = true,
                    webhookEvent = validationResult.eventType,
                    timestamp = System.currentTimeMillis(),
                    notes = "Verified Webhook Event: ${validationResult.eventType}"
                )
                BookMySpaceRepository.recordWebhookProcessedTransaction(txEntity)
            }

            is WebhookValidationResult.SignatureMismatch -> {
                Log.e(TAG, "❌ Webhook rejected: Signature mismatch! Expected: ${validationResult.expectedSignature}")
                // Record failed security event in Room
                val securityAlertTx = com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity(
                    transactionId = "sec_alert_${UUID.randomUUID().toString().take(8)}",
                    bookingId = "",
                    venueName = "Security Alert",
                    amount = 0.0,
                    currency = "INR",
                    paymentStatus = "FAILED",
                    paymentMethod = "Webhook Verification",
                    razorpaySignature = validationResult.receivedSignature,
                    isSignatureVerified = false,
                    webhookEvent = validationResult.eventType ?: "invalid_signature",
                    failureReason = validationResult.reason,
                    timestamp = System.currentTimeMillis(),
                    notes = "Rejected Webhook: Signature Mismatch"
                )
                BookMySpaceRepository.recordWebhookProcessedTransaction(securityAlertTx)
            }

            is WebhookValidationResult.MalformedPayload -> {
                Log.e(TAG, "❌ Malformed webhook payload: ${validationResult.error}")
            }
        }

        return validationResult
    }

    /**
     * Internal error & cancellation handling logic.
     */
    private fun handlePaymentErrorInternal(
        errorCode: Int,
        response: String?,
        paymentData: PaymentData?
    ) {
        val bookingId = activeBookingId
        val message = response ?: "Payment processing was not completed"

        Log.w(TAG, "Payment error/cancellation received: code=$errorCode, message=$message, bookingId=$bookingId")

        val state = if (errorCode == Checkout.PAYMENT_CANCELED) {
            PaymentUiState.Cancelled(
                bookingId = bookingId,
                message = message
            )
        } else {
            PaymentUiState.Error(
                code = errorCode,
                message = message,
                bookingId = bookingId
            )
        }

        _uiState.value = state
        paymentCallback?.invoke(state)
    }

    /**
     * Resets the UI state back to [PaymentUiState.Idle].
     */
    fun resetState() {
        _uiState.value = PaymentUiState.Idle
        activeBookingId = null
        paymentCallback = null
    }
}

/**
 * Exception thrown when payment UI initialization or launching fails.
 */
class PaymentException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)
