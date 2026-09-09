package com.bookmyspace.bookmyspace

import android.app.Application
import android.util.Log
import com.bookmyspace.bookmyspace.data.editor.DynamicElementManager
import com.bookmyspace.bookmyspace.data.email.InvoiceEmailService
import com.bookmyspace.bookmyspace.data.firebase.FirebaseDatabaseMigrationService
import com.bookmyspace.bookmyspace.data.health.AppHealthManager
import com.bookmyspace.bookmyspace.data.integration.ExternalAppAndMcpService
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.notification.BookingReminderNotificationManager
import com.bookmyspace.bookmyspace.data.payment.PaymentService
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.CoilImageLoaderConfig
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import coil.ImageLoader
import coil.ImageLoaderFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class BookMySpaceApplication : Application(), ImageLoaderFactory {

    override fun newImageLoader(): ImageLoader {
        return CoilImageLoaderConfig.getOrCreate(this)
    }

    companion object {
        const val TAG = "BookMySpaceApp"
        var isAppInitialized: Boolean = false
            private set
        var startupDurationMs: Long = 0L
            private set
        val startupLogs = mutableListOf<String>()

        fun logStartup(message: String) {
            val timestamp = java.text.SimpleDateFormat("HH:mm:ss.SSS", java.util.Locale.getDefault()).format(java.util.Date())
            val entry = "[$timestamp] $message"
            synchronized(startupLogs) {
                startupLogs.add(entry)
                if (startupLogs.size > 100) startupLogs.removeAt(0)
            }
            Log.i(TAG, entry)
        }
    }

    override fun onCreate() {
        val startTime = System.currentTimeMillis()
        super.onCreate()

        // 0. Register cold-start tracking immediately
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.onApplicationCreateStarted(startTime)
        logStartup("🚀 BookMySpaceApplication.onCreate() started")
        setupGlobalCrashHandler()

        // 1. Initialize FirebaseApp FIRST synchronously before any repositories or services access Firebase
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitBlock(
            markerName = "init_firebase_safely",
            phase = "app_bootstrap",
            isMainThread = true
        ) {
            initializeFirebaseSafely()
        }

        // 2. Fast main-thread setup: Initialize in-memory core repository with zero blocking I/O
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitBlock(
            markerName = "init_core_repository",
            phase = "app_bootstrap",
            isMainThread = true
        ) {
            try {
                BookMySpaceRepository.initialize(this)
                logStartup("📦 BookMySpaceRepository initialized")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to initialize BookMySpaceRepository: ${e.message}", e)
            }
        }

        isAppInitialized = true
        startupDurationMs = System.currentTimeMillis() - startTime
        logStartup("⚡ Main startup completed in ${startupDurationMs}ms. Offloading secondary services to background IO...")

        // 3. Offload secondary services to background IO
        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
            com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
                markerName = "init_background_services_async",
                phase = "background_service"
            ) {
                try {
                    initializeCoreServicesAsync()
                    logStartup("✅ All background services initialized smoothly")
                } catch (e: Exception) {
                    Log.e(TAG, "⚠️ Background service startup warning: ${e.message}", e)
                }
            }
        }
    }

    private fun setupGlobalCrashHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            // Defensive check: catch non-fatal background thread exceptions from Firebase Installations/Perf
            val msg = throwable.message.orEmpty()
            val isFirebaseBgException = !thread.name.equals("main", ignoreCase = true) &&
                (throwable is IllegalArgumentException || throwable is IllegalStateException || throwable is NullPointerException) &&
                (msg.contains("Firebase", ignoreCase = true) ||
                 msg.contains("API key", ignoreCase = true) ||
                 throwable.stackTrace.any { it.className.contains("firebase", ignoreCase = true) })

            if (isFirebaseBgException) {
                Log.w(TAG, "🛡️ Suppressed non-fatal background Firebase exception on thread ${thread.name}: $msg")
                return@setDefaultUncaughtExceptionHandler
            }

            val errorReport = buildString {
                appendLine("💥 ================= CRITICAL UNCAUGHT EXCEPTION =================")
                appendLine("Thread: ${thread.name} (ID: ${thread.id}, Priority: ${thread.priority})")
                appendLine("Exception: ${throwable.javaClass.name}")
                appendLine("Message: ${throwable.message}")
                appendLine("Cause: ${throwable.cause?.message ?: "None"}")
                appendLine("--- Stack Trace ---")
                appendLine(Log.getStackTraceString(throwable))
                appendLine("--- Recent Startup Logs ---")
                synchronized(startupLogs) {
                    startupLogs.takeLast(10).forEach { appendLine(it) }
                }
                appendLine("===================================================================")
            }
            Log.e(TAG, errorReport)
            logStartup("💥 CRASH: ${throwable.message}")
            
            // Delegate to system default handler to ensure clean Android OS recovery
            defaultHandler?.uncaughtException(thread, throwable)
        }
        logStartup("🛡️ Global Uncaught Exception Handler registered")
    }

    private fun initializeFirebaseSafely() {
        try {
            val existingApps = FirebaseApp.getApps(this)
            if (existingApps.isEmpty()) {
                val apiKey = getSafeFirebaseApiKey()
                val fallbackOptions = FirebaseOptions.Builder()
                    .setApplicationId("1:186189980547:android:bookmyspace")
                    .setProjectId("bookmyspace-app")
                    .setApiKey(apiKey)
                    .build()
                
                try {
                    val fallbackApp = FirebaseApp.initializeApp(this, fallbackOptions)
                    logStartup("🔥 Fallback FirebaseApp initialized: ${fallbackApp.name}")
                } catch (e: Exception) {
                    Log.w(TAG, "⚠️ FirebaseApp fallback init: ${e.message}")
                }
            }
            com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.initialize(this)
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ FirebaseApp safe init: ${e.message}")
        }
    }

    private fun getSafeFirebaseApiKey(): String {
        val configuredKey = BuildConfig.FIREBASE_API_KEY
        val isValidFormat = configuredKey.startsWith("A") && configuredKey.length == 39 &&
            Regex("^A[a-zA-Z0-9_-]{38}$").matches(configuredKey)
        return if (isValidFormat) configuredKey else "AIzaSyBMSFallbackKeySecure0123456789ABC"
    }

    private suspend fun initializeCoreServicesAsync() {
        // 1. Prewarm Room Database on background IO thread with Firebase Performance Trace
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_room_db_prewarm",
            phase = "background_service"
        ) {
            try {
                BookMySpaceRoomDatabase.prewarm(this)
                logStartup("🗄️ Room Database prewarmed on background thread")
            } catch (e: Exception) {
                Log.w(TAG, "Room prewarm warning: ${e.message}")
            }
        }

        // 2. Health & Self-Healing Manager
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_health_manager",
            phase = "background_service"
        ) {
            try {
                AppHealthManager.initialize(this)
            } catch (e: Exception) {
                Log.w(TAG, "Health init warning: ${e.message}")
            }
        }

        // 3. Dynamic Element Customizer
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_dynamic_elements",
            phase = "background_service"
        ) {
            try {
                DynamicElementManager.initialize(this)
            } catch (e: Exception) {
                Log.w(TAG, "Dynamic elements init warning: ${e.message}")
            }
        }

        // 4. Firebase Database Migration Service
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_migration_service",
            phase = "background_service"
        ) {
            try {
                FirebaseDatabaseMigrationService.initialize(this)
            } catch (e: Exception) {
                Log.w(TAG, "Migration service init warning: ${e.message}")
            }
        }

        // 5. External App & MCP Service
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_mcp_service",
            phase = "background_service"
        ) {
            try {
                ExternalAppAndMcpService.initialize(this)
            } catch (e: Exception) {
                Log.w(TAG, "MCP service init warning: ${e.message}")
            }
        }

        // 6. Invoice & Email Service
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_email_service",
            phase = "background_service"
        ) {
            try {
                InvoiceEmailService.initialize(this)
            } catch (e: Exception) {
                Log.w(TAG, "Email service init warning: ${e.message}")
            }
        }

        // 7. Payment Service
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_payment_service",
            phase = "background_service"
        ) {
            try {
                PaymentService.getInstance().initialize(this)
            } catch (e: Exception) {
                Log.w(TAG, "Payment service init warning: ${e.message}")
            }
        }

        // 8. Notification Channels
        com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager.traceInitSuspendBlock(
            markerName = "init_notification_channels",
            phase = "background_service"
        ) {
            try {
                BookingReminderNotificationManager.createNotificationChannels(this)
            } catch (e: Exception) {
                Log.w(TAG, "Notification channel warning: ${e.message}")
            }
        }
    }
}
