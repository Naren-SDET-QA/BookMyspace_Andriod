package com.bookmyspace.bookmyspace.data.payment

import android.app.Activity
import android.content.Context
import android.util.Log
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.razorpay.Checkout
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener
import org.json.JSONObject
import java.util.UUID

/**
 * Data model representing a payment transaction payload.
 */
data class PaymentOrderRequest(
    val bookingId: String,
    val venueName: String,
    val customerName: String,
    val customerEmail: String,
    val customerPhone: String,
    val amountInRupees: Double,
    val description: String = "Space Booking Reservation",
    val orderId: String? = null,
    val currency: String = "INR",
    val themeColorHex: String = "#0D47A1"
)

/**
 * Sealed class representing possible outcomes of a payment processing operation.
 */
sealed class PaymentProcessResult {
    data class Success(
        val paymentId: String,
        val orderId: String?,
        val signature: String?,
        val bookingId: String
    ) : PaymentProcessResult()

    data class Error(
        val code: Int,
        val message: String,
        val bookingId: String
    ) : PaymentProcessResult()

    data class Cancelled(
        val bookingId: String,
        val message: String = "Payment was cancelled by user"
    ) : PaymentProcessResult()
}

/**
 * Service responsible for orchestrating Razorpay Standard Checkout SDK flows,
 * payload construction, key initialization, and payment completion callbacks.
 */
class PaymentProcessingService private constructor() {

    companion object {
        private const val TAG = "PaymentProcessingService"
        
        // Default test key (or injected from BuildConfig / environment)
        const val DEFAULT_RAZORPAY_KEY_ID = "rzp_test_bookmyspace"

        @Volatile
        private var instance: PaymentProcessingService? = null

        fun getInstance(): PaymentProcessingService {
            return instance ?: synchronized(this) {
                instance ?: PaymentProcessingService().also { instance = it }
            }
        }
    }

    private var activeBookingId: String? = null
    private var paymentCallback: ((PaymentProcessResult) -> Unit)? = null

    /**
     * Preloads Razorpay SDK resources for low latency checkout experience.
     */
    fun preload(context: Context) {
        try {
            Checkout.preload(context.applicationContext)
            Log.d(TAG, "Razorpay checkout preloaded successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error preloading Razorpay: ${e.message}", e)
        }
    }

    /**
     * Constructs the standard Razorpay checkout JSON options.
     */
    fun buildCheckoutOptions(
        keyId: String = DEFAULT_RAZORPAY_KEY_ID,
        request: PaymentOrderRequest
    ): JSONObject {
        return JSONObject().apply {
            put("name", "BookMySpace")
            put("description", request.description.ifBlank { "Reservation at ${request.venueName}" })
            put("currency", request.currency)
            put("key", keyId)
            
            // Amount in smallest currency sub-unit (paise for INR)
            val amountInPaise = (request.amountInRupees * 100).toLong()
            put("amount", amountInPaise)

            request.orderId?.let {
                if (it.isNotBlank()) {
                    put("order_id", it)
                }
            }

            // Theme customization
            val theme = JSONObject().apply {
                put("color", request.themeColorHex)
            }
            put("theme", theme)

            // Prefill customer details
            val prefill = JSONObject().apply {
                if (request.customerEmail.isNotBlank()) {
                    put("email", request.customerEmail)
                }
                if (request.customerPhone.isNotBlank()) {
                    put("contact", request.customerPhone)
                }
                if (request.customerName.isNotBlank()) {
                    put("name", request.customerName)
                }
            }
            put("prefill", prefill)

            // Retry options
            val retryObj = JSONObject().apply {
                put("enabled", true)
                put("max_count", 2)
            }
            put("retry", retryObj)

            // Custom metadata / notes
            val notes = JSONObject().apply {
                put("booking_id", request.bookingId)
                put("venue_name", request.venueName)
                put("platform", "BookMySpace_Android")
            }
            put("notes", notes)
        }
    }

    /**
     * Launches the Razorpay checkout overlay using the given Activity context.
     */
    fun startPayment(
        activity: Activity,
        request: PaymentOrderRequest,
        keyId: String = DEFAULT_RAZORPAY_KEY_ID,
        onResult: (PaymentProcessResult) -> Unit
    ) {
        this.activeBookingId = request.bookingId
        this.paymentCallback = onResult

        val checkout = Checkout()
        checkout.setKeyID(keyId)

        try {
            val options = buildCheckoutOptions(keyId, request)
            Log.d(TAG, "Opening Razorpay checkout for booking ${request.bookingId} with amount ₹${request.amountInRupees}")
            checkout.open(activity, options)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Razorpay checkout: ${e.message}", e)
            val errorResult = PaymentProcessResult.Error(
                code = -1,
                message = e.localizedMessage ?: "Failed to open payment gateway",
                bookingId = request.bookingId
            )
            onResult(errorResult)
            clearCallback()
        }
    }

    /**
     * Invoked when Razorpay payment completes successfully.
     */
    fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        val bookingId = activeBookingId ?: ""
        val paymentId = razorpayPaymentId ?: paymentData?.paymentId ?: "pay_${UUID.randomUUID().toString().take(8)}"
        val orderId = paymentData?.orderId
        val signature = paymentData?.signature

        Log.d(TAG, "Payment Success: paymentId=$paymentId, orderId=$orderId, bookingId=$bookingId")
        
        // Auto-synchronize booking status in repository
        if (bookingId.isNotBlank()) {
            BookMySpaceRepository.confirmBookingPayment(
                bookingId = bookingId,
                paymentId = paymentId,
                paymentMethod = "Razorpay Standard Checkout"
            )
        }

        val result = PaymentProcessResult.Success(
            paymentId = paymentId,
            orderId = orderId,
            signature = signature,
            bookingId = bookingId
        )
        paymentCallback?.invoke(result)
        clearCallback()
    }

    /**
     * Invoked when Razorpay payment fails or is cancelled by user.
     */
    fun onPaymentError(errorCode: Int, response: String?, paymentData: PaymentData?) {
        val bookingId = activeBookingId ?: ""
        val message = response ?: "Payment processing failed"
        Log.e(TAG, "Payment Error: code=$errorCode, message=$message, bookingId=$bookingId")

        val result = if (errorCode == Checkout.PAYMENT_CANCELED) {
            PaymentProcessResult.Cancelled(
                bookingId = bookingId,
                message = message
            )
        } else {
            PaymentProcessResult.Error(
                code = errorCode,
                message = message,
                bookingId = bookingId
            )
        }
        paymentCallback?.invoke(result)
        clearCallback()
    }

    private fun clearCallback() {
        activeBookingId = null
        paymentCallback = null
    }
}
