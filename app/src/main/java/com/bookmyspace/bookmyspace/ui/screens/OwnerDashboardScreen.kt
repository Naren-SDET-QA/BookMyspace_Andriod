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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.auth.UserRoleProvider
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.model.BookingStatus
import com.bookmyspace.bookmyspace.data.model.UserRole
import com.bookmyspace.bookmyspace.data.model.Venue
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerDashboardScreen(
    onCreateVenue: () -> Unit,
    onNavigateToPaymentConfig: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val allVenues by BookMySpaceRepository.venues.collectAsState()
    val allBookings by BookMySpaceRepository.bookings.collectAsState()
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val currentRole by UserRoleProvider.role.collectAsState()

    // Strict role-based filtering: Owners manage only their own venues & booking requests; Admins see all
    val ownerVenues = remember(allVenues, authUser, currentRole) {
        BookMySpaceRepository.getVenuesForRole(currentRole, authUser?.id)
    }

    val ownerBookings = remember(allBookings, ownerVenues, authUser, currentRole) {
        BookMySpaceRepository.getBookingsForRole(currentRole, authUser?.id)
    }

    val pendingCount = remember(ownerBookings) {
        ownerBookings.count { it.status == BookingStatus.PENDING_OWNER_APPROVAL }
    }

    var selectedTab by remember { mutableIntStateOf(0) } // 0: Listings, 1: Bookings, 2: Revenue
    var bookingSubFilter by remember { mutableStateOf("PENDING") } // "PENDING", "CONFIRMED", "REJECTED", "ALL"

    // Dialog state for rejection
    var rejectingBooking by remember { mutableStateOf<Booking?>(null) }
    var rejectionReason by remember { mutableStateOf("Slot unavailable due to prior commitment / maintenance") }
    var isProcessingAction by remember { mutableStateOf(false) }

    val filteredBookings = remember(ownerBookings, bookingSubFilter) {
        when (bookingSubFilter) {
            "PENDING" -> ownerBookings.filter { it.status == BookingStatus.PENDING_OWNER_APPROVAL }
            "CONFIRMED" -> ownerBookings.filter { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.COMPLETED }
            "REJECTED" -> ownerBookings.filter { it.status == BookingStatus.REJECTED || it.status == BookingStatus.CANCELLED }
            else -> ownerBookings
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Venue Owner Portal 🏢", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                            if (pendingCount > 0) {
                                Spacer(modifier = Modifier.width(8.dp))
                                Badge(containerColor = MaterialTheme.colorScheme.error) {
                                    Text("$pendingCount Pending", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                }
                            }
                        }
                        Text(
                            text = authUser?.fullName?.let { "Welcome, $it • Role: ${currentRole.name}" } ?: "Partner Dashboard",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                actions = {
                    FilledTonalButton(
                        onClick = onCreateVenue,
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.padding(end = 8.dp).testTag("owner_add_venue_btn")
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Add Venue", fontSize = 12.sp)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier.testTag("owner_dashboard_screen")
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("My Spaces (${ownerVenues.size})", fontWeight = FontWeight.Bold, fontSize = 12.sp) },
                    modifier = Modifier.testTag("owner_tab_spaces")
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Requests (${ownerBookings.size})", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            if (pendingCount > 0) {
                                Spacer(modifier = Modifier.width(4.dp))
                                Surface(
                                    shape = CircleShape,
                                    color = MaterialTheme.colorScheme.error,
                                    modifier = Modifier.size(16.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Text("$pendingCount", fontSize = 9.sp, color = Color.White, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    },
                    modifier = Modifier.testTag("owner_tab_bookings")
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = { Text("Revenue", fontWeight = FontWeight.Bold, fontSize = 12.sp) },
                    modifier = Modifier.testTag("owner_tab_revenue")
                )
            }

            if (ownerVenues.isEmpty() && ownerBookings.isEmpty()) {
                com.bookmyspace.bookmyspace.ui.components.EyeCatchingDashboardSkeleton()
            } else {
                when (selectedTab) {
                    0 -> {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(14.dp)
                        ) {
                            items(ownerVenues) { venue ->
                                OwnerVenueCard(venue = venue)
                            }
                        }
                    }
                    1 -> {
                        Column(modifier = Modifier.fillMaxSize()) {
                            // Sub-filter chips
                            LazyRow(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                item {
                                    FilterChip(
                                        selected = bookingSubFilter == "PENDING",
                                        onClick = { bookingSubFilter = "PENDING" },
                                        label = { Text("⏳ Pending Approval ($pendingCount)", fontSize = 11.5.sp, fontWeight = FontWeight.Bold) },
                                        modifier = Modifier.testTag("filter_pending_approval")
                                    )
                                }
                                item {
                                    FilterChip(
                                        selected = bookingSubFilter == "CONFIRMED",
                                        onClick = { bookingSubFilter = "CONFIRMED" },
                                        label = { Text("✅ Confirmed (${ownerBookings.count { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.COMPLETED }})", fontSize = 11.5.sp) },
                                        modifier = Modifier.testTag("filter_confirmed")
                                    )
                                }
                                item {
                                    FilterChip(
                                        selected = bookingSubFilter == "REJECTED",
                                        onClick = { bookingSubFilter = "REJECTED" },
                                        label = { Text("❌ Rejected (${ownerBookings.count { it.status == BookingStatus.REJECTED || it.status == BookingStatus.CANCELLED }})", fontSize = 11.5.sp) },
                                        modifier = Modifier.testTag("filter_rejected")
                                    )
                                }
                                item {
                                    FilterChip(
                                        selected = bookingSubFilter == "ALL",
                                        onClick = { bookingSubFilter = "ALL" },
                                        label = { Text("All (${ownerBookings.size})", fontSize = 11.5.sp) },
                                        modifier = Modifier.testTag("filter_all")
                                    )
                                }
                            }

                            if (filteredBookings.isEmpty()) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .padding(32.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text("📬", fontSize = 48.sp)
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Text(
                                            text = if (bookingSubFilter == "PENDING") "No pending booking requests" else "No bookings found in this category",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 15.sp
                                        )
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = "When customers pay the token amount, their requests will appear here for your review.",
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
                                        OwnerBookingApprovalCard(
                                            booking = booking,
                                            onApprove = {
                                                val res = BookMySpaceRepository.approveBookingRequest(
                                                    bookingId = booking.id,
                                                    actorRole = currentRole,
                                                    actorUserId = authUser?.id
                                                )
                                                if (res.isSuccess) {
                                                    Toast.makeText(context, "Booking #${booking.id} Approved! Final Order created & customer notified.", Toast.LENGTH_LONG).show()
                                                } else {
                                                    Toast.makeText(context, res.exceptionOrNull()?.message ?: "Approval failed", Toast.LENGTH_LONG).show()
                                                }
                                            },
                                            onReject = {
                                                rejectingBooking = booking
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    2 -> {
                        OwnerRevenueTab(bookings = ownerBookings, onNavigateToPaymentConfig = onNavigateToPaymentConfig)
                    }
                }
            }
        }
    }

    // Rejection & Refund Dialog
    if (rejectingBooking != null) {
        val target = rejectingBooking!!
        val refundAmount = if (target.isAdvancePayment) target.advanceAmountPaid else target.totalAmount

        AlertDialog(
            onDismissRequest = { if (!isProcessingAction) rejectingBooking = null },
            icon = { Icon(Icons.Default.Cancel, contentDescription = null, tint = MaterialTheme.colorScheme.error) },
            title = { Text("Reject Booking #${target.id}?", fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Customer: ${target.userName.ifBlank { "Guest" }} (${target.userPhone.ifBlank { target.userEmail }})",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 13.sp
                    )
                    Text(
                        text = "Venue: ${target.venueName} • Slot: ${target.slotLabel}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(10.dp))

                    if (refundAmount > 0) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.CurrencyRupee, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Automatic token refund of ₹${refundAmount.toInt()} will be credited back to customer.",
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.onErrorContainer,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    Text("Specify Rejection Reason (sent to customer):", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(6.dp))
                    OutlinedTextField(
                        value = rejectionReason,
                        onValueChange = { rejectionReason = it },
                        modifier = Modifier.fillMaxWidth().testTag("rejection_reason_input"),
                        placeholder = { Text("e.g. Venue booked for private maintenance") },
                        maxLines = 3
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        isProcessingAction = true
                        coroutineScope.launch {
                            val res = BookMySpaceRepository.rejectBookingRequest(
                                bookingId = target.id,
                                reason = rejectionReason.ifBlank { "Owner declined request" },
                                actorRole = currentRole,
                                actorUserId = authUser?.id
                            )
                            isProcessingAction = false
                            rejectingBooking = null
                            if (res.isSuccess) {
                                Toast.makeText(context, "Booking Rejected and Token Refund of ₹${refundAmount.toInt()} processed.", Toast.LENGTH_LONG).show()
                            } else {
                                Toast.makeText(context, res.exceptionOrNull()?.message ?: "Rejection failed", Toast.LENGTH_LONG).show()
                            }
                        }
                    },
                    enabled = !isProcessingAction,
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.testTag("confirm_reject_booking_btn")
                ) {
                    if (isProcessingAction) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                    } else {
                        Text("Confirm Rejection & Refund")
                    }
                }
            },
            dismissButton = {
                OutlinedButton(
                    onClick = { rejectingBooking = null },
                    enabled = !isProcessingAction
                ) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun OwnerBookingApprovalCard(
    booking: Booking,
    onApprove: () -> Unit,
    onReject: () -> Unit
) {
    val isPending = booking.status == BookingStatus.PENDING_OWNER_APPROVAL
    val isConfirmed = booking.status == BookingStatus.CONFIRMED || booking.status == BookingStatus.COMPLETED
    val isRejected = booking.status == BookingStatus.REJECTED || booking.status == BookingStatus.CANCELLED

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = when {
                isPending -> MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.25f)
                isConfirmed -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                else -> MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.15f)
            }
        ),
        border = BorderStroke(
            1.5.dp,
            when {
                isPending -> MaterialTheme.colorScheme.tertiary.copy(alpha = 0.5f)
                isConfirmed -> MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
                else -> MaterialTheme.colorScheme.error.copy(alpha = 0.3f)
            }
        ),
        modifier = Modifier
            .fillMaxWidth()
            .testTag("owner_booking_card_${booking.id}")
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Header Row: Customer + Status Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                        modifier = Modifier.size(36.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(booking.userName.take(1).uppercase().ifBlank { "U" }, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(booking.userName.ifBlank { "Guest User" }, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(booking.userPhone.ifBlank { booking.userEmail }.ifBlank { "Verified Customer" }, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = when {
                        isPending -> Color(0xFFFFF3E0)
                        isConfirmed -> Color(0xFFE8F5E9)
                        else -> Color(0xFFFFEBEE)
                    }
                ) {
                    Text(
                        text = when {
                            isPending -> "⏳ ACTION REQUIRED"
                            isConfirmed -> "✅ CONFIRMED"
                            booking.status == BookingStatus.REJECTED -> "❌ REJECTED"
                            else -> booking.status.name
                        },
                        color = when {
                            isPending -> Color(0xFFE65100)
                            isConfirmed -> Color(0xFF2E7D32)
                            else -> Color(0xFFC62828)
                        },
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(10.dp))

            // Venue & Slot Details
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Stadium, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.width(6.dp))
                Text(booking.venueName, fontWeight = FontWeight.Bold, fontSize = 13.5.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Spacer(modifier = Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.CalendarMonth, contentDescription = null, modifier = Modifier.size(15.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.width(6.dp))
                Text("Date: ${booking.bookingDate.ifBlank { booking.date }} | Slot: ${booking.slotLabel}", fontSize = 12.sp)
            }

            // Payment Breakdown
            Spacer(modifier = Modifier.height(10.dp))
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.8f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = if (booking.isAdvancePayment || booking.advanceAmountPaid > 0) "Token Paid Online" else "Total Amount",
                            fontSize = 10.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = if (booking.isAdvancePayment || booking.advanceAmountPaid > 0) "₹${booking.advanceAmountPaid.toInt()}" else "₹${booking.totalAmount.toInt()}",
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 15.sp,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }

                    if (booking.remainingBalanceDue > 0) {
                        Column(horizontalAlignment = Alignment.End) {
                            Text("Balance Due on Check-In", fontSize = 10.5.sp, color = Color(0xFFE65100), fontWeight = FontWeight.SemiBold)
                            Text("₹${booking.remainingBalanceDue.toInt()}", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color(0xFFE65100))
                        }
                    } else {
                        Column(horizontalAlignment = Alignment.End) {
                            Text("Payment Method", fontSize = 10.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(booking.paymentMethod.ifBlank { "UPI / Online" }, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                        }
                    }
                }
            }

            // Registration details summary if present
            if (booking.registrationDetails.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Customer KYC Details: ${booking.registrationDetails.entries.take(2).joinToString(", ") { "${it.key}: ${it.value}" }}",
                    fontSize = 10.5.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // Final Order / Rejection Info
            if (!booking.finalOrderId.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text("Order ID: #${booking.finalOrderId} • Pass: ${booking.qrCodeToken}", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color(0xFF2E7D32))
            }
            if (!booking.rejectionReason.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text("Rejection Reason: ${booking.rejectionReason} (Refund: ${booking.refundId ?: "Processed"})", fontSize = 11.sp, color = MaterialTheme.colorScheme.error)
            }

            // Actions for Pending Bookings
            if (isPending) {
                Spacer(modifier = Modifier.height(14.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    OutlinedButton(
                        onClick = onReject,
                        shape = RoundedCornerShape(10.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.5f)),
                        modifier = Modifier.weight(1f).testTag("reject_booking_btn_${booking.id}")
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Reject & Refund", fontSize = 12.sp)
                    }

                    Button(
                        onClick = onApprove,
                        shape = RoundedCornerShape(10.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                        modifier = Modifier.weight(1.3f).testTag("approve_booking_btn_${booking.id}")
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Approve Booking", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun OwnerVenueCard(venue: Venue) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                AsyncImage(
                    model = venue.coverImageUrl,
                    contentDescription = venue.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(60.dp)
                        .clip(RoundedCornerShape(12.dp))
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(venue.name, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Text("📍 ${venue.city}, ${venue.state}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("₹${venue.pricingBaseAmount.toInt()} / slot • ${venue.timeSlots.size} slots", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
                }
                Surface(
                    color = if (venue.isActive) Color(0xFFE8F5E9) else Color(0xFFFFEBEE),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = if (venue.isActive) "Active" else "Inactive",
                        color = if (venue.isActive) Color(0xFF2E7D32) else Color(0xFFC62828),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun OwnerRevenueTab(
    bookings: List<Booking>,
    onNavigateToPaymentConfig: () -> Unit = {}
) {
    val totalRevenue = bookings.filter { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.COMPLETED }.sumOf { it.totalAmount }
    val advanceReceived = bookings.filter { it.status == BookingStatus.CONFIRMED || it.status == BookingStatus.COMPLETED || it.status == BookingStatus.PENDING_OWNER_APPROVAL }.sumOf { if (it.isAdvancePayment) it.advanceAmountPaid else it.totalAmount }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Total Settled Revenue", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("₹${totalRevenue.toInt()}", fontWeight = FontWeight.ExtraBold, fontSize = 28.sp, color = MaterialTheme.colorScheme.primary)
                Spacer(modifier = Modifier.height(4.dp))
                Text("Advance Tokens Collected: ₹${advanceReceived.toInt()}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF2E7D32))
                Spacer(modifier = Modifier.height(4.dp))
                Text("Transferred directly to registered bank account weekly on Tuesdays", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Tune, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Venue Payment Policies", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                    Text("Configurable", fontSize = 11.sp, color = Color(0xFF2E7D32), fontWeight = FontWeight.SemiBold)
                }
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    "Enable Pay at Venue, split advance tokens (e.g. 20%), UPI methods, and verify gateway health status.",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    onClick = onNavigateToPaymentConfig,
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth().testTag("owner_manage_payment_policies_btn")
                ) {
                    Icon(Icons.Default.Healing, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Configure Payment Policies & Gateway", fontWeight = FontWeight.Bold, fontSize = 12.5.sp)
                }
            }
        }
    }
}

