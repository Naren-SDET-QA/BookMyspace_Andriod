package com.bookmyspace.bookmyspace

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.bookmyspace.bookmyspace.data.payment.PaymentHandler
import com.bookmyspace.bookmyspace.data.payment.PaymentProcessingService
import com.bookmyspace.bookmyspace.data.payment.PaymentService
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.navigation.AppNavigation
import com.bookmyspace.bookmyspace.ui.theme.BookMySpaceTheme
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener

class MainActivity : ComponentActivity(), PaymentResultWithDataListener {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BookMySpaceRepository.initialize(applicationContext)
        com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.initialize(applicationContext)
        PaymentService.getInstance().initialize(applicationContext)
        enableEdgeToEdge()
        setContent {
            BookMySpaceTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AppNavigation()
                }
            }
        }
    }

    override fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        PaymentHandler.getActiveHandler()?.onPaymentSuccess(razorpayPaymentId, paymentData)
        PaymentService.getInstance().onPaymentSuccess(razorpayPaymentId, paymentData)
        PaymentProcessingService.getInstance().onPaymentSuccess(razorpayPaymentId, paymentData)
    }

    override fun onPaymentError(errorCode: Int, response: String?, paymentData: PaymentData?) {
        PaymentHandler.getActiveHandler()?.onPaymentError(errorCode, response, paymentData)
        PaymentService.getInstance().onPaymentError(errorCode, response, paymentData)
        PaymentProcessingService.getInstance().onPaymentError(errorCode, response, paymentData)
    }
}
