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
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class BookMySpaceApplication : Application() {

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

        logStartup("🚀 BookMySpaceApplication.onCreate() started")
        setupGlobalCrashHandler()

        // 1. Initialize FirebaseApp FIRST synchronously before any repositories or services access Firebase
        initializeFirebaseSafely()

        // 2. Fast main-thread setup: Initialize in-memory core repository with zero blocking I/O
        try {
            BookMySpaceRepository.initialize(this)
            logStartup("📦 BookMySpaceRepository initialized")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize BookMySpaceRepository: ${e.message}", e)
        }

        isAppInitialized = true
        startupDurationMs = System.currentTimeMillis() - startTime
        logStartup("⚡ Main startup completed in ${startupDurationMs}ms. Offloading secondary services to background IO...")

        // 3. Offload secondary services to background IO
        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
            try {
                initializeCoreServicesAsync()
                logStartup("✅ All background services initialized smoothly")
            } catch (e: Exception) {
                Log.e(TAG, "⚠️ Background service startup warning: ${e.message}", e)
            }
        }
    }

    private fun setupGlobalCrashHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
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
                val fallbackOptions = FirebaseOptions.Builder()
                    .setApplicationId("1:186189980547:android:bookmyspace")
                    .setProjectId("bookmyspace-app")
                    .setApiKey("AIzaSyBMS_FALLBACK_KEY_SECURE")
                    .build()
                
                try {
                    val app = FirebaseApp.initializeApp(this)
                    if (app != null) {
                        logStartup("🔥 FirebaseApp initialized: ${app.name}")
                    } else {
                        val fallbackApp = FirebaseApp.initializeApp(this, fallbackOptions)
                        logStartup("🔥 Fallback FirebaseApp initialized: ${fallbackApp.name}")
                    }
                } catch (e: Exception) {
                    val fallbackApp = FirebaseApp.initializeApp(this, fallbackOptions)
                    logStartup("🔥 Fallback FirebaseApp initialized: ${fallbackApp.name}")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ FirebaseApp safe init: ${e.message}")
        }
    }

    private suspend fun initializeCoreServicesAsync() {
        // 1. Prewarm Room Database on background IO thread (prevents UI hangs on first query)
        try {
            BookMySpaceRoomDatabase.prewarm(this)
            logStartup("🗄️ Room Database prewarmed on background thread")
        } catch (e: Exception) {
            Log.w(TAG, "Room prewarm warning: ${e.message}")
        }

        // 2. Health & Self-Healing Manager
        try {
            AppHealthManager.initialize(this)
        } catch (e: Exception) {
            Log.w(TAG, "Health init warning: ${e.message}")
        }

        // Dynamic Element Customizer
        try {
            DynamicElementManager.initialize(this)
        } catch (e: Exception) {
            Log.w(TAG, "Dynamic elements init warning: ${e.message}")
        }

        // Firebase Database Migration Service
        try {
            FirebaseDatabaseMigrationService.initialize(this)
        } catch (e: Exception) {
            Log.w(TAG, "Migration service init warning: ${e.message}")
        }

        // External App & MCP Service
        try {
            ExternalAppAndMcpService.initialize(this)
        } catch (e: Exception) {
            Log.w(TAG, "MCP service init warning: ${e.message}")
        }

        // Invoice & Email Service
        try {
            InvoiceEmailService.initialize(this)
        } catch (e: Exception) {
            Log.w(TAG, "Email service init warning: ${e.message}")
        }

        // Payment Service
        try {
            PaymentService.getInstance().initialize(this)
        } catch (e: Exception) {
            Log.w(TAG, "Payment service init warning: ${e.message}")
        }

        // Notification Channels
        try {
            BookingReminderNotificationManager.createNotificationChannels(this)
        } catch (e: Exception) {
            Log.w(TAG, "Notification channel warning: ${e.message}")
        }
    }
}
