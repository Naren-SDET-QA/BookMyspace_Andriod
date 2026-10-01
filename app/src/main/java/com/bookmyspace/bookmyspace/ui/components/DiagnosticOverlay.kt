package com.bookmyspace.bookmyspace.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.diagnostics.BlockDiagnosticRecord
import com.bookmyspace.bookmyspace.data.diagnostics.DiagnosticSeverity
import com.bookmyspace.bookmyspace.data.diagnostics.PerformanceDiagnosticsManager

/**
 * Diagnostic Floating Overlay using Firebase Performance & Watchdog.
 * Identifies UI thread stalls, dropped frames, slow composables, or blocking tasks.
 */
@Composable
fun DiagnosticOverlay(
    modifier: Modifier = Modifier
) {
    val isVisible by PerformanceDiagnosticsManager.isOverlayVisible.collectAsState()
    val janks by PerformanceDiagnosticsManager.recentJanks.collectAsState()
    val fps by PerformanceDiagnosticsManager.currentFpsEstimate.collectAsState()
    val totalBlockedMs by PerformanceDiagnosticsManager.totalBlockedTimeMs.collectAsState()
    val lastOps by PerformanceDiagnosticsManager.lastOperationTime.collectAsState()
    val startupTraces by PerformanceDiagnosticsManager.startupTraces.collectAsState()
    val coldStartDuration by PerformanceDiagnosticsManager.coldStartTotalDurationMs.collectAsState()

    var isExpanded by remember { mutableStateOf(false) }
    var selectedRecord by remember { mutableStateOf<BlockDiagnosticRecord?>(null) }

    if (!isVisible) {
        return
    }

    Box(
        modifier = modifier
            .wrapContentSize()
            .padding(12.dp),
        contentAlignment = Alignment.TopEnd
    ) {
        Column(
            horizontalAlignment = Alignment.End,
            modifier = Modifier.widthIn(max = 340.dp)
        ) {
            // Header Badge / Compact Meter
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = Color(0xFF0F172A).copy(alpha = 0.94f),
                shadowElevation = 8.dp,
                border = androidx.compose.foundation.BorderStroke(
                    width = 1.dp,
                    color = if (janks.any { it.severity == DiagnosticSeverity.CRITICAL }) Color(0xFFEF4444) else Color(0xFF38BDF8)
                ),
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .clickable { isExpanded = !isExpanded }
                    .testTag("diagnostic_overlay_header")
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    // Status pulse dot
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(
                                when {
                                    janks.isEmpty() -> Color(0xFF10B981)
                                    janks.first().severity == DiagnosticSeverity.CRITICAL -> Color(0xFFEF4444)
                                    else -> Color(0xFFF59E0B)
                                }
                            )
                    )

                    // Title with Firebase Perf tag
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Firebase Perf",
                                color = Color(0xFFFBBF24),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "UI Monitor",
                                color = Color.White,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                        Text(
                            text = if (janks.isEmpty()) "UI Thread Healthy (~${fps} FPS)" else "${janks.size} stall(s) | ${totalBlockedMs}ms lost",
                            color = if (janks.isEmpty()) Color(0xFF94A3B8) else Color(0xFFFCA5A5),
                            fontSize = 10.sp,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    Spacer(modifier = Modifier.width(4.dp))

                    Icon(
                        imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                        contentDescription = "Toggle Details",
                        tint = Color(0xFF94A3B8),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Expanded Diagnostic Panel
            AnimatedVisibility(
                visible = isExpanded,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut()
            ) {
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = Color(0xFF0F172A).copy(alpha = 0.96f),
                    shadowElevation = 12.dp,
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF334155)),
                    modifier = Modifier
                        .padding(top = 8.dp)
                        .fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp)
                    ) {
                        // Action row
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "THREAD DIAGNOSTICS",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Black,
                                color = Color(0xFF94A3B8),
                                letterSpacing = 0.5.sp
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                TextButton(
                                    onClick = { PerformanceDiagnosticsManager.clearHistory() },
                                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp)
                                ) {
                                    Text("Clear", fontSize = 11.sp, color = Color(0xFF38BDF8))
                                }
                                IconButton(
                                    onClick = { PerformanceDiagnosticsManager.setOverlayVisible(false) },
                                    modifier = Modifier.size(24.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Close,
                                        contentDescription = "Hide",
                                        tint = Color(0xFF94A3B8),
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                        }

                        Divider(color = Color(0xFF334155), thickness = 0.5.dp, modifier = Modifier.padding(vertical = 6.dp))

                        // Stats Grid
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceAround
                        ) {
                            MetricItem("Target FPS", "60")
                            MetricItem("Est. FPS", "$fps")
                            MetricItem("Total Stalls", "${janks.size}")
                            MetricItem("Blocked", "${totalBlockedMs}ms")
                        }

                        if (lastOps.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Active Firebase Traces:",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFFCBD5E1)
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            lastOps.forEach { (name, ms) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(
                                        text = name,
                                        fontSize = 10.sp,
                                        color = Color(0xFF94A3B8),
                                        fontFamily = FontFamily.Monospace,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                        modifier = Modifier.weight(1f)
                                    )
                                    Text(
                                        text = "${ms}ms",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (ms > 50) Color(0xFFEF4444) else Color(0xFF10B981),
                                        fontFamily = FontFamily.Monospace
                                    )
                                }
                            }
                        }

                        if (startupTraces.isNotEmpty() || coldStartDuration != null) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Startup & First Paint:",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFFBBF24)
                                )
                                Text(
                                    text = if (coldStartDuration != null) "${coldStartDuration}ms" else "Measuring...",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF38BDF8),
                                    fontFamily = FontFamily.Monospace
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))

                            Column(
                                verticalArrangement = Arrangement.spacedBy(2.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                startupTraces.forEach { trace ->
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Box(
                                                modifier = Modifier
                                                    .size(6.dp)
                                                    .clip(CircleShape)
                                                    .background(if (trace.isMainThread) Color(0xFFEF4444) else Color(0xFF10B981))
                                            )
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text(
                                                text = trace.markerName.removePrefix("init_"),
                                                fontSize = 9.sp,
                                                color = Color(0xFFCBD5E1),
                                                fontFamily = FontFamily.Monospace,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis
                                            )
                                        }
                                        Text(
                                            text = "${trace.durationMs}ms",
                                            fontSize = 9.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = if (trace.isMainThread && trace.durationMs > 50) Color(0xFFEF4444) else Color(0xFF94A3B8),
                                            fontFamily = FontFamily.Monospace
                                        )
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Text(
                            text = "Detected UI Blocks (Watchdog):",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFFCBD5E1)
                        )

                        Spacer(modifier = Modifier.height(4.dp))

                        if (janks.isEmpty()) {
                            Text(
                                text = "No UI thread hangs detected. Main loop executing smoothly without frame drops.",
                                fontSize = 10.sp,
                                color = Color(0xFF64748B),
                                modifier = Modifier.padding(vertical = 8.dp)
                            )
                        } else {
                            LazyColumn(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .heightIn(max = 160.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                items(janks) { record ->
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = if (record.severity == DiagnosticSeverity.CRITICAL) Color(0xFF450A0A) else Color(0xFF1E293B),
                                        border = androidx.compose.foundation.BorderStroke(
                                            0.5.dp,
                                            if (record.severity == DiagnosticSeverity.CRITICAL) Color(0xFFDC2626) else Color(0xFF475569)
                                        ),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable {
                                                selectedRecord = if (selectedRecord == record) null else record
                                            }
                                    ) {
                                        Column(modifier = Modifier.padding(8.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Text(
                                                    text = record.source,
                                                    fontSize = 11.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = Color.White
                                                )
                                                Text(
                                                    text = "+${record.durationMs}ms stall",
                                                    fontSize = 11.sp,
                                                    fontWeight = FontWeight.Black,
                                                    color = if (record.severity == DiagnosticSeverity.CRITICAL) Color(0xFFF87171) else Color(0xFFFBBF24),
                                                    fontFamily = FontFamily.Monospace
                                                )
                                            }

                                            if (selectedRecord == record && record.stackTraceSnippet.isNotBlank()) {
                                                Spacer(modifier = Modifier.height(4.dp))
                                                Text(
                                                    text = record.stackTraceSnippet,
                                                    fontSize = 9.sp,
                                                    fontFamily = FontFamily.Monospace,
                                                    color = Color(0xFFCBD5E1),
                                                    lineHeight = 12.sp
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MetricItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = value, fontSize = 13.sp, fontWeight = FontWeight.Black, color = Color.White, fontFamily = FontFamily.Monospace)
        Text(text = label, fontSize = 9.sp, color = Color(0xFF94A3B8))
    }
}
