package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.network.NetworkRetryManager
import com.bookmyspace.bookmyspace.data.network.NetworkSyncState

@Composable
fun NetworkErrorRetryCard(
    syncState: NetworkSyncState.Error,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
    onUseOfflineMode: (() -> Unit)? = null,
    isRetrying: Boolean = false,
    title: String = "Unable to Load Live Data"
) {
    NetworkErrorRetryCard(
        errorMessage = syncState.errorMessage,
        onRetry = onRetry,
        modifier = modifier,
        onFallbackOffline = onUseOfflineMode,
        isRetrying = isRetrying,
        title = title
    )
}

/**
 * Visual 'Retry' Card shown prominently when network, Firebase, or content operations fail.
 * Allows users to manually retry the request or switch seamlessly to local offline mode.
 */
@Composable
fun NetworkErrorRetryCard(
    errorMessage: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
    onFallbackOffline: (() -> Unit)? = null,
    isRetrying: Boolean = false,
    title: String = "Unable to Load Live Data"
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.85f),
            contentColor = MaterialTheme.colorScheme.onErrorContainer
        ),
        border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.5f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = modifier
            .fillMaxWidth()
            .testTag("network_error_retry_card")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.error.copy(alpha = 0.15f),
                modifier = Modifier.size(56.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Default.CloudOff,
                        contentDescription = "Cloud connection issue",
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(32.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = errorMessage.ifBlank { "Could not connect to live servers. Please check your internet or retry." },
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onErrorContainer.copy(alpha = 0.85f),
                modifier = Modifier.padding(horizontal = 8.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Primary Visual Retry Button
                Button(
                    onClick = onRetry,
                    enabled = !isRetrying,
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error,
                        contentColor = MaterialTheme.colorScheme.onError
                    ),
                    modifier = Modifier
                        .defaultMinSize(minHeight = 44.dp)
                        .testTag("network_retry_button")
                ) {
                    if (isRetrying) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = MaterialTheme.colorScheme.onError,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Retrying...", fontWeight = FontWeight.Bold)
                    } else {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Retry Button Icon",
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Retry Now", fontWeight = FontWeight.Bold)
                    }
                }

                // Fallback to Offline / Safe Cache Option
                if (onFallbackOffline != null) {
                    OutlinedButton(
                        onClick = onFallbackOffline,
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.onErrorContainer
                        ),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.onErrorContainer.copy(alpha = 0.4f)),
                        modifier = Modifier
                            .defaultMinSize(minHeight = 44.dp)
                            .testTag("offline_fallback_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.OfflinePin,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Use Offline", fontWeight = FontWeight.Medium)
                    }
                }
            }
        }
    }
}

/**
 * Compact top floating bar shown when network sync is in error state or retrying.
 */
@Composable
fun NetworkSyncStatusBanner(
    syncState: NetworkSyncState,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null
) {
    AnimatedVisibility(
        visible = syncState is NetworkSyncState.Error || syncState is NetworkSyncState.Syncing,
        enter = expandVertically() + fadeIn(),
        exit = shrinkVertically() + fadeOut(),
        modifier = modifier
    ) {
        val isError = syncState is NetworkSyncState.Error
        val isSyncing = syncState is NetworkSyncState.Syncing

        Surface(
            shape = RoundedCornerShape(12.dp),
            color = if (isError) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.primaryContainer,
            contentColor = if (isError) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onPrimaryContainer,
            shadowElevation = 4.dp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 6.dp)
                .testTag("network_sync_status_banner")
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    if (isSyncing) {
                        val infiniteTransition = rememberInfiniteTransition(label = "spin")
                        val rotation by infiniteTransition.animateFloat(
                            initialValue = 0f,
                            targetValue = 360f,
                            animationSpec = infiniteRepeatable(
                                animation = tween(1000, easing = LinearEasing),
                                repeatMode = RepeatMode.Restart
                            ),
                            label = "spin_angle"
                        )
                        Icon(
                            imageVector = Icons.Default.Sync,
                            contentDescription = "Syncing",
                            modifier = Modifier
                                .size(20.dp)
                                .rotate(rotation),
                            tint = MaterialTheme.colorScheme.primary
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.CloudOff,
                            contentDescription = "Sync Error",
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.error
                        )
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    Text(
                        text = when (syncState) {
                            is NetworkSyncState.Syncing -> syncState.message
                            is NetworkSyncState.Error -> syncState.errorMessage
                            else -> "Network status updated"
                        },
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                        maxLines = 2
                    )
                }

                if (isError) {
                    IconButton(
                        onClick = onRetry,
                        modifier = Modifier
                            .size(36.dp)
                            .testTag("banner_retry_icon_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Retry sync",
                            tint = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }
        }
    }
}
