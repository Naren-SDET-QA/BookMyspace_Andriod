package com.bookmyspace.bookmyspace

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import com.bookmyspace.bookmyspace.data.notification.BookingReminderNotificationManager
import com.bookmyspace.bookmyspace.data.payment.PaymentHandler
import com.bookmyspace.bookmyspace.data.payment.PaymentProcessingService
import com.bookmyspace.bookmyspace.data.payment.PaymentService
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.navigation.AppNavigation
import com.bookmyspace.bookmyspace.ui.theme.BookMySpaceTheme
import com.google.firebase.messaging.FirebaseMessaging
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener

class MainActivity : ComponentActivity(), PaymentResultWithDataListener {

    private val requestNotificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            Log.d("MainActivity", "POST_NOTIFICATIONS permission granted by user")
        } else {
            Log.w("MainActivity", "POST_NOTIFICATIONS permission denied by user")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BookMySpaceRepository.initialize(applicationContext)
        com.bookmyspace.bookmyspace.data.health.AppHealthManager.initialize(applicationContext)
        com.bookmyspace.bookmyspace.data.editor.DynamicElementManager.initialize(applicationContext)
        com.bookmyspace.bookmyspace.data.firebase.FirebaseDatabaseMigrationService.initialize(applicationContext)
        com.bookmyspace.bookmyspace.data.integration.ExternalAppAndMcpService.initialize(applicationContext)
        com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.initialize(applicationContext)
        PaymentService.getInstance().initialize(applicationContext)

        // Initialize FCM notification channels
        BookingReminderNotificationManager.createNotificationChannels(applicationContext)

        // Request runtime notification permission on Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    android.Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                requestNotificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        // Initialize Firebase Cloud Messaging token
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    val token = task.result
                    Log.d("MainActivity", "FCM Registration Token initialized: $token")
                    BookMySpaceRepository.updateFcmToken(token)
                } else {
                    Log.w("MainActivity", "Fetching FCM registration token failed", task.exception)
                }
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "FirebaseMessaging initialization check: ${e.message}")
        }

        enableEdgeToEdge()
        setContent {
            BookMySpaceTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    com.bookmyspace.bookmyspace.ui.components.GlobalErrorBoundary {
                        AppNavigation()
                    }
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
