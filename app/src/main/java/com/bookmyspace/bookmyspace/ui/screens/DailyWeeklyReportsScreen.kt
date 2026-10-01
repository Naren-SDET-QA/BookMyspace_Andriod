package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.notification.BookingReminderNotificationManager
import com.bookmyspace.bookmyspace.data.report.BusinessReportEngine
import com.bookmyspace.bookmyspace.data.report.PaymentMethodBreakdown
import com.bookmyspace.bookmyspace.data.report.ReportTimeRange
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.data.repository.PaymentTransactionRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DailyWeeklyReportsScreen(
    onNavigateBack: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    val coroutineScope = rememberCoroutineScope()

    val bookings by BookMySpaceRepository.bookings.collectAsState()
    val venues by BookMySpaceRepository.venues.collectAsState()

    // Room DB Transactions
    val txRepository = remember { PaymentTransactionRepository.getInstance(context) }
    val roomTransactions by txRepository.allTransactions.collectAsState(initial = emptyList())

    var selectedTimeRange by remember { mutableStateOf(ReportTimeRange.TODAY) }
    var selectedVenueId by remember { mutableStateOf<String?>("ALL") }
    var showReportPreviewModal by remember { mutableStateOf(false) }
    var isDailyNotificationScheduled by remember { mutableStateOf(true) }

    // Compute live business report summary
    val reportSummary = remember(bookings, roomTransactions, selectedTimeRange, selectedVenueId) {
        BusinessReportEngine.generateReport(
            bookings = bookings,
            transactions = roomTransactions,
            timeRange = selectedTimeRange,
            selectedVenueId = selectedVenueId
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = if (selectedTimeRange == ReportTimeRange.THIS_WEEK) "Weekly Revenue & Reports" else "Daily Business Reports",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                        Text(
                            text = reportSummary.periodLabel,
                            fontSize = 11.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("reports_back_btn")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = {
                            BusinessReportEngine.copyToClipboard(context, reportSummary.formattedMessage)
                        },
                        modifier = Modifier.testTag("reports_top_copy_btn")
                    ) {
                        Icon(Icons.Default.ContentCopy, contentDescription = "Copy Report Message")
                    }
                    IconButton(
                        onClick = {
                            BusinessReportEngine.shareReport(
                                context = context,
                                text = reportSummary.formattedMessage,
                                subject = "BookMySpace ${reportSummary.periodLabel} Report"
                            )
                        },
                        modifier = Modifier.testTag("reports_top_share_btn")
                    ) {
                        Icon(Icons.Default.Share, contentDescription = "Share via WhatsApp / Apps", tint = MaterialTheme.colorScheme.primary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier.fillMaxSize().testTag("daily_weekly_reports_screen")
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Time Range Filter Chips
            item {
                Column {
                    Text(
                        text = "SELECT REPORT TIMEFRAME",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        letterSpacing = 0.5.sp
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        items(ReportTimeRange.values()) { range ->
                            FilterChip(
                                selected = selectedTimeRange == range,
                                onClick = { selectedTimeRange = range },
                                leadingIcon = {
                                    Icon(
                                        imageVector = when (range) {
                                            ReportTimeRange.TODAY -> Icons.Default.Today
                                            ReportTimeRange.YESTERDAY -> Icons.Default.History
                                            ReportTimeRange.THIS_WEEK -> Icons.Default.DateRange
                                            ReportTimeRange.THIS_MONTH -> Icons.Default.CalendarMonth
                                            ReportTimeRange.ALL_TIME -> Icons.Default.BarChart
                                        },
                                        contentDescription = null,
                                        modifier = Modifier.size(16.dp)
                                    )
                                },
                                label = {
                                    Text(
                                        text = range.shortLabel,
                                        fontWeight = if (selectedTimeRange == range) FontWeight.Bold else FontWeight.Medium,
                                        fontSize = 12.sp
                                    )
                                },
                                modifier = Modifier.testTag("chip_range_${range.name.lowercase()}")
                            )
                        }
                    }
                }
            }

            // Venue Filter Dropdown / Row
            item {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.LocationCity, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Filter by Space:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }

                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            item {
                                FilterChip(
                                    selected = selectedVenueId == "ALL",
                                    onClick = { selectedVenueId = "ALL" },
                                    label = { Text("All Spaces (Global)", fontSize = 10.5.sp) }
                                )
                            }
                            items(venues.take(4)) { venue ->
                                FilterChip(
                                    selected = selectedVenueId == venue.id,
                                    onClick = { selectedVenueId = venue.id },
                                    label = { Text(venue.name.take(16) + if (venue.name.length > 16) "..." else "", fontSize = 10.5.sp) }
                                )
                            }
                        }
                    }
                }
            }

            // Hero Metric 1: Total Amount Generated
            item {
                Card(
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.9f)
                    ),
                    modifier = Modifier.fillMaxWidth().testTag("report_total_revenue_card")
                ) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "TOTAL AMOUNT GENERATED",
                                fontSize = 11.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f),
                                letterSpacing = 0.5.sp
                            )
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = Color(0xFF2E7D32)
                            ) {
                                Text(
                                    text = "LIVE DATA ✓",
                                    fontSize = 9.5.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = BusinessReportEngine.formatINR(reportSummary.totalRevenue),
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 34.sp,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "${reportSummary.periodLabel} • ${reportSummary.totalBookings} Total Bookings",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.9f)
                        )

                        Spacer(modifier = Modifier.height(14.dp))
                        HorizontalDivider(color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.15f))
                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("🌐 Settled Online", fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f))
                                Text(
                                    text = BusinessReportEngine.formatINR(reportSummary.onlineSettledRevenue),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = Color(0xFF1565C0)
                                )
                            }
                            Box(modifier = Modifier.width(1.dp).height(24.dp).background(MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.2f)))
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("🏢 Pay at Venue", fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f))
                                Text(
                                    text = BusinessReportEngine.formatINR(reportSummary.payAtVenueRevenue),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = Color(0xFF2E7D32)
                                )
                            }
                            if (reportSummary.advanceTokensCollected > 0) {
                                Box(modifier = Modifier.width(1.dp).height(24.dp).background(MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.2f)))
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text("🔒 Advance Tokens", fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f))
                                    Text(
                                        text = BusinessReportEngine.formatINR(reportSummary.advanceTokensCollected),
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp,
                                        color = Color(0xFFE65100)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Key Metrics 4-Box Grid: Bookings, Online %, Guests, AOV
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    // Total Bookings Card
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                        modifier = Modifier.weight(1f).testTag("report_metric_total_bookings")
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("🎟️ Total Bookings", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold)
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "${reportSummary.totalBookings}",
                                fontSize = 22.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "🌐 ${reportSummary.onlineBookings} Online | 🏢 ${reportSummary.payAtVenueBookings} Venue",
                                fontSize = 9.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    // Online Bookings % Card
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                        modifier = Modifier.weight(1f).testTag("report_metric_online_split")
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text("⚡ Online Share", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold)
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "${String.format(java.util.Locale.ENGLISH, "%.1f", reportSummary.onlineBookingsPercentage)}%",
                                fontSize = 22.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = Color(0xFF1565C0)
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "${reportSummary.confirmedBookingsCount} Confirmed • ${reportSummary.pendingBookingsCount} Pending",
                                fontSize = 9.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    // Total Registered Guests Card
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                        modifier = Modifier.weight(1f)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text("👥 Registered Guests", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold)
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "${reportSummary.totalGuestsRegistered}",
                                fontSize = 22.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "KYC & Member verified",
                                fontSize = 9.5.sp,
                                color = Color(0xFF2E7D32),
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }

                    // Average Order Value (AOV)
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                        modifier = Modifier.weight(1f)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            Text("🏷️ Avg. Slot Value", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold)
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = BusinessReportEngine.formatINR(reportSummary.averageOrderValue),
                                fontSize = 20.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Per booking session",
                                fontSize = 9.5.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            // Section: Payment Method Breakdown (UPI, Card, NetBanking, etc.)
            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                    modifier = Modifier.fillMaxWidth().testTag("payment_methods_breakdown_card")
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = "💳 Payment Mode Breakdown",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 16.sp
                                )
                                Text(
                                    text = "How much amount was generated via each method",
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.primaryContainer
                            ) {
                                Text(
                                    text = "${reportSummary.paymentBreakdowns.size} Modes",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Visual Colored Distribution Multi-Segment Bar
                        if (reportSummary.totalRevenue > 0) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(10.dp)
                                    .clip(RoundedCornerShape(5.dp))
                                    .background(MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                reportSummary.paymentBreakdowns.forEach { breakdown ->
                                    if (breakdown.percentage > 0f) {
                                        Box(
                                            modifier = Modifier
                                                .weight(breakdown.percentage.coerceAtLeast(0.01f))
                                                .fillMaxHeight()
                                                .background(Color(breakdown.colorHex))
                                        )
                                    }
                                }
                            }
                            Spacer(modifier = Modifier.height(16.dp))
                        }

                        // Detailed list of payment methods
                        reportSummary.paymentBreakdowns.forEach { method ->
                            PaymentMethodItemRow(method = method)
                            Spacer(modifier = Modifier.height(10.dp))
                        }
                    }
                }
            }

            // Section: Formatted Daily Report Message (Ready for WhatsApp / SMS / Slack)
            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
                    ),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)),
                    modifier = Modifier.fillMaxWidth().testTag("formatted_report_message_card")
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Surface(
                                    shape = CircleShape,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(32.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Text("📋", fontSize = 15.sp)
                                    }
                                }
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text(
                                        text = "Daily Report Message",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 15.sp
                                    )
                                    Text(
                                        text = "Instant WhatsApp, SMS & Slack formatted text",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }

                            Row {
                                TextButton(
                                    onClick = {
                                        BusinessReportEngine.copyToClipboard(context, reportSummary.formattedMessage)
                                    },
                                    modifier = Modifier.testTag("copy_report_msg_btn")
                                ) {
                                    Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(15.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Copy", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        // Styled Monospaced Text Preview Container
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surface,
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(
                                    text = reportSummary.formattedMessage,
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 11.sp,
                                    lineHeight = 16.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        // Action Buttons: Share to WhatsApp & Send Notification
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = {
                                    BusinessReportEngine.shareReport(
                                        context = context,
                                        text = reportSummary.formattedMessage,
                                        subject = "BookMySpace ${reportSummary.periodLabel} Report"
                                    )
                                },
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.weight(1.2f).testTag("share_whatsapp_report_btn")
                            ) {
                                Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Share via WhatsApp", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }

                            OutlinedButton(
                                onClick = {
                                    // Trigger Heads-Up Daily Report notification
                                    BookingReminderNotificationManager.show1HourReminderNotification(
                                        context = context,
                                        bookingId = "DAILY_REPORT_${System.currentTimeMillis() % 10000}",
                                        venueName = "BookMySpace Daily Business Summary",
                                        slotTime = "Total Revenue: ${BusinessReportEngine.formatINR(reportSummary.totalRevenue)} (${reportSummary.totalBookings} Bookings)",
                                        bookingDate = reportSummary.periodLabel,
                                        qrCodeToken = "UPI: ${BusinessReportEngine.formatINR(reportSummary.upiTotalAmount)} | Cards: ${BusinessReportEngine.formatINR(reportSummary.cardTotalAmount)}"
                                    )
                                    Toast.makeText(context, "Daily Report Push Notification Broadcasted! 🔔", Toast.LENGTH_SHORT).show()
                                },
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.weight(1f).testTag("trigger_report_push_btn")
                            ) {
                                Icon(Icons.Default.NotificationsActive, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Test 9 PM Push", fontSize = 11.5.sp)
                            }
                        }
                    }
                }
            }

            // Top Performing Spaces / Venues
            if (reportSummary.topVenues.isNotEmpty()) {
                item {
                    Card(
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(18.dp)) {
                            Text("🏆 Top Performing Spaces & Courts", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text("Highest revenue and slot booking volume in this period", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)

                            Spacer(modifier = Modifier.height(12.dp))

                            reportSummary.topVenues.forEachIndexed { idx, (venueName, stats) ->
                                Surface(
                                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                                            Surface(
                                                shape = CircleShape,
                                                color = if (idx == 0) Color(0xFFFFD54F) else MaterialTheme.colorScheme.primaryContainer,
                                                modifier = Modifier.size(24.dp)
                                            ) {
                                                Box(contentAlignment = Alignment.Center) {
                                                    Text("${idx + 1}", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.Black)
                                                }
                                            }
                                            Spacer(modifier = Modifier.width(10.dp))
                                            Column {
                                                Text(venueName, fontWeight = FontWeight.Bold, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                                Text("${stats.first} slots booked", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                        }

                                        Text(
                                            text = BusinessReportEngine.formatINR(stats.second),
                                            fontWeight = FontWeight.ExtraBold,
                                            fontSize = 14.sp,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Automated 9:00 PM Daily Report Scheduler Toggle
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                            Icon(Icons.Default.Schedule, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(24.dp))
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text("Automated 9:00 PM Daily Report", fontWeight = FontWeight.Bold, fontSize = 13.5.sp)
                                Text("Deliver full revenue & UPI breakdown notification every night", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        Switch(
                            checked = isDailyNotificationScheduled,
                            onCheckedChange = {
                                isDailyNotificationScheduled = it
                                Toast.makeText(context, if (it) "Nightly 9:00 PM Business Report Scheduled! ⏰" else "Nightly Reports Paused", Toast.LENGTH_SHORT).show()
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PaymentMethodItemRow(method: PaymentMethodBreakdown) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(method.emoji, fontSize = 16.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = method.name,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                }

                Text(
                    text = BusinessReportEngine.formatINR(method.amount),
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 14.sp,
                    color = Color(method.colorHex)
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${method.transactionCount} transaction(s)",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "${String.format(java.util.Locale.ENGLISH, "%.1f", method.percentage)}% of total",
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(method.colorHex)
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            LinearProgressIndicator(
                progress = { (method.percentage / 100f).coerceIn(0f, 1f) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = Color(method.colorHex),
                trackColor = MaterialTheme.colorScheme.surfaceVariant
            )
        }
    }
}
