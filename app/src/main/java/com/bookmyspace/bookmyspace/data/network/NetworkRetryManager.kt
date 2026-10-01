package com.bookmyspace.bookmyspace.data.network

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * State representing network & cloud sync operations.
 */
sealed class NetworkSyncState {
    object Idle : NetworkSyncState()
    data class Syncing(val attempt: Int = 1, val message: String = "Connecting to live cloud...") : NetworkSyncState()
    data class Success(val message: String = "Data synchronized", val timestamp: Long = System.currentTimeMillis()) : NetworkSyncState()
    data class Error(
        val errorMessage: String,
        val canRetry: Boolean = true,
        val failedAttempts: Int = 1,
        val timestamp: Long = System.currentTimeMillis()
    ) : NetworkSyncState()
}

/**
 * Robust Network & Firebase Retry Manager that provides exponential backoff,
 * centralized sync status tracking, and recovery handles for the entire app.
 */
object NetworkRetryManager {
    private const val TAG = "NetworkRetryManager"
    private val coroutineScope = CoroutineScope(Dispatchers.IO)

    private val _syncState = MutableStateFlow<NetworkSyncState>(NetworkSyncState.Idle)
    val syncState: StateFlow<NetworkSyncState> = _syncState.asStateFlow()

    private var onGlobalRetryAction: (suspend () -> Unit)? = null

    fun registerGlobalRetryAction(action: suspend () -> Unit) {
        onGlobalRetryAction = action
    }

    fun setSyncState(state: NetworkSyncState) {
        _syncState.value = state
    }

    fun resetToIdle() {
        _syncState.value = NetworkSyncState.Idle
    }

    /**
     * Executes a network or Firebase operation with exponential backoff and error tracking.
     */
    suspend fun <T> executeWithRetry(
        operationName: String = "Network Operation",
        maxRetries: Int = 3,
        initialDelayMs: Long = 800L,
        maxDelayMs: Long = 3000L,
        backoffFactor: Double = 2.0,
        block: suspend () -> T
    ): Result<T> = withContext(Dispatchers.IO) {
        var currentDelay = initialDelayMs
        var lastException: Throwable? = null

        for (attempt in 1..maxRetries) {
            try {
                _syncState.value = NetworkSyncState.Syncing(
                    attempt = attempt,
                    message = if (attempt > 1) "Retrying $operationName (Attempt $attempt of $maxRetries)..." else "Loading live $operationName..."
                )
                val result = block()
                _syncState.value = NetworkSyncState.Success("Synced $operationName successfully")
                return@withContext Result.success(result)
            } catch (e: Throwable) {
                lastException = e
                Log.w(TAG, "[$operationName] Attempt $attempt failed: ${e.message}")
                if (attempt < maxRetries) {
                    delay(currentDelay)
                    currentDelay = (currentDelay * backoffFactor).toLong().coerceAtMost(maxDelayMs)
                }
            }
        }

        val errorMsg = lastException?.message?.ifBlank { null }
            ?: "Unable to connect to live servers. Running in safe offline mode."
        _syncState.value = NetworkSyncState.Error(
            errorMessage = errorMsg,
            canRetry = true,
            failedAttempts = maxRetries
        )
        return@withContext Result.failure(lastException ?: Exception(errorMsg))
    }

    /**
     * Triggers a manual retry of the registered global sync action.
     */
    fun triggerRetry(onComplete: (() -> Unit)? = null) {
        coroutineScope.launch {
            try {
                _syncState.value = NetworkSyncState.Syncing(attempt = 1, message = "Retrying live sync...")
                val action = onGlobalRetryAction
                if (action != null) {
                    action()
                    _syncState.value = NetworkSyncState.Success("Sync restored successfully")
                } else {
                    delay(800L)
                    _syncState.value = NetworkSyncState.Idle
                }
            } catch (e: Exception) {
                Log.e(TAG, "Manual retry failed: ${e.message}", e)
                _syncState.value = NetworkSyncState.Error(
                    errorMessage = e.message ?: "Retry attempt failed. Please verify connection.",
                    canRetry = true
                )
            } finally {
                withContext(Dispatchers.Main) {
                    onComplete?.invoke()
                }
            }
        }
    }
}
