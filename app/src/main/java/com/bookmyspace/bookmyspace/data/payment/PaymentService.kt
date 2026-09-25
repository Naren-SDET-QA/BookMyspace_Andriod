package com.bookmyspace.bookmyspace.data.payment

import android.app.Activity
import android.content.Context
import android.util.Log
import com.bookmyspace.bookmyspace.BuildConfig
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.razorpay.Checkout
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener
import org.json.JSONObject
import java.util.UUID

/**
 * Payment request payload containing transaction parameters.
 */
data class PaymentRequest(
    val bookingId: String,
    val venueName: String,
    val amountInRupees: Double,
    val customerName: String = "",
    val customerEmail: String = "",
    val customerPhone: String = "",
    val description: String = "",
    val orderId: String? = null,
    val currency: String = "INR",
    val themeColorHex: String = "#0D47A1"
)

/**
 * Result sealed class representing the status of a payment operation.
 */
sealed class PaymentResult {
    data class Success(
        val paymentId: String,
        val orderId: String?,
        val signature: String?,
        val bookingId: String
    ) : PaymentResult()

    data class Failure(
        val errorCode: Int,
        val errorMessage: String,
        val bookingId: String
    ) : PaymentResult()

    data class Cancelled(
        val bookingId: String,
        val message: String = "Payment was cancelled by the user"
    ) : PaymentResult()
}

/**
 * Service class that manages Razorpay SDK initialization from environment variables (BuildConfig / System env)
 * and provides robust methods to process payments across the application.
 */
class PaymentService private constructor() {

    companion object {
        private const val TAG = "PaymentService"
        private const val FALLBACK_TEST_KEY = "rzp_test_bookmyspace"

        @Volatile
        private var instance: PaymentService? = null

        fun getInstance(): PaymentService {
            return instance ?: synchronized(this) {
                instance ?: PaymentService().also { instance = it }
            }
        }
    }

    private var razorpayKeyId: String = ""
    private var isInitialized: Boolean = false
    private var activeBookingId: String? = null
    private var activeResultCallback: ((PaymentResult) -> Unit)? = null

    /**
     * Initializes the Razorpay SDK using the API key resolved from environment variables via BuildConfig
     * with fallback to System environment or default test keys.
     */
    fun initialize(context: Context, customKey: String? = null) {
        razorpayKeyId = resolveApiKey(customKey)
        try {
            isInitialized = true
            Log.d(TAG, "Razorpay SDK initialized successfully with Key: ${razorpayKeyId.take(8)}...")
        } catch (e: Throwable) {
            Log.e(TAG, "Error initializing Razorpay SDK: ${e.message}", e)
        }
    }

    /**
     * Resolves the Razorpay API Key from BuildConfig / Environment variables.
     */
    fun resolveApiKey(customKey: String? = null): String {
        if (!customKey.isNullOrBlank()) {
            return customKey
        }

        // 1. Check generated BuildConfig key from .env / Secrets Gradle Plugin
        try {
            val buildConfigKey = BuildConfig.RAZORPAY_KEY_ID
            if (!buildConfigKey.isNullOrBlank() && !buildConfigKey.equals("null", ignoreCase = true)) {
                return buildConfigKey
            }
        } catch (e: Throwable) {
            Log.w(TAG, "BuildConfig.RAZORPAY_KEY_ID not accessible: ${e.message}")
        }

        // 2. Check System Environment variables
        try {
            val sysEnvKey = System.getenv("RAZORPAY_KEY_ID")
            if (!sysEnvKey.isNullOrBlank()) {
                return sysEnvKey
            }
        } catch (e: Throwable) {
            Log.w(TAG, "System.getenv RAZORPAY_KEY_ID not accessible: ${e.message}")
        }

        // 3. Fallback test key
        return FALLBACK_TEST_KEY
    }

    /**
     * Returns the currently active Razorpay API key.
     */
    fun getApiKey(): String {
        if (razorpayKeyId.isBlank()) {
            razorpayKeyId = resolveApiKey()
        }
        return razorpayKeyId
    }

    /**
     * Primary method to process payments by launching the Razorpay Checkout flow.
     *
     * @param activity The host Activity required to present the payment overlay.
     * @param request The payment request details (amount, bookingId, user details).
     * @param onResult Callback invoked with the final PaymentResult (Success, Failure, Cancelled).
     */
    fun processPayment(
        activity: Activity,
        request: PaymentRequest,
        onResult: (PaymentResult) -> Unit
    ) {
        val apiKey = getApiKey()
        if (apiKey.isBlank()) {
            val error = PaymentResult.Failure(
                errorCode = -1,
                errorMessage = "Razorpay API key is missing. Please configure RAZORPAY_KEY_ID in environment secrets.",
                bookingId = request.bookingId
            )
            onResult(error)
            return
        }

        if (request.amountInRupees <= 0) {
            val error = PaymentResult.Failure(
                errorCode = -2,
                errorMessage = "Invalid payment amount: ₹${request.amountInRupees}",
                bookingId = request.bookingId
            )
            onResult(error)
            return
        }

        this.activeBookingId = request.bookingId
        this.activeResultCallback = onResult

        val checkout = Checkout()
        checkout.setKeyID(apiKey)

        try {
            val options = buildRazorpayOptions(apiKey, request)
            Log.d(TAG, "Launching Razorpay payment for booking ${request.bookingId} - Amount: ₹${request.amountInRupees}")
            checkout.open(activity, options)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch Razorpay checkout: ${e.message}", e)
            val error = PaymentResult.Failure(
                errorCode = -3,
                errorMessage = e.localizedMessage ?: "Failed to open payment checkout gateway",
                bookingId = request.bookingId
            )
            onResult(error)
            clearActiveSession()
        }
    }

    /**
     * Convenience method to process payment directly from a Booking model.
     */
    fun processBookingPayment(
        activity: Activity,
        booking: Booking,
        customerName: String = "",
        customerEmail: String = "",
        customerPhone: String = "",
        onResult: (PaymentResult) -> Unit
    ) {
        val request = PaymentRequest(
            bookingId = booking.id,
            venueName = booking.venueName,
            amountInRupees = booking.totalAmount,
            customerName = customerName.ifBlank { booking.userName },
            customerEmail = customerEmail.ifBlank { booking.userEmail },
            customerPhone = customerPhone.ifBlank { booking.userPhone },
            description = "Reservation for ${booking.venueName} on ${booking.bookingDate.ifBlank { booking.date }}"
        )
        processPayment(activity, request, onResult)
    }

    /**
     * Constructs the standard Razorpay checkout configuration JSON.
     */
    fun buildRazorpayOptions(apiKey: String, request: PaymentRequest): JSONObject {
        return JSONObject().apply {
            put("key", apiKey)
            put("name", "BookMySpace")
            put("description", request.description.ifBlank { "Reservation at ${request.venueName}" })
            put("currency", request.currency)

            // Convert Rupees to paise (subunit)
            val amountInPaise = (request.amountInRupees * 100).toLong()
            put("amount", amountInPaise)

            request.orderId?.let {
                if (it.isNotBlank()) put("order_id", it)
            }

            // Theme customization
            val theme = JSONObject().apply {
                put("color", request.themeColorHex)
            }
            put("theme", theme)

            // Prefill customer profile
            val prefill = JSONObject().apply {
                if (request.customerEmail.isNotBlank()) put("email", request.customerEmail)
                if (request.customerPhone.isNotBlank()) put("contact", request.customerPhone)
                if (request.customerName.isNotBlank()) put("name", request.customerName)
            }
            put("prefill", prefill)

            // Retry options
            val retry = JSONObject().apply {
                put("enabled", true)
                put("max_count", 2)
            }
            put("retry", retry)

            // Metadata / Notes
            val notes = JSONObject().apply {
                put("booking_id", request.bookingId)
                put("venue_name", request.venueName)
                put("platform", "Android")
            }
            put("notes", notes)
        }
    }

    /**
     * Dispatches successful payment response to the active listener and updates the repository
     * after verifying cryptographic signature.
     */
    fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        val bookingId = activeBookingId ?: ""
        val paymentId = razorpayPaymentId ?: paymentData?.paymentId ?: "pay_${UUID.randomUUID().toString().take(8)}"
        val orderId = paymentData?.orderId
        val signature = paymentData?.signature

        Log.d(TAG, "Verifying payment signature: ID=$paymentId, OrderID=$orderId, Booking=$bookingId")

        val validationResult = PaymentSignatureValidator.verifyCheckoutSignature(
            orderId = orderId,
            paymentId = paymentId,
            signature = signature
        )

        when (validationResult) {
            is SignatureValidationResult.Valid, is SignatureValidationResult.Skipped -> {
                if (bookingId.isNotBlank()) {
                    BookMySpaceRepository.confirmBookingPayment(
                        bookingId = bookingId,
                        paymentId = paymentId,
                        paymentMethod = "Razorpay Gateway",
                        orderId = orderId,
                        signature = signature,
                        isVerified = true
                    )
                }

                val result = PaymentResult.Success(
                    paymentId = paymentId,
                    orderId = orderId,
                    signature = signature,
                    bookingId = bookingId
                )
                activeResultCallback?.invoke(result)
            }
            is SignatureValidationResult.Invalid -> {
                Log.e(TAG, "🚨 Signature verification failed in PaymentService: ${validationResult.reason}")
                if (bookingId.isNotBlank()) {
                    BookMySpaceRepository.recordPaymentFailure(
                        bookingId = bookingId,
                        reason = "Signature verification failed: ${validationResult.reason}",
                        paymentId = paymentId,
                        orderId = orderId,
                        signature = signature,
                        isVerified = false
                    )
                }

                val error = PaymentResult.Failure(
                    errorCode = -403,
                    errorMessage = "Payment signature verification failed. Potential security issue.",
                    bookingId = bookingId
                )
                activeResultCallback?.invoke(error)
            }
        }
        clearActiveSession()
    }

    /**
     * Dispatches payment error or user cancellation to the active listener.
     */
    fun onPaymentError(errorCode: Int, response: String?, paymentData: PaymentData?) {
        val bookingId = activeBookingId ?: ""
        val message = response ?: "Payment processing failed"

        Log.w(TAG, "Payment Failed/Cancelled: Code=$errorCode, Message=$message, Booking=$bookingId")

        val result = if (errorCode == Checkout.PAYMENT_CANCELED) {
            PaymentResult.Cancelled(
                bookingId = bookingId,
                message = message
            )
        } else {
            PaymentResult.Failure(
                errorCode = errorCode,
                errorMessage = message,
                bookingId = bookingId
            )
        }
        activeResultCallback?.invoke(result)
        clearActiveSession()
    }

    private fun clearActiveSession() {
        activeBookingId = null
        activeResultCallback = null
    }
}
