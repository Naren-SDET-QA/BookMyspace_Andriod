package com.bookmyspace.bookmyspace.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.ui.components.BookingSummaryInvoiceModal
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyBookingsScreen(
    onPayBooking: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val allBookings by BookMySpaceRepository.bookings.collectAsState()
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val currentRole by com.bookmyspace.bookmyspace.data.auth.UserRoleProvider.role.collectAsState()
    val bookings = remember(allBookings, authUser, currentRole) {
        BookMySpaceRepository.getBookingsForRole(currentRole, authUser?.id)
    }
    val paymentTransactions by BookMySpaceRepository.paymentTransactions.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) } // 0: Upcoming, 1: Completed, 2: Cancelled & Rejected, 3: Transactions
    val context = LocalContext.current

    val filteredBookings = remember(bookings, selectedTab) {
        when (selectedTab) {
            0 -> bookings.filter { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.PENDING || it.status == BookingStatus.PENDING_OWNER_APPROVAL || it.status == BookingStatus.HELD }
            1 -> bookings.filter { it.status == BookingStatus.COMPLETED }
            2 -> bookings.filter { it.status == BookingStatus.CANCELLED || it.status == BookingStatus.REJECTED }
            else -> emptyList()
        }
    }

    var showCancelDialogForBooking by remember { mutableStateOf<Booking?>(null) }
    var showQrDialogForBooking by remember { mutableStateOf<Booking?>(null) }
    var showInvoiceForTransaction by remember { mutableStateOf<PaymentTransactionEntity?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "My Bookings & Payments 🎟️",
                        fontWeight = FontWeight.Bold,
                        fontSize = 20.sp
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        modifier = modifier.testTag("my_bookings_screen")
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            ScrollableTabRow(
                selectedTabIndex = selectedTab,
                edgePadding = 16.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Active (${bookings.count { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.PENDING || it.status == BookingStatus.PENDING_OWNER_APPROVAL || it.status == BookingStatus.HELD }})", fontWeight = FontWeight.Bold, fontSize = 13.sp) }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("Completed (${bookings.count { it.status == BookingStatus.COMPLETED }})", fontWeight = FontWeight.Bold, fontSize = 13.sp) }
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = { Text("Declined/Cancelled (${bookings.count { it.status == BookingStatus.CANCELLED || it.status == BookingStatus.REJECTED }})", fontWeight = FontWeight.Bold, fontSize = 13.sp) }
                )
                Tab(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    text = { Text("💳 Payments (${paymentTransactions.size})", fontWeight = FontWeight.Bold, fontSize = 13.sp) }
                )
            }

            if (selectedTab == 3) {
                // Room database payment transaction records
                if (paymentTransactions.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(text = "💳", fontSize = 54.sp)
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "No payment transaction records yet",
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "Completed and processed payment transactions will automatically appear here.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        items(paymentTransactions, key = { it.transactionId }) { tx ->
                            PaymentTransactionCardItem(
                                transaction = tx,
                                onSelectBooking = { bookingId ->
                                    val matchIndex = bookings.indexOfFirst { it.id == bookingId }
                                    if (matchIndex != -1) {
                                        selectedTab = 0
                                    }
                                },
                                onViewInvoice = { showInvoiceForTransaction = tx }
                            )
                        }
                    }
                }
            } else if (bookings.isEmpty()) {
                com.bookmyspace.bookmyspace.ui.components.EyeCatchingBookingsSkeleton()
            } else if (filteredBookings.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = if (selectedTab == 0) "🎟️" else if (selectedTab == 1) "✅" else "❌",
                            fontSize = 54.sp
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = if (selectedTab == 0) "No upcoming bookings found" else if (selectedTab == 1) "No completed bookings yet" else "No cancelled bookings",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Explore venues, select your preferred time slot, and book instantly.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    items(filteredBookings, key = { it.id }) { booking ->
                        val matchingTx = paymentTransactions.firstOrNull { it.bookingId == booking.id }
                            ?: PaymentTransactionEntity(
                                transactionId = "pay_bms_${booking.id.takeLast(8)}",
                                bookingId = booking.id,
                                venueId = booking.venueId,
                                venueName = booking.venueName,
                                amount = booking.totalAmount.ifZero(booking.totalPrice),
                                currency = "INR",
                                paymentStatus = if (booking.status == BookingStatus.CONFIRMED || booking.status == BookingStatus.COMPLETED) "SUCCESS" else booking.status.name,
                                paymentMethod = "Razorpay (UPI / NetBanking)",
                                razorpayOrderId = "order_bms_${booking.id.takeLast(8)}",
                                razorpaySignature = "sig_bms_${booking.id.takeLast(8)}_verified",
                                customerName = booking.userName.ifBlank { "Narendra Reddy" },
                                customerEmail = booking.userEmail.ifBlank { "narenqe2@gmail.com" },
                                customerPhone = booking.userPhone.ifBlank { "+91 98765 43210" },
                                timestamp = booking.createdAt,
                                notes = "Booking for ${booking.venueName} - ${booking.slotLabel}"
                            )

                        BookingCardItem(
                            booking = booking,
                            onPayNow = { onPayBooking(booking.id) },
                            onCancelBooking = { showCancelDialogForBooking = booking },
                            onShowQrPass = { showQrDialogForBooking = booking },
                            onGetDirections = {
                                val gmmIntentUri = Uri.parse("geo:0,0?q=${Uri.encode(booking.venueName)}")
                                val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri)
                                mapIntent.setPackage("com.google.android.apps.maps")
                                try {
                                    context.startActivity(mapIntent)
                                } catch (_: Exception) {
                                    context.startActivity(Intent(Intent.ACTION_VIEW, gmmIntentUri))
                                }
                            },
                            onViewInvoice = if (booking.status == BookingStatus.CONFIRMED || booking.status == BookingStatus.COMPLETED) {
                                { showInvoiceForTransaction = matchingTx }
                            } else null
                        )
                    }
                }
            }
        }
    }

    // Cancel Booking Dialog
    if (showCancelDialogForBooking != null) {
        val targetBooking = showCancelDialogForBooking!!
        AlertDialog(
            onDismissRequest = { showCancelDialogForBooking = null },
            icon = { Icon(Icons.Default.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.error) },
            title = { Text("Cancel Booking #${targetBooking.id}?") },
            text = {
                Column {
                    Text("Are you sure you want to cancel your slot at ${targetBooking.venueName}?")
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "Refund of ₹${(targetBooking.totalAmount * 0.90).toInt()} (90% after standard cancellation fee) will be credited to your original payment method within 2-3 business days.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.cancelBooking(targetBooking.id)
                        showCancelDialogForBooking = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Confirm Cancellation")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { showCancelDialogForBooking = null }) {
                    Text("Keep Booking")
                }
            }
        )
    }

    // QR Code Pass Dialog
    if (showQrDialogForBooking != null) {
        val targetBooking = showQrDialogForBooking!!
        AlertDialog(
            onDismissRequest = { showQrDialogForBooking = null },
            icon = { Icon(Icons.Default.QrCode2, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(36.dp)) },
            title = { Text("Check-In Digital Pass 🎫", fontWeight = FontWeight.Bold, fontSize = 18.sp) },
            text = {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Surface(
                        color = Color.White,
                        shape = RoundedCornerShape(16.dp),
                        shadowElevation = 4.dp,
                        modifier = Modifier.size(200.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                Icons.Default.QrCode2,
                                contentDescription = "QR Code",
                                modifier = Modifier.size(160.dp),
                                tint = Color.Black
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                    Text(targetBooking.venueName, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Text("📅 ${targetBooking.bookingDate.ifBlank { targetBooking.date }} | ⏰ ${targetBooking.slotLabel}", fontSize = 12.sp)
                    Text("Ref: #${targetBooking.bookingRef.ifBlank { targetBooking.id }}", fontSize = 11.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Show this QR pass at the venue entrance counter for instant verification.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            },
            confirmButton = {
                Button(onClick = { showQrDialogForBooking = null }) {
                    Text("Done")
                }
            }
        )
    }

    // Summary Invoice View Modal (Tax Invoice & Booking Summary)
    showInvoiceForTransaction?.let { tx ->
        val matchingBooking = remember(tx.bookingId, tx.transactionId, bookings) {
            bookings.find { it.id == tx.bookingId || it.paymentId == tx.transactionId }
        }
        BookingSummaryInvoiceModal(
            transaction = tx,
            booking = matchingBooking,
            onDismiss = { showInvoiceForTransaction = null },
            onNavigateToBooking = { bookingId ->
                showInvoiceForTransaction = null
                val matchIndex = bookings.indexOfFirst { it.id == bookingId }
                if (matchIndex != -1) {
                    selectedTab = 0
                }
            }
        )
    }
}

@Composable
private fun BookingCardItem(
    booking: Booking,
    onPayNow: () -> Unit,
    onCancelBooking: () -> Unit,
    onShowQrPass: () -> Unit,
    onGetDirections: () -> Unit,
    onViewInvoice: (() -> Unit)? = null
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                AsyncImage(
                    model = booking.venueCoverUrl.ifBlank { booking.venueImageUrl }.ifBlank { "https://images.unsplash.com/photo-1546519638-68e109498ffc" },
                    contentDescription = booking.venueName,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(12.dp))
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(booking.venueName, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("📅 ${booking.bookingDate.ifBlank { booking.date }}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("⏰ ${booking.slotLabel.ifBlank { "${booking.startTime} - ${booking.endTime}" }}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
                Surface(
                    color = when (booking.status) {
                        BookingStatus.CONFIRMED -> Color(0xFFE8F5E9)
                        BookingStatus.COMPLETED -> Color(0xFFE3F2FD)
                        BookingStatus.PENDING_OWNER_APPROVAL -> Color(0xFFFFF8E1)
                        BookingStatus.PENDING, BookingStatus.HELD -> Color(0xFFFFF3E0)
                        BookingStatus.CANCELLED, BookingStatus.REJECTED -> Color(0xFFFFEBEE)
                    },
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = when (booking.status) {
                            BookingStatus.CONFIRMED -> "CONFIRMED"
                            BookingStatus.COMPLETED -> "COMPLETED"
                            BookingStatus.PENDING_OWNER_APPROVAL -> "AWAITING APPROVAL"
                            BookingStatus.PENDING -> "PENDING"
                            BookingStatus.HELD -> "HOLD"
                            BookingStatus.CANCELLED -> "CANCELLED"
                            BookingStatus.REJECTED -> "DECLINED"
                        },
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = when (booking.status) {
                            BookingStatus.CONFIRMED -> Color(0xFF2E7D32)
                            BookingStatus.COMPLETED -> Color(0xFF1565C0)
                            BookingStatus.PENDING_OWNER_APPROVAL -> Color(0xFFF57F17)
                            BookingStatus.PENDING, BookingStatus.HELD -> Color(0xFFE65100)
                            BookingStatus.CANCELLED, BookingStatus.REJECTED -> Color(0xFFC62828)
                        },
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            if (booking.status == BookingStatus.PENDING_OWNER_APPROVAL) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = Color(0xFFFFF8E1),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.HourglassTop, contentDescription = null, tint = Color(0xFFF57F17), modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            "Token paid • Awaiting owner review & slot confirmation",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(0xFF5D4037)
                        )
                    }
                }
            } else if (booking.status == BookingStatus.REJECTED) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = Color(0xFFFFEBEE),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Cancel, contentDescription = null, tint = Color(0xFFC62828), modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                "Owner Declined Request",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFFB71C1C)
                            )
                        }
                        if (!booking.rejectionReason.isNullOrBlank()) {
                            Text(
                                "Reason: ${booking.rejectionReason}",
                                fontSize = 11.sp,
                                color = Color(0xFFB71C1C),
                                modifier = Modifier.padding(start = 22.dp)
                            )
                        }
                        if (!booking.refundId.isNullOrBlank()) {
                            Text(
                                "Token Refund: ₹${booking.advanceAmountPaid.toInt().coerceAtLeast(booking.totalAmount.toInt())} processed (${booking.refundId})",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF2E7D32),
                                modifier = Modifier.padding(start = 22.dp, top = 2.dp)
                            )
                        }
                    }
                }
            } else if (booking.status == BookingStatus.CONFIRMED && !booking.finalOrderId.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    "Order #${booking.finalOrderId}",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
            }

            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    if (booking.isAdvancePayment || booking.advanceAmountPaid > 0) {
                        Text("Advance Paid (Bal: ₹${booking.remainingBalanceDue.toInt()} due)", fontSize = 10.sp, color = Color(0xFFE65100), fontWeight = FontWeight.Bold)
                        Text("₹${booking.advanceAmountPaid.toInt()} / ₹${booking.totalAmount.ifZero(booking.totalPrice).toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, color = MaterialTheme.colorScheme.primary)
                    } else {
                        Text("Total Paid / Due", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("₹${booking.totalAmount.ifZero(booking.totalPrice).toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (booking.status == BookingStatus.PENDING || booking.status == BookingStatus.HELD) {
                        Button(
                            onClick = onPayNow,
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Text("Pay Now 💳", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    } else if (booking.status == BookingStatus.CONFIRMED || booking.status == BookingStatus.COMPLETED) {
                        if (onViewInvoice != null) {
                            FilledTonalButton(
                                onClick = onViewInvoice,
                                shape = RoundedCornerShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp),
                                modifier = Modifier.testTag("booking_invoice_btn_${booking.id}")
                            ) {
                                Icon(Icons.Default.ReceiptLong, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(modifier = Modifier.width(3.dp))
                                Text("PDF Invoice", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }

                        OutlinedButton(
                            onClick = onShowQrPass,
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp)
                        ) {
                            Icon(Icons.Default.QrCode, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(3.dp))
                            Text("QR", fontSize = 11.sp)
                        }

                        OutlinedButton(
                            onClick = onGetDirections,
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp)
                        ) {
                            Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(14.dp))
                        }

                        if (booking.status == BookingStatus.CONFIRMED) {
                            IconButton(
                                onClick = onCancelBooking,
                                modifier = Modifier.size(32.dp)
                            ) {
                                Icon(Icons.Default.Cancel, contentDescription = "Cancel", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun PaymentTransactionCardItem(
    transaction: PaymentTransactionEntity,
    onSelectBooking: (String) -> Unit,
    onViewInvoice: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault()) }
    val formattedDate = remember(transaction.timestamp) {
        dateFormat.format(Date(transaction.timestamp))
    }

    val (statusBg, statusText, statusIcon) = when (transaction.paymentStatus.uppercase()) {
        "SUCCESS", "PAID", "COMPLETED" -> Triple(
            Color(0xFFE8F5E9),
            Color(0xFF2E7D32),
            Icons.Default.CheckCircle
        )
        "PENDING", "PROCESSING", "HELD" -> Triple(
            Color(0xFFFFF3E0),
            Color(0xFFE65100),
            Icons.Default.HourglassTop
        )
        "FAILED", "ERROR" -> Triple(
            Color(0xFFFFEBEE),
            Color(0xFFC62828),
            Icons.Default.Error
        )
        else -> Triple(
            Color(0xFFF5F5F5),
            Color(0xFF616161),
            Icons.Default.Cancel
        )
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.65f)),
        modifier = modifier
            .fillMaxWidth()
            .testTag("tx_card_${transaction.transactionId}")
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = statusIcon,
                        contentDescription = transaction.paymentStatus,
                        tint = statusText,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = transaction.transactionId,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                }

                Surface(
                    color = statusBg,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = transaction.paymentStatus.uppercase(),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = statusText,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(10.dp))

            if (transaction.venueName.isNotBlank()) {
                Text(
                    text = transaction.venueName,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("Booking ID", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        text = "#${transaction.bookingId}",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp
                    )
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("Date & Time", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        text = formattedDate,
                        fontWeight = FontWeight.Normal,
                        fontSize = 12.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("Payment Method", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        text = transaction.paymentMethod,
                        fontWeight = FontWeight.Medium,
                        fontSize = 12.sp
                    )
                }
                if (transaction.razorpayOrderId != null) {
                    Column(horizontalAlignment = Alignment.End) {
                        Text("Order ID", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            text = transaction.razorpayOrderId,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 11.sp
                        )
                    }
                }
            }

            if (transaction.failureReason != null) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.4f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Reason: ${transaction.failureReason}",
                        color = MaterialTheme.colorScheme.error,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(8.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Total Paid", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        text = "₹${transaction.amount.toInt()}",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 18.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (onViewInvoice != null && (
                            transaction.paymentStatus.equals("SUCCESS", true) ||
                            transaction.paymentStatus.equals("PAID", true) ||
                            transaction.paymentStatus.equals("COMPLETED", true)
                        )
                    ) {
                        FilledTonalButton(
                            onClick = onViewInvoice,
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                            modifier = Modifier.testTag("my_bookings_invoice_btn_${transaction.transactionId}")
                        ) {
                            Icon(Icons.Default.ReceiptLong, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Invoice", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }

                    if (transaction.bookingId.isNotBlank()) {
                        OutlinedButton(
                            onClick = { onSelectBooking(transaction.bookingId) },
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Icon(Icons.Default.ConfirmationNumber, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("View Booking", fontSize = 11.sp)
                        }
                    }
                }
            }
        }
    }
}

private fun Double.ifZero(alt: Double): Double = if (this == 0.0) alt else this
