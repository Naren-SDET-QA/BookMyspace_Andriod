package com.bookmyspace.bookmyspace.data.diagnostics

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import com.google.firebase.FirebaseApp
import com.google.firebase.perf.FirebasePerformance
import com.google.firebase.perf.metrics.Trace
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Diagnostic record representing a block or slow operation detected on the main UI thread.
 */
data class BlockDiagnosticRecord(
    val timestamp: Long = System.currentTimeMillis(),
    val durationMs: Long,
    val source: String,
    val stackTraceSnippet: String,
    val severity: DiagnosticSeverity = if (durationMs > 2500) DiagnosticSeverity.CRITICAL else DiagnosticSeverity.WARNING
)

/**
 * Diagnostic record representing a custom trace marker in the app initialization sequence,
 * identifying specific blocks of code delaying the first-screen paint.
 */
data class StartupTraceRecord(
    val markerName: String,
    val phase: String, // "app_bootstrap", "activity_bootstrap", "first_screen_paint", "background_service"
    val durationMs: Long,
    val isMainThread: Boolean,
    val startTimeOffsetMs: Long,
    val status: String = "SUCCESS",
    val threadName: String = Thread.currentThread().name
)

enum class DiagnosticSeverity {
    WARNING,
    CRITICAL
}

/**
 * Real-time Performance & Diagnostic Monitor.
 * Provides production-safe Firebase Performance Monitoring for:
 * 1. Screen rendering transitions & Compose display latency
 * 2. Background operation durations (Room database, Firebase sync, network calls)
 * 3. Non-invasive ANR/Freeze detection (>2500ms) with zero UI stutter or recomposition thrashing
 */
object PerformanceDiagnosticsManager {

    const val TAG = "PerfDiagnostics"
    const val DEFAULT_ANR_THRESHOLD_MS = 2500L // Detect real ANR/freeze issues, not routine 60fps frames

    private val _isOverlayVisible = MutableStateFlow(false)
    val isOverlayVisible: StateFlow<Boolean> = _isOverlayVisible.asStateFlow()

    private val _recentJanks = MutableStateFlow<List<BlockDiagnosticRecord>>(emptyList())
    val recentJanks: StateFlow<List<BlockDiagnosticRecord>> = _recentJanks.asStateFlow()

    private val _currentFpsEstimate = MutableStateFlow(60)
    val currentFpsEstimate: StateFlow<Int> = _currentFpsEstimate.asStateFlow()

    private val _lastOperationTime = MutableStateFlow<Map<String, Long>>(emptyMap())
    val lastOperationTime: StateFlow<Map<String, Long>> = _lastOperationTime.asStateFlow()

    private val _totalBlockedTimeMs = MutableStateFlow(0L)
    val totalBlockedTimeMs: StateFlow<Long> = _totalBlockedTimeMs.asStateFlow()

    private val _startupTraces = MutableStateFlow<List<StartupTraceRecord>>(emptyList())
    val startupTraces: StateFlow<List<StartupTraceRecord>> = _startupTraces.asStateFlow()

    private val _coldStartTotalDurationMs = MutableStateFlow<Long?>(null)
    val coldStartTotalDurationMs: StateFlow<Long?> = _coldStartTotalDurationMs.asStateFlow()

    @Volatile
    private var appProcessStartTimeMs: Long = 0L

    @Volatile
    private var firebaseInitTimeMs: Long = 0L

    @Volatile
    private var coldStartTrace: Trace? = null

    @Volatile
    private var firstPaintCompleted = false

    private val blockBuffer = ConcurrentLinkedQueue<BlockDiagnosticRecord>()
    private val activeTraces = ConcurrentHashMap<String, Trace>()

    private var isWatchdogRunning = false
    private var watchdogThread: Thread? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var tick = 0L

    @Volatile
    private var isFirebasePerfReady = false

    private var lastRecordedAnrTime = 0L

    /**
     * Initialize Firebase Performance Monitoring safely.
     * Ensures no crashes or hangs if Firebase is in offline fallback mode.
     */
    fun initialize(context: Context) {
        try {
            // Keep remote Firebase Performance disabled when using offline / local fallback mode.
            // All performance diagnostics, cold-start benchmarks, memory metrics, ANR watchdog,
            // and frame drop monitors operate in pure local high-speed mode without network errors.
            if (FirebaseApp.getApps(context).isNotEmpty()) {
                val app = FirebaseApp.getInstance()
                val apiKey = try { app.options.apiKey } catch (_: Exception) { null }
                val isGenuineProductionApiKey = apiKey != null &&
                    apiKey.startsWith("AIza") &&
                    apiKey.length == 39 &&
                    !apiKey.contains("Fallback", ignoreCase = true) &&
                    !apiKey.contains("PLACEHOLDER", ignoreCase = true) &&
                    !apiKey.contains("YOUR_", ignoreCase = true)

                if (isGenuineProductionApiKey) {
                    try {
                        val perf = FirebasePerformance.getInstance()
                        perf.isPerformanceCollectionEnabled = true
                        isFirebasePerfReady = true
                        firebaseInitTimeMs = System.currentTimeMillis()
                        Log.i(TAG, "🔥 Firebase Performance Monitoring initialized and active")

                        // Start the overall cold-start trace AFTER FirebaseApp is confirmed initialized
                        if (appProcessStartTimeMs > 0 && coldStartTrace == null && !firstPaintCompleted) {
                            try {
                                val trace = perf.newTrace("cold_start_to_first_screen_paint")
                                trace.putAttribute("phase", "first_screen_paint")
                                trace.start()
                                coldStartTrace = trace
                                Log.d(TAG, "⏱️ [PerfInit] Started overall cold-start trace safely after FirebaseApp initialization")
                            } catch (e: Exception) {
                                Log.d(TAG, "Cold-start trace fallback: ${e.message}")
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "FirebasePerformance initialization skipped: ${e.message}")
                        isFirebasePerfReady = false
                    }
                } else {
                    Log.i(TAG, "⚡ PerformanceDiagnosticsManager operating in local-only high-performance mode (zero network overhead)")
                    isFirebasePerfReady = false
                }
            } else {
                Log.i(TAG, "⚡ PerformanceDiagnosticsManager operating in local-only high-performance mode")
                isFirebasePerfReady = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Firebase Performance initialization notice: ${e.message}")
            isFirebasePerfReady = false
        }
    }

    fun toggleOverlay() {
        _isOverlayVisible.value = !_isOverlayVisible.value
    }

    fun setOverlayVisible(visible: Boolean) {
        _isOverlayVisible.value = visible
    }

    /**
     * Start a Firebase Performance trace for screen rendering.
     */
    fun startScreenTrace(screenName: String): Trace? {
        val sanitized = screenName.replace(Regex("[^a-zA-Z0-9_]"), "_").take(32)
        val traceName = "screen_$sanitized"
        return try {
            if (isFirebasePerfReady) {
                val trace = FirebasePerformance.getInstance().newTrace(traceName)
                trace.start()
                activeTraces[traceName] = trace
                Log.d(TAG, "⏱️ [Perf] Screen trace started: $traceName")
                trace
            } else {
                null
            }
        } catch (e: Exception) {
            Log.d(TAG, "Screen trace start skipped: ${e.message}")
            null
        }
    }

    /**
     * Stop a screen performance trace, recording duration and rendering metrics.
     */
    fun stopScreenTrace(trace: Trace?, screenName: String = "", durationMs: Long = -1L) {
        try {
            val sanitized = screenName.replace(Regex("[^a-zA-Z0-9_]"), "_").take(32)
            val traceName = "screen_$sanitized"
            val effectiveTrace = trace ?: activeTraces.remove(traceName)
            if (effectiveTrace != null) {
                if (durationMs > 0) {
                    effectiveTrace.putMetric("screen_render_ms", durationMs)
                }
                effectiveTrace.stop()
                Log.d(TAG, "⏱️ [Perf] Screen trace stopped: $traceName ($durationMs ms)")
            }
        } catch (e: Exception) {
            Log.d(TAG, "Screen trace stop skipped: ${e.message}")
        }
    }

    /**
     * Composable helper to benchmark screen rendering and view lifetime with Firebase Performance.
     */
    @Composable
    fun TrackScreenPerformance(screenName: String) {
        DisposableEffect(screenName) {
            val startTime = System.currentTimeMillis()
            val trace = startScreenTrace(screenName)
            onDispose {
                val duration = System.currentTimeMillis() - startTime
                stopScreenTrace(trace, screenName, duration)
            }
        }
    }

    /**
     * Start a non-invasive background watchdog to detect genuine ANR / UI lockups (>2500ms).
     * Never interrupts normal 60fps frame rendering.
     */
    fun startWatchdog(thresholdMs: Long = DEFAULT_ANR_THRESHOLD_MS) {
        if (isWatchdogRunning) return
        isWatchdogRunning = true

        watchdogThread = Thread({
            Log.i(TAG, "🛡️ [Diagnostics] Non-invasive ANR Watchdog active (threshold=${thresholdMs}ms)")
            while (isWatchdogRunning) {
                val startTick = tick
                val startTime = System.currentTimeMillis()

                mainHandler.post {
                    tick = (tick + 1) % Long.MAX_VALUE
                }

                try {
                    Thread.sleep(thresholdMs)
                } catch (_: InterruptedException) {
                    break
                }

                if (tick == startTick && isWatchdogRunning) {
                    // Main thread didn't respond within thresholdMs -> genuine UI freeze/stall
                    val now = System.currentTimeMillis()
                    if (now - lastRecordedAnrTime > 5000L) { // Throttle: at most once every 5 seconds
                        lastRecordedAnrTime = now
                        val mainThread = Looper.getMainLooper().thread
                        val stackTrace = mainThread.stackTrace

                        val totalBlocked = now - startTime
                        val stackString = stackTrace.take(6).joinToString("\n") { element ->
                            "  at ${element.className}.${element.methodName}(${element.fileName}:${element.lineNumber})"
                        }

                        val topClass = stackTrace.firstOrNull {
                            !it.className.startsWith("android.os") && !it.className.startsWith("java.lang")
                        }?.className?.substringAfterLast(".") ?: "UIThread"

                        val record = BlockDiagnosticRecord(
                            durationMs = totalBlocked,
                            source = topClass,
                            stackTraceSnippet = stackString,
                            severity = if (totalBlocked > 4000) DiagnosticSeverity.CRITICAL else DiagnosticSeverity.WARNING
                        )

                        Log.w(TAG, "⚠️ [UI Freeze Alert] Main thread frozen for ${totalBlocked}ms at $topClass")
                        recordBlock(record)

                        // Log to Firebase Performance Trace
                        try {
                            if (isFirebasePerfReady) {
                                val fbTrace = FirebasePerformance.getInstance().newTrace("anr_stall_${topClass.take(16)}")
                                fbTrace.start()
                                fbTrace.putMetric("stall_duration_ms", totalBlocked)
                                fbTrace.stop()
                            }
                        } catch (e: Exception) {
                            Log.d(TAG, "Firebase Perf trace fallback: ${e.message}")
                        }
                    }
                }
            }
        }, "BMS-ANR-Watchdog").apply {
            isDaemon = true
            priority = Thread.MIN_PRIORITY // Minimum priority so it never competes with UI or IO threads
            start()
        }
    }

    fun stopWatchdog() {
        isWatchdogRunning = false
        watchdogThread?.interrupt()
        watchdogThread = null
    }

    private fun recordBlock(record: BlockDiagnosticRecord) {
        blockBuffer.offer(record)
        while (blockBuffer.size > 10) {
            blockBuffer.poll()
        }
        _recentJanks.value = blockBuffer.toList().reversed()
        _totalBlockedTimeMs.value += record.durationMs

        val estimatedFps = (1000f / (16.6f + (record.durationMs.coerceAtMost(1000L) / 20f))).toInt().coerceIn(10, 60)
        _currentFpsEstimate.value = estimatedFps
    }

    /**
     * Measure a long-running background or asynchronous operation with Firebase Performance.
     */
    suspend fun <T> traceSuspendOperation(
        traceName: String,
        category: String = "background_io",
        block: suspend () -> T
    ): T {
        var trace: Trace? = null
        val cleanName = traceName.replace(Regex("[^a-zA-Z0-9_]"), "_").take(32)
        try {
            if (isFirebasePerfReady) {
                trace = FirebasePerformance.getInstance().newTrace(cleanName)
                trace.putAttribute("category", category)
                trace.start()
            }
        } catch (e: Exception) {
            Log.d(TAG, "Firebase trace creation skipped: ${e.message}")
        }

        val startTime = System.currentTimeMillis()
        try {
            return block()
        } finally {
            val duration = System.currentTimeMillis() - startTime
            try {
                trace?.putMetric("duration_ms", duration)
                trace?.stop()
            } catch (_: Exception) {
            }

            val currentOps = _lastOperationTime.value.toMutableMap()
            currentOps[cleanName] = duration
            _lastOperationTime.value = currentOps
        }
    }

    /**
     * Measure a synchronous operation with Firebase Performance.
     */
    fun <T> traceOperation(
        traceName: String,
        category: String = "sync_op",
        block: () -> T
    ): T {
        var trace: Trace? = null
        val cleanName = traceName.replace(Regex("[^a-zA-Z0-9_]"), "_").take(32)
        try {
            if (isFirebasePerfReady) {
                trace = FirebasePerformance.getInstance().newTrace(cleanName)
                trace.putAttribute("category", category)
                trace.start()
            }
        } catch (e: Exception) {
            Log.d(TAG, "Firebase trace creation skipped: ${e.message}")
        }

        val startTime = System.currentTimeMillis()
        try {
            return block()
        } finally {
            val duration = System.currentTimeMillis() - startTime
            try {
                trace?.putMetric("duration_ms", duration)
                trace?.stop()
            } catch (_: Exception) {
            }

            val currentOps = _lastOperationTime.value.toMutableMap()
            currentOps[cleanName] = duration
            _lastOperationTime.value = currentOps
        }
    }

    /**
     * Start measuring overall cold-start sequence from the beginning of Application.onCreate().
     */
    fun onApplicationCreateStarted(startTimeMs: Long = System.currentTimeMillis()) {
        appProcessStartTimeMs = startTimeMs
        // FirebaseApp may not be initialized at this exact line.
        // If ready, start immediately; otherwise initialize() will start it safely after FirebaseApp.initializeApp().
        try {
            if (isFirebasePerfReady && coldStartTrace == null) {
                val trace = FirebasePerformance.getInstance().newTrace("cold_start_to_first_screen_paint")
                trace.putAttribute("phase", "first_screen_paint")
                trace.start()
                coldStartTrace = trace
                Log.d(TAG, "⏱️ [PerfInit] Started overall cold-start trace: cold_start_to_first_screen_paint")
            }
        } catch (e: Exception) {
            Log.d(TAG, "Cold start trace deferred: ${e.message}")
        }
    }

    /**
     * Trace a synchronous initialization code block delaying the main thread or background setup.
     * Complies with Firebase Performance limits: <= 5 attributes per trace, max 32 metrics.
     */
    fun <T> traceInitBlock(
        markerName: String,
        phase: String = "app_bootstrap",
        isMainThread: Boolean = (Looper.myLooper() == Looper.getMainLooper()),
        block: () -> T
    ): T {
        val cleanName = "init_" + markerName.removePrefix("init_").replace(Regex("[^a-zA-Z0-9_]"), "_").take(27)
        val offset = if (appProcessStartTimeMs > 0) System.currentTimeMillis() - appProcessStartTimeMs else 0L
        var trace: Trace? = null

        try {
            if (isFirebasePerfReady) {
                trace = FirebasePerformance.getInstance().newTrace(cleanName)
                // Exactly 2 attributes to stay well below the 5-attribute limit (leaving 3 for future extensions)
                trace.putAttribute("phase", phase.take(40))
                trace.putAttribute("thread", if (isMainThread) "main" else "background")
                trace.start()
            }
        } catch (e: Exception) {
            Log.d(TAG, "Init trace $cleanName start skipped: ${e.message}")
        }

        val start = System.currentTimeMillis()
        var status = "SUCCESS"
        var isSuccess = 1L
        try {
            return block()
        } catch (t: Throwable) {
            status = "FAILED"
            isSuccess = 0L
            throw t
        } finally {
            val duration = System.currentTimeMillis() - start
            try {
                trace?.putMetric("duration_ms", duration)
                trace?.putMetric("start_offset_ms", offset)
                trace?.putMetric("is_main_thread", if (isMainThread) 1L else 0L)
                trace?.putMetric("success", isSuccess)
                trace?.stop()
            } catch (_: Exception) {}

            val record = StartupTraceRecord(
                markerName = cleanName,
                phase = phase,
                durationMs = duration,
                isMainThread = isMainThread,
                startTimeOffsetMs = offset,
                status = status,
                threadName = Thread.currentThread().name
            )

            val current = _startupTraces.value.toMutableList()
            current.add(record)
            _startupTraces.value = current

            val currentOps = _lastOperationTime.value.toMutableMap()
            currentOps[cleanName] = duration
            _lastOperationTime.value = currentOps

            val threadTag = if (isMainThread) "🔴 MAIN THREAD (Impacts Paint)" else "🟢 BG Thread"
            Log.i(TAG, "⏱️ [PerfInit] $cleanName took ${duration}ms [offset=+${offset}ms, $threadTag, phase=$phase, status=$status]")
        }
    }

    /**
     * Trace an asynchronous/suspend initialization block (e.g. Room prewarm, MCP setup).
     * Complies with Firebase Performance limits: <= 5 attributes per trace, max 32 metrics.
     */
    suspend fun <T> traceInitSuspendBlock(
        markerName: String,
        phase: String = "background_service",
        block: suspend () -> T
    ): T {
        val isMainThread = (Looper.myLooper() == Looper.getMainLooper())
        val cleanName = "init_" + markerName.removePrefix("init_").replace(Regex("[^a-zA-Z0-9_]"), "_").take(27)
        val offset = if (appProcessStartTimeMs > 0) System.currentTimeMillis() - appProcessStartTimeMs else 0L
        var trace: Trace? = null

        try {
            if (isFirebasePerfReady) {
                trace = FirebasePerformance.getInstance().newTrace(cleanName)
                // Exactly 2 attributes to stay well below the 5-attribute limit
                trace.putAttribute("phase", phase.take(40))
                trace.putAttribute("thread", if (isMainThread) "main" else "background")
                trace.start()
            }
        } catch (e: Exception) {
            Log.d(TAG, "Init suspend trace $cleanName start skipped: ${e.message}")
        }

        val start = System.currentTimeMillis()
        var status = "SUCCESS"
        var isSuccess = 1L
        try {
            return block()
        } catch (t: Throwable) {
            status = "FAILED"
            isSuccess = 0L
            throw t
        } finally {
            val duration = System.currentTimeMillis() - start
            try {
                trace?.putMetric("duration_ms", duration)
                trace?.putMetric("start_offset_ms", offset)
                trace?.putMetric("is_main_thread", if (isMainThread) 1L else 0L)
                trace?.putMetric("success", isSuccess)
                trace?.stop()
            } catch (_: Exception) {}

            val record = StartupTraceRecord(
                markerName = cleanName,
                phase = phase,
                durationMs = duration,
                isMainThread = isMainThread,
                startTimeOffsetMs = offset,
                status = status,
                threadName = Thread.currentThread().name
            )

            val current = _startupTraces.value.toMutableList()
            current.add(record)
            _startupTraces.value = current

            val currentOps = _lastOperationTime.value.toMutableMap()
            currentOps[cleanName] = duration
            _lastOperationTime.value = currentOps

            Log.i(TAG, "⏱️ [PerfInit] $cleanName took ${duration}ms [offset=+${offset}ms, BG Thread, phase=$phase, status=$status]")
        }
    }

    /**
     * Record the exact moment the First Screen (HomeScreen) completes its initial paint & measurement.
     * Completes the overall cold_start_to_first_screen_paint trace and logs the full delay attribution breakdown.
     */
    fun recordFirstScreenPainted(
        screenName: String = "HomeScreen",
        activity: Activity? = null
    ) {
        if (firstPaintCompleted) return
        firstPaintCompleted = true

        val now = System.currentTimeMillis()
        val totalColdStartMs = if (appProcessStartTimeMs > 0) now - appProcessStartTimeMs else 0L
        _coldStartTotalDurationMs.value = totalColdStartMs

        val preFirebaseMs = if (firebaseInitTimeMs > 0 && appProcessStartTimeMs > 0) {
            (firebaseInitTimeMs - appProcessStartTimeMs).coerceAtLeast(0L)
        } else 0L

        val mainThreadDelayMs = _startupTraces.value
            .filter { it.isMainThread }
            .sumOf { it.durationMs }

        val bgDurationMs = _startupTraces.value
            .filter { !it.isMainThread }
            .sumOf { it.durationMs }

        try {
            coldStartTrace?.let { trace ->
                trace.putMetric("total_cold_start_ms", totalColdStartMs)
                trace.putMetric("pre_firebase_ms", preFirebaseMs)
                trace.putMetric("main_thread_delay_ms", mainThreadDelayMs)
                trace.putMetric("background_services_time_ms", bgDurationMs)
                trace.putMetric("trace_markers_count", _startupTraces.value.size.toLong())
                // Exactly 2 attributes to stay well below the 5-attribute limit
                trace.putAttribute("first_screen", screenName.take(40))
                trace.putAttribute("rating", when {
                    totalColdStartMs < 800L -> "EXCELLENT"
                    totalColdStartMs < 1500L -> "GOOD"
                    else -> "NEEDS_OPTIMIZATION"
                })
                trace.stop()
            }
        } catch (e: Exception) {
            Log.d(TAG, "Cold start trace stop skipped: ${e.message}")
        }

        // Notify Android OS / Play Vitals
        try {
            activity?.reportFullyDrawn()
        } catch (_: Exception) {}

        val report = buildString {
            appendLine("🏁 ================= APP COLD START & FIRST-SCREEN PAINT REPORT =================")
            appendLine("Total Cold-Start to First Paint: ${totalColdStartMs}ms ($screenName)")
            appendLine("Pre-Firebase Bootstrap Time: ${preFirebaseMs}ms")
            appendLine("Direct Main-Thread Blocking Time: ${mainThreadDelayMs}ms")
            appendLine("Background Services Total: ${bgDurationMs}ms")
            appendLine("--- Trace Markers Breakdown Delaying First Paint ---")
            _startupTraces.value.sortedBy { it.startTimeOffsetMs }.forEach { r ->
                val threadTag = if (r.isMainThread) "🔴 MAIN THREAD" else "🟢 BACKGROUND "
                appendLine("  • [+${r.startTimeOffsetMs.toString().padStart(4)}ms] ${r.markerName.padEnd(28)} : ${r.durationMs.toString().padStart(4)}ms [$threadTag, ${r.phase}, ${r.status}]")
            }
            appendLine("================================================================================")
        }
        Log.i(TAG, report)
    }

    fun clearHistory() {
        blockBuffer.clear()
        _recentJanks.value = emptyList()
        _totalBlockedTimeMs.value = 0L
        _startupTraces.value = emptyList()
        _coldStartTotalDurationMs.value = null
    }
}
