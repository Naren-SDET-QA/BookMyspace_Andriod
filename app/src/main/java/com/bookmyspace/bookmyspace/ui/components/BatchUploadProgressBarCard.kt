package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.util.PhotoStorageManager

/**
 * State representing a multi-image concurrent upload session.
 */
data class BatchUploadState(
    val isUploading: Boolean = false,
    val totalCount: Int = 0,
    val completedCount: Int = 0,
    val failedCount: Int = 0,
    val inFlightCount: Int = 0,
    val overallProgress: Float = 0f,
    val totalSavedBytes: Long = 0L,
    val statusMessage: String = "",
    val activeConcurrency: Int = 3
)

/**
 * Modern M3 Progress Bar Card for concurrent multi-image uploads.
 * Displays overall animated progress, worker threads, individual completion counters,
 * and real-time WebP optimization telemetry.
 */
@Composable
fun BatchUploadProgressBarCard(
    state: BatchUploadState,
    onCancel: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = state.overallProgress.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 350, easing = FastOutSlowInEasing),
        label = "BatchUploadProgressAnimation"
    )

    // Infinite rotation for active upload icon
    val infiniteTransition = rememberInfiniteTransition(label = "UploadRotation")
    val rotationAngle by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "UploadRotate"
    )

    val isFinished = !state.isUploading && (state.completedCount + state.failedCount >= state.totalCount) && state.totalCount > 0

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isFinished) {
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
            } else {
                MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.4f)
            }
        ),
        border = BorderStroke(
            width = 1.dp,
            color = if (isFinished) MaterialTheme.colorScheme.primary.copy(alpha = 0.6f) else MaterialTheme.colorScheme.secondary.copy(alpha = 0.5f)
        ),
        modifier = modifier
            .fillMaxWidth()
            .testTag("batch_upload_progress_bar_card")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Header Row: Status icon, title, completion badge, and action button
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(34.dp)
                            .background(
                                color = if (isFinished) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                                shape = CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        if (state.isUploading) {
                            Icon(
                                imageVector = Icons.Default.Sync,
                                contentDescription = "Uploading",
                                tint = MaterialTheme.colorScheme.onSecondary,
                                modifier = Modifier
                                    .size(18.dp)
                                    .rotate(rotationAngle)
                            )
                        } else if (isFinished) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = "Finished",
                                tint = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.size(20.dp)
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Default.CloudUpload,
                                contentDescription = "Upload",
                                tint = MaterialTheme.colorScheme.onSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }

                    Column {
                        Text(
                            text = if (isFinished) "Batch Upload Complete 🎉" else "Uploading ${state.totalCount} Photos Concurrently",
                            fontSize = 13.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = "${state.completedCount} of ${state.totalCount} completed • ${(animatedProgress * 100).toInt()}%",
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Action button: Cancel while uploading, Dismiss when finished
                if (state.isUploading) {
                    TextButton(
                        onClick = onCancel,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier
                            .height(30.dp)
                            .testTag("batch_upload_cancel_button")
                    ) {
                        Text("Cancel", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.error)
                    }
                } else {
                    IconButton(
                        onClick = onDismiss,
                        modifier = Modifier
                            .size(28.dp)
                            .testTag("batch_upload_dismiss_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Dismiss",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            // High-precision Animated Linear Progress Bar
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                LinearProgressIndicator(
                    progress = { animatedProgress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .testTag("batch_upload_linear_progress_bar"),
                    color = if (isFinished) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant
                )
            }

            // Info Chips & Telemetry: Worker Concurrency & WebP Bandwidth Savings
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Active Concurrency Tag
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = MaterialTheme.colorScheme.surface.copy(alpha = 0.7f),
                    border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Speed,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(12.dp)
                        )
                        Text(
                            text = "${state.activeConcurrency}x Parallel Pipeline",
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                // WebP Optimization savings or status
                if (state.totalSavedBytes > 0) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                    ) {
                        Text(
                            text = "⚡ WebP saved ~${PhotoStorageManager.formatFileSize(state.totalSavedBytes)}",
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        )
                    }
                } else {
                    Text(
                        text = state.statusMessage.ifBlank { "Optimizing high-res images..." },
                        fontSize = 10.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}
