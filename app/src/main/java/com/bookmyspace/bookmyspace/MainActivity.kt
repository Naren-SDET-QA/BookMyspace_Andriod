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
import androidx.lifecycle.lifecycleScope
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity(), PaymentResultWithDataListener {

    companion object {
        private const val TAG = "MainActivityLifecycle"
    }

    private val requestNotificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            Log.i(TAG, "🔔 [Permissions] POST_NOTIFICATIONS permission GRANTED by user")
        } else {
            Log.w(TAG, "⚠️ [Permissions] POST_NOTIFICATIONS permission DENIED by user")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val createStartTime = System.currentTimeMillis()
        Log.i(TAG, "🚀 [Lifecycle] onCreate() started with savedInstanceState=${savedInstanceState != null}")

        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitBlock(
            markerName = "init_activity_pre_ui",
            phase = "activity_bootstrap",
            isMainThread = true
        ) {
            super.onCreate(savedInstanceState)
            // Initialize Firebase Performance Monitoring & Safe ANR Watchdog
            com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.initialize(this)
            com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.startWatchdog(thresholdMs = 2500L)
            enableEdgeToEdge()
        }

        Log.i(TAG, "🎨 [UI] Setting Compose Content tree...")

        try {
            com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitBlock(
                markerName = "init_activity_set_content",
                phase = "activity_bootstrap",
                isMainThread = true
            ) {
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
            Log.i(TAG, "✅ [Lifecycle] setContent configured in ${System.currentTimeMillis() - createStartTime}ms")
        } catch (e: Exception) {
            Log.e(TAG, "💥 [UI] Fatal exception during setContent: ${e.message}", e)
            throw e
        }

        // Post-launch background tasks: Request runtime permissions & FCM token asynchronously after UI settles
        lifecycleScope.launch(Dispatchers.IO) {
            kotlinx.coroutines.delay(1200L)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val currentPermission = ContextCompat.checkSelfPermission(
                        this@MainActivity,
                        android.Manifest.permission.POST_NOTIFICATIONS
                    )
                    if (currentPermission != PackageManager.PERMISSION_GRANTED) {
                        Log.i(TAG, "🔔 [Permissions] Requesting POST_NOTIFICATIONS runtime permission...")
                        withContext(Dispatchers.Main) {
                            requestNotificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ [Permissions] Error checking notification permission: ${e.message}")
            }

            try {
                if (com.google.firebase.FirebaseApp.getApps(this@MainActivity).isNotEmpty()) {
                    Log.d(TAG, "🔥 [FCM] Requesting FirebaseMessaging registration token...")
                    try {
                        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                            if (task.isSuccessful) {
                                val token = task.result
                                Log.i(TAG, "🔥 [FCM] Token retrieved successfully: ${token.take(16)}... (length=${token.length})")
                                BookMySpaceRepository.updateFcmToken(token)
                            }
                        }
                    } catch (t: Throwable) {
                        Log.w(TAG, "⚠️ [FCM] FirebaseMessaging component inactive: ${t.message}")
                    }
                }
            } catch (e: Throwable) {
                Log.w(TAG, "⚠️ [FCM] FirebaseMessaging unavailable or in local fallback mode: ${e.message}")
            }
        }
    }

    override fun onStart() {
        super.onStart()
        Log.i(TAG, "▶️ [Lifecycle] onStart() - Activity becoming visible")
    }

    override fun onResume() {
        super.onResume()
        Log.i(TAG, "🟢 [Lifecycle] onResume() - Activity in foreground and interactive")
    }

    override fun onPause() {
        super.onPause()
        Log.i(TAG, "⏸️ [Lifecycle] onPause() - Activity losing foreground focus")
    }

    override fun onStop() {
        super.onStop()
        Log.i(TAG, "⏹️ [Lifecycle] onStop() - Activity no longer visible")
    }

    override fun onDestroy() {
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.stopWatchdog()
        super.onDestroy()
        Log.i(TAG, "🛑 [Lifecycle] onDestroy() - Activity being destroyed")
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        Log.d(TAG, "💾 [Lifecycle] onSaveInstanceState() - Saving UI state")
    }

    override fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        Log.i(TAG, "💳 [Payment] Success callback received: paymentId=$razorpayPaymentId")
        PaymentHandler.getActiveHandler()?.onPaymentSuccess(razorpayPaymentId, paymentData)
        PaymentService.getInstance().onPaymentSuccess(razorpayPaymentId, paymentData)
        PaymentProcessingService.getInstance().onPaymentSuccess(razorpayPaymentId, paymentData)
    }

    override fun onPaymentError(errorCode: Int, response: String?, paymentData: PaymentData?) {
        Log.w(TAG, "💳 [Payment] Error callback received: code=$errorCode, response=$response")
        PaymentHandler.getActiveHandler()?.onPaymentError(errorCode, response, paymentData)
        PaymentService.getInstance().onPaymentError(errorCode, response, paymentData)
        PaymentProcessingService.getInstance().onPaymentError(errorCode, response, paymentData)
    }
}

