package com.bookmyspace.bookmyspace

import android.util.Log
import com.razorpay.Checkout
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity(), PaymentResultWithDataListener {

    private val CHANNEL = "com.bookmyspace.bookmyspace/razorpay_native"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openCheckout") {
                val keyId = call.argument<String>("keyId") ?: ""
                val orderId = call.argument<String>("orderId") ?: ""
                val amount = call.argument<Double>("amount") ?: 0.0
                val amountInPaise = call.argument<Number>("amountInPaise")?.toLong() ?: (amount * 100).toLong()
                val currency = call.argument<String>("currency") ?: "INR"
                val name = call.argument<String>("name") ?: "BookMySpace"
                val description = call.argument<String>("description") ?: "Space Booking Reservation"
                val customerEmail = call.argument<String>("customerEmail") ?: ""
                val customerPhone = call.argument<String>("customerPhone") ?: ""
                val customerName = call.argument<String>("customerName") ?: ""
                val themeColor = call.argument<String>("themeColor") ?: "#00BFA5"
                val notesMap = call.argument<Map<String, Any>>("notes") ?: emptyMap()

                pendingResult = result

                try {
                    val checkout = Checkout()
                    checkout.setKeyID(keyId)

                    val options = JSONObject().apply {
                        put("name", name)
                        put("description", description)
                        put("currency", currency)
                        put("amount", amountInPaise)
                        if (orderId.isNotBlank()) {
                            put("order_id", orderId)
                        }
                        put("theme", JSONObject().put("color", themeColor))
                        put("prefill", JSONObject().apply {
                            if (customerEmail.isNotBlank()) put("email", customerEmail)
                            if (customerPhone.isNotBlank()) put("contact", customerPhone)
                            if (customerName.isNotBlank()) put("name", customerName)
                        })
                        put("notes", JSONObject(notesMap))
                    }

                    checkout.open(this, options)
                } catch (e: Exception) {
                    Log.e("MainActivity", "Razorpay checkout launch exception: ${e.message}", e)
                    result.error("CHECKOUT_ERROR", e.message, null)
                    pendingResult = null
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        val resultMap = mapOf(
            "status" to "success",
            "paymentId" to (razorpayPaymentId ?: paymentData?.paymentId ?: ""),
            "orderId" to (paymentData?.orderId ?: ""),
            "signature" to (paymentData?.signature ?: "")
        )
        pendingResult?.success(resultMap)
        pendingResult = null
    }

    override fun onPaymentError(code: Int, response: String?, paymentData: PaymentData?) {
        if (code == Checkout.PAYMENT_CANCELED) {
            val resultMap = mapOf(
                "status" to "cancelled",
                "message" to "Payment was cancelled by user"
            )
            pendingResult?.success(resultMap)
        } else {
            val resultMap = mapOf(
                "status" to "failed",
                "errorCode" to code.toString(),
                "message" to (response ?: "Payment failed")
            )
            pendingResult?.success(resultMap)
        }
        pendingResult = null
    }
}
