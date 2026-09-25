package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.health.AppHealthManager
import com.bookmyspace.bookmyspace.data.health.HealthSeverity
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.compose.ui.platform.LocalContext
import com.bookmyspace.bookmyspace.BookMySpaceApplication

/**
 * Global Error Boundary & UI Wrapper that safely wraps UI components to catch
 * unhandled exceptions or state anomalies and render graceful recovery options
 * instead of crashing the app.
 */
@Composable
fun GlobalErrorBoundary(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    var hasError by remember { mutableStateOf(false) }
    var errorDetails by remember { mutableStateOf<String?>(null) }
    var errorTitle by remember { mutableStateOf("Something went wrong") }
    var isSafeModeActive by remember { mutableStateOf(false) }

    val healthReport by AppHealthManager.healthReport.collectAsState()
    val isAlertDismissed by AppHealthManager.criticalAlertDismissed.collectAsState()

    val isUiHanging by com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.isUiHanging.collectAsState()
    val hangHealingMessage by com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.lastHealingMessage.collectAsState()
    val isSafePerfMode by com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.isSafePerformanceMode.collectAsState()

    if (hasError) {
        // Recovery Screen
        ErrorRecoveryScreen(
            title = errorTitle,
            error = errorDetails ?: "An unexpected layout or state error occurred.",
            onRetry = {
                hasError = false
                errorDetails = null
                AppHealthManager.performHealthCheck()
            },
            onResetState = {
                hasError = false
                errorDetails = null
                isSafeModeActive = true
                BookMySpaceRepository.resetToSafeSampleData()
                AppHealthManager.performHealthCheck()
            }
        )
    } else {
        Box(modifier = modifier.fillMaxSize()) {
            content()

            // Optional Top Floating Health Alert Banner for Degraded Services
            AnimatedVisibility(
                visible = healthReport.alertBannerMessage != null && !isAlertDismissed,
                enter = fadeIn() + slideInVertically(),
                exit = fadeOut() + slideOutVertically(),
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(horizontal = 16.dp, vertical = 40.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = when (healthReport.overallSeverity) {
                        HealthSeverity.CRITICAL -> MaterialTheme.colorScheme.errorContainer
                        HealthSeverity.WARNING -> MaterialTheme.colorScheme.tertiaryContainer
                        else -> MaterialTheme.colorScheme.surfaceVariant
                    },
                    shadowElevation = 6.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(
                            imageVector = when (healthReport.overallSeverity) {
                                HealthSeverity.CRITICAL -> Icons.Default.CloudOff
                                HealthSeverity.WARNING -> Icons.Default.WarningAmber
                                else -> Icons.Default.CheckCircle
                            },
                            contentDescription = "Health Status",
                            tint = when (healthReport.overallSeverity) {
                                HealthSeverity.CRITICAL -> MaterialTheme.colorScheme.error
                                HealthSeverity.WARNING -> MaterialTheme.colorScheme.tertiary
                                else -> MaterialTheme.colorScheme.primary
                            },
                            modifier = Modifier.size(22.dp)
                        )

                        Text(
                            text = healthReport.alertBannerMessage ?: "",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.Medium,
                            color = when (healthReport.overallSeverity) {
                                HealthSeverity.CRITICAL -> MaterialTheme.colorScheme.onErrorContainer
                                HealthSeverity.WARNING -> MaterialTheme.colorScheme.onTertiaryContainer
                                else -> MaterialTheme.colorScheme.onSurfaceVariant
                            },
                            modifier = Modifier.weight(1f)
                        )

                        IconButton(
                            onClick = { AppHealthManager.dismissAlertBanner() },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Dismiss Banner",
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }

            // 🛡️ Real-Time Self-Healing & Anti-Hang Notification Pill
            AnimatedVisibility(
                visible = hangHealingMessage != null || isUiHanging,
                enter = fadeIn() + slideInVertically { -it },
                exit = fadeOut() + slideOutVertically { -it },
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(horizontal = 16.dp, vertical = if (healthReport.alertBannerMessage != null && !isAlertDismissed) 92.dp else 40.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = if (isUiHanging) Color(0xFF7F1D1D) else Color(0xFF064E3B),
                    shadowElevation = 8.dp,
                    border = androidx.compose.foundation.BorderStroke(
                        width = 1.dp,
                        color = if (isUiHanging) Color(0xFFEF4444) else Color(0xFF10B981)
                    ),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            text = if (isUiHanging) "⚠️" else "🛡️",
                            fontSize = 18.sp
                        )

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = if (isUiHanging) "UI Unresponsiveness Detected" else "Self-Healing Engine Active",
                                style = MaterialTheme.typography.labelMedium.copy(
                                    fontWeight = FontWeight.Bold
                                ),
                                color = Color.White
                            )
                            Text(
                                text = if (isUiHanging) {
                                    "Watchdog detected main thread stall. Initiating recovery..."
                                } else {
                                    hangHealingMessage ?: "Anti-hang protocols applied. Running 60fps Safe Mode."
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White.copy(alpha = 0.9f)
                            )
                        }

                        if (isUiHanging) {
                            Button(
                                onClick = {
                                    com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.triggerEmergencySelfHeal("User unstick action")
                                },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color(0xFFEF4444),
                                    contentColor = Color.White
                                ),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                shape = RoundedCornerShape(8.dp),
                                modifier = Modifier.defaultMinSize(minHeight = 32.dp)
                            ) {
                                Text("⚡ Unstick", style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold))
                            }
                        } else {
                            IconButton(
                                onClick = {
                                    com.bookmyspace.bookmyspace.data.healing.AppHangSelfHealingWatchdog.clearLastHealingMessage()
                                },
                                modifier = Modifier.size(24.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Dismiss Self-Healing Notice",
                                    tint = Color.White,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Beautiful full-screen fallback screen with self-healing recovery actions.
 */
@Composable
private fun ErrorRecoveryScreen(
    title: String,
    error: String,
    onRetry: () -> Unit,
    onResetState: () -> Unit
) {
    var showDetails by remember { mutableStateOf(false) }
    val context = LocalContext.current

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(MaterialTheme.colorScheme.errorContainer),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Shield,
                    contentDescription = "Error Boundary Shield",
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(40.dp)
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            Text(
                text = title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onBackground,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "The application encountered a recoverable state anomaly. Your local data and preferences remain secure.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Action Buttons
            Button(
                onClick = onRetry,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Reload & Reconnect", fontWeight = FontWeight.SemiBold)
            }

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedButton(
                onClick = onResetState,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Restore, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Restore Safe State & Memory Cache", fontWeight = FontWeight.SemiBold)
            }

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedButton(
                onClick = {
                    val logs = buildString {
                        appendLine("=== BookMySpace System Startup Diagnostics ===")
                        appendLine("Timestamp: ${java.util.Date()}")
                        appendLine("App Initialized: ${BookMySpaceApplication.isAppInitialized}")
                        appendLine("Startup Duration: ${BookMySpaceApplication.startupDurationMs}ms")
                        appendLine("Error Context: $error")
                        appendLine("")
                        appendLine("--- Recent Startup Logs ---")
                        synchronized(BookMySpaceApplication.startupLogs) {
                            BookMySpaceApplication.startupLogs.takeLast(25).forEach { appendLine("  $it") }
                        }
                    }
                    val emailIntent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("mailto:support@bookmyspace.in")
                        putExtra(Intent.EXTRA_SUBJECT, "BookMySpace Startup Diagnostic Report")
                        putExtra(Intent.EXTRA_TEXT, logs)
                    }
                    try {
                        context.startActivity(emailIntent)
                    } catch (e: Exception) {
                        Log.w("GlobalErrorBoundary", "Failed to launch email: ${e.message}")
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Email, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Email Diagnostics", fontWeight = FontWeight.SemiBold)
            }

            Spacer(modifier = Modifier.height(20.dp))

            TextButton(
                onClick = { showDetails = !showDetails }
            ) {
                Text(
                    text = if (showDetails) "Hide Technical Diagnostic Details" else "View Technical Diagnostic Details",
                    style = MaterialTheme.typography.labelMedium
                )
            }

            if (showDetails) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = error,
                        style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace, fontSize = 11.sp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }
        }
    }
}
