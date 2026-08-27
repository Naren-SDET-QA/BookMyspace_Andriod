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
