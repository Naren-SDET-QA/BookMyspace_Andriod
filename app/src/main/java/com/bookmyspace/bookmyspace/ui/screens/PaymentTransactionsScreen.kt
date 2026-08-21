package com.bookmyspace.bookmyspace.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.animation.*
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bookmyspace.bookmyspace.data.local.BookMySpaceRoomDatabase
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.data.repository.PaymentTransactionRepository
import com.bookmyspace.bookmyspace.ui.components.BookingSummaryInvoiceModal
import com.bookmyspace.bookmyspace.ui.components.PaymentSuccessLottieAnimation
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

/**
 * Composable screen that directly queries the Room database for stored payment
 * transactions and displays them in a rich list with clear status indicators (success/failed/pending).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentTransactionsScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToBooking: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    // Room Database Repository
    val repository = remember {
        PaymentTransactionRepository.getInstance(context)
    }

    // Query Room database reactive flow
    val allTransactions by repository.allTransactions.collectAsState(initial = emptyList())
    val bookings by BookMySpaceRepository.bookings.collectAsState()

    var selectedStatusFilter by remember { mutableStateOf("ALL") }
    var searchQuery by remember { mutableStateOf("") }
    var selectedTransactionForReceipt by remember { mutableStateOf<PaymentTransactionEntity?>(null) }
    var selectedTransactionForInvoice by remember { mutableStateOf<PaymentTransactionEntity?>(null) }
    var showDeleteConfirmDialog by remember { mutableStateOf<PaymentTransactionEntity?>(null) }
    var showWebhookValidatorDialog by remember { mutableStateOf(false) }

    // Seed sample transactions if Room DB is empty
    LaunchedEffect(allTransactions.isEmpty()) {
        if (allTransactions.isEmpty()) {
            val now = System.currentTimeMillis()
            val sampleTransactions = listOf(
                PaymentTransactionEntity(
                    transactionId = "pay_bms_live_901",
                    bookingId = "bk_demo_901",
                    venueId = "v_smash_arena",
                    venueName = "Smash Arena International Badminton Complex",
                    amount = 850.0,
                    currency = "INR",
                    paymentStatus = "SUCCESS",
                    paymentMethod = "Razorpay UPI (Google Pay)",
                    razorpayOrderId = "order_bms_live_901",
                    razorpaySignature = "sig_valid_bms_901",
                    customerName = "Narendra Reddy",
                    customerEmail = "narenqe2@gmail.com",
                    customerPhone = "+91 98765 43210",
                    timestamp = now - 3600000L * 2,
                    notes = "Court 1 & 2 Prime Slot Booking"
                ),
                PaymentTransactionEntity(
                    transactionId = "pay_bms_live_902",
                    bookingId = "bk_demo_902",
                    venueId = "v_grand_palace",
                    venueName = "The Royal Imperial Palace & Convention",
                    amount = 150000.0,
                    currency = "INR",
                    paymentStatus = "SUCCESS",
                    paymentMethod = "Razorpay Net Banking (HDFC Bank)",
                    razorpayOrderId = "order_bms_live_902",
                    razorpaySignature = "sig_valid_bms_902",
                    customerName = "Narendra Reddy",
                    customerEmail = "narenqe2@gmail.com",
                    customerPhone = "+91 98765 43210",
                    timestamp = now - 86400000L,
                    notes = "Grand Ballroom Reception Advance"
                ),
                PaymentTransactionEntity(
                    transactionId = "pay_bms_fail_903",
                    bookingId = "bk_demo_903",
                    venueId = "v_skyline_turf",
                    venueName = "Skyline Rooftop Football Arena",
                    amount = 1200.0,
                    currency = "INR",
                    paymentStatus = "FAILED",
                    paymentMethod = "Razorpay Cards (Visa)",
                    razorpayOrderId = "order_bms_live_903",
                    customerName = "Narendra Reddy",
                    customerEmail = "narenqe2@gmail.com",
                    customerPhone = "+91 98765 43210",
                    failureReason = "Payment failed: Card expired or insufficient balance (ERR_INSUFFICIENT_FUNDS)",
                    timestamp = now - 86400000L * 2,
                    notes = "Evening 7-8 PM 5v5 Turf Slot"
                ),
                PaymentTransactionEntity(
                    transactionId = "pay_bms_pend_904",
                    bookingId = "bk_demo_904",
                    venueId = "v_apex_cowork",
                    venueName = "Apex Innovation Hub & Coworking",
                    amount = 4500.0,
                    currency = "INR",
                    paymentStatus = "PENDING",
                    paymentMethod = "Razorpay UPI (PhonePe)",
                    razorpayOrderId = "order_bms_live_904",
                    customerName = "Narendra Reddy",
                    customerEmail = "narenqe2@gmail.com",
                    customerPhone = "+91 98765 43210",
                    timestamp = now - 86400000L * 3,
                    notes = "Weekly Dedicated Desk Reservation"
                ),
                PaymentTransactionEntity(
                    transactionId = "pay_bms_fail_905",
                    bookingId = "bk_demo_905",
                    venueId = "v_olympic_pool",
                    venueName = "Olympic Aquatic Center & Pool",
                    amount = 500.0,
                    currency = "INR",
                    paymentStatus = "FAILED",
                    paymentMethod = "Razorpay UPI (Paytm)",
                    razorpayOrderId = "order_bms_live_905",
                    customerName = "Narendra Reddy",
                    customerEmail = "narenqe2@gmail.com",
                    customerPhone = "+91 98765 43210",
                    failureReason = "Payment cancelled by user in UPI app",
                    timestamp = now - 86400000L * 4,
                    notes = "Morning Swim Pass"
                )
            )
            sampleTransactions.forEach { repository.recordTransaction(it) }
        }
    }

    // Filtered transaction list
    val filteredTransactions = remember(allTransactions, selectedStatusFilter, searchQuery) {
        allTransactions.filter { tx ->
            val matchesFilter = when (selectedStatusFilter) {
                "ALL" -> true
                "SUCCESS" -> tx.paymentStatus.equals("SUCCESS", ignoreCase = true) || tx.paymentStatus.equals("PAID", ignoreCase = true)
                "FAILED" -> tx.paymentStatus.equals("FAILED", ignoreCase = true) || tx.paymentStatus.equals("ERROR", ignoreCase = true)
                "PENDING" -> tx.paymentStatus.equals("PENDING", ignoreCase = true) || tx.paymentStatus.equals("PROCESSING", ignoreCase = true)
                else -> true
            }

            val matchesSearch = if (searchQuery.isBlank()) {
                true
            } else {
                val q = searchQuery.trim().lowercase()
                tx.transactionId.lowercase().contains(q) ||
                        tx.bookingId.lowercase().contains(q) ||
                        tx.venueName.lowercase().contains(q) ||
                        tx.paymentMethod.lowercase().contains(q) ||
                        tx.customerName.lowercase().contains(q)
            }

            matchesFilter && matchesSearch
        }
    }

    // Calculation metrics
    val totalSuccessAmount = remember(allTransactions) {
        allTransactions
            .filter { it.paymentStatus.equals("SUCCESS", ignoreCase = true) || it.paymentStatus.equals("PAID", ignoreCase = true) }
            .sumOf { it.amount }
    }
    val successCount = remember(allTransactions) {
        allTransactions.count { it.paymentStatus.equals("SUCCESS", ignoreCase = true) || it.paymentStatus.equals("PAID", ignoreCase = true) }
    }
    val failedCount = remember(allTransactions) {
        allTransactions.count { it.paymentStatus.equals("FAILED", ignoreCase = true) || it.paymentStatus.equals("ERROR", ignoreCase = true) }
    }

    Scaffold(
        modifier = modifier
            .fillMaxSize()
            .testTag("payment_transactions_screen"),
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Payment Transactions",
                            fontWeight = FontWeight.Bold,
                            fontSize = 19.sp
                        )
                        Text(
                            text = "Room Database Local Records",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("payment_tx_back_button")
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(
                        onClick = { showWebhookValidatorDialog = true },
                        modifier = Modifier.testTag("payment_tx_webhook_validator_button")
                    ) {
                        Icon(
                            Icons.Default.VerifiedUser,
                            contentDescription = "Webhook & Signature Validator",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                    IconButton(
                        onClick = {
                            coroutineScope.launch {
                                // Add a simulated live transaction
                                val newId = "pay_live_${UUID.randomUUID().toString().take(6)}"
                                val orderId = "order_${UUID.randomUUID().toString().take(8)}"
                                val isSuccess = Math.random() > 0.3
                                val sig = if (isSuccess) com.bookmyspace.bookmyspace.data.payment.PaymentSignatureValidator.generateCheckoutSignature(orderId, newId) else "sig_tampered_invalid"
                                repository.recordTransaction(
                                    PaymentTransactionEntity(
                                        transactionId = newId,
                                        bookingId = "bk_${UUID.randomUUID().toString().take(6)}",
                                        venueId = "v_smash_arena",
                                        venueName = "Smash Arena International",
                                        amount = (400..1500).random().toDouble(),
                                        currency = "INR",
                                        paymentStatus = if (isSuccess) "SUCCESS" else "FAILED",
                                        paymentMethod = "Razorpay UPI",
                                        razorpayOrderId = orderId,
                                        razorpaySignature = sig,
                                        isSignatureVerified = isSuccess,
                                        customerName = "Narendra Reddy",
                                        customerEmail = "narenqe2@gmail.com",
                                        customerPhone = "+91 98765 43210",
                                        failureReason = if (!isSuccess) "HMAC-SHA256 signature verification failed" else null,
                                        timestamp = System.currentTimeMillis(),
                                        notes = "Instant Slot Reservation"
                                    )
                                )
                                Toast.makeText(context, "New verified transaction logged to Room", Toast.LENGTH_SHORT).show()
                            }
                        },
                        modifier = Modifier.testTag("payment_tx_add_mock_button")
                    ) {
                        Icon(Icons.Default.AddCard, contentDescription = "Simulate Transaction", tint = MaterialTheme.colorScheme.primary)
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Metrics Summary Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .testTag("payment_metrics_summary_card"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f)
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Total Spent",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Text(
                            text = "₹${totalSuccessAmount.toInt()}",
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 22.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        // Success Badge Metric
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = Color(0xFFE8F5E9)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF2E7D32), modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = "$successCount Success",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF2E7D32)
                                )
                            }
                        }

                        // Failed Badge Metric
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = Color(0xFFFFEBEE)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.Error, contentDescription = null, tint = Color(0xFFC62828), modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = "$failedCount Failed",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFC62828)
                                )
                            }
                        }
                    }
                }
            }

            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .testTag("payment_search_input"),
                placeholder = { Text("Search by ID, venue, method...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Icon(Icons.Default.Clear, contentDescription = "Clear")
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )

            // Status Filter Chips
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                val filters = listOf(
                    "ALL" to "All (${allTransactions.size})",
                    "SUCCESS" to "Success ($successCount)",
                    "FAILED" to "Failed ($failedCount)",
                    "PENDING" to "Pending (${allTransactions.count { it.paymentStatus.equals("PENDING", ignoreCase = true) }})"
                )

                items(filters) { (statusKey, label) ->
                    FilterChip(
                        selected = selectedStatusFilter == statusKey,
                        onClick = { selectedStatusFilter = statusKey },
                        label = { Text(label, fontWeight = FontWeight.SemiBold, fontSize = 12.sp) },
                        modifier = Modifier.testTag("filter_chip_$statusKey")
                    )
                }
            }

            // List of Transactions from Room Database
            if (allTransactions.isEmpty()) {
                com.bookmyspace.bookmyspace.ui.components.EyeCatchingTransactionsSkeleton()
            } else if (filteredTransactions.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = Icons.Default.ReceiptLong,
                            contentDescription = null,
                            modifier = Modifier.size(56.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = if (searchQuery.isNotBlank()) "No transactions matching '$searchQuery'" else "No transactions found",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Payment records stored locally in Room database will appear here.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .testTag("payment_transactions_list"),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(filteredTransactions, key = { it.transactionId }) { transaction ->
                        PaymentTransactionListItem(
                            transaction = transaction,
                            onClick = { selectedTransactionForReceipt = transaction },
                            onViewInvoice = { selectedTransactionForInvoice = transaction },
                            onCopyId = { id ->
                                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                val clip = ClipData.newPlainText("Transaction ID", id)
                                clipboard.setPrimaryClip(clip)
                                Toast.makeText(context, "Copied $id", Toast.LENGTH_SHORT).show()
                            },
                            onDelete = { showDeleteConfirmDialog = transaction }
                        )
                    }
                }
            }
        }
    }

    // Webhook Validator & Simulator Dialog
    if (showWebhookValidatorDialog) {
        RazorpayWebhookValidatorDialog(
            onDismiss = { showWebhookValidatorDialog = false }
        )
    }

    // Summary Invoice View Modal (Tax Invoice & Booking Summary)
    selectedTransactionForInvoice?.let { tx ->
        val matchingBooking = remember(tx.bookingId, tx.transactionId, bookings) {
            bookings.find { it.id == tx.bookingId || it.paymentId == tx.transactionId }
        }
        BookingSummaryInvoiceModal(
            transaction = tx,
            booking = matchingBooking,
            onDismiss = { selectedTransactionForInvoice = null },
            onNavigateToBooking = { bookingId ->
                selectedTransactionForInvoice = null
                onNavigateToBooking(bookingId)
            }
        )
    }

    // Receipt Detail Bottom Sheet Dialog
    selectedTransactionForReceipt?.let { tx ->
        PaymentReceiptDetailModal(
            transaction = tx,
            onDismiss = { selectedTransactionForReceipt = null },
            onViewInvoice = {
                selectedTransactionForReceipt = null
                selectedTransactionForInvoice = tx
            },
            onViewBooking = { bookingId ->
                selectedTransactionForReceipt = null
                onNavigateToBooking(bookingId)
            }
        )
    }

    // Delete Record Confirmation Dialog
    showDeleteConfirmDialog?.let { tx ->
        AlertDialog(
            onDismissRequest = { showDeleteConfirmDialog = null },
            title = { Text("Delete Payment Record") },
            text = { Text("Are you sure you want to remove the record for ${tx.transactionId} from the local database?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        coroutineScope.launch {
                            repository.deleteTransaction(tx.transactionId)
                            showDeleteConfirmDialog = null
                            Toast.makeText(context, "Record removed", Toast.LENGTH_SHORT).show()
                        }
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmDialog = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}

/**
 * Individual Card item displaying payment transaction with status indicators.
 */
@Composable
fun PaymentTransactionListItem(
    transaction: PaymentTransactionEntity,
    onClick: () -> Unit,
    onViewInvoice: () -> Unit,
    onCopyId: (String) -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault()) }
    val formattedDate = remember(transaction.timestamp) {
        dateFormat.format(Date(transaction.timestamp))
    }

    // Determine status visual indicator styling
    val (statusBg, statusText, statusIcon, statusLabel) = when (transaction.paymentStatus.uppercase()) {
        "SUCCESS", "PAID", "COMPLETED" -> StatusVisual(
            bgColor = Color(0xFFE8F5E9),
            textColor = Color(0xFF2E7D32),
            icon = Icons.Default.CheckCircle,
            label = "SUCCESS"
        )
        "FAILED", "ERROR" -> StatusVisual(
            bgColor = Color(0xFFFFEBEE),
            textColor = Color(0xFFC62828),
            icon = Icons.Default.Error,
            label = "FAILED"
        )
        "PENDING", "PROCESSING", "HELD" -> StatusVisual(
            bgColor = Color(0xFFFFF3E0),
            textColor = Color(0xFFE65100),
            icon = Icons.Default.HourglassTop,
            label = "PENDING"
        )
        "REFUNDED" -> StatusVisual(
            bgColor = Color(0xFFE0F2F1),
            textColor = Color(0xFF00695C),
            icon = Icons.Default.CurrencyExchange,
            label = "REFUNDED"
        )
        else -> StatusVisual(
            bgColor = Color(0xFFF5F5F5),
            textColor = Color(0xFF616161),
            icon = Icons.Default.Cancel,
            label = transaction.paymentStatus.uppercase()
        )
    }

    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .testTag("tx_item_${transaction.transactionId}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Header Row: Status Indicator Badge + Transaction ID + Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f, fill = false)
                ) {
                    // Status Visual Indicator Icon
                    Surface(
                        color = statusBg,
                        shape = CircleShape,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = statusIcon,
                                contentDescription = statusLabel,
                                tint = statusText,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = transaction.transactionId,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            IconButton(
                                onClick = { onCopyId(transaction.transactionId) },
                                modifier = Modifier.size(20.dp)
                            ) {
                                Icon(
                                    Icons.Default.ContentCopy,
                                    contentDescription = "Copy ID",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(13.dp)
                                )
                            }
                        }
                        Text(
                            text = formattedDate,
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // Status Badge Tag
                Surface(
                    color = statusBg,
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = statusLabel,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = statusText,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
            Spacer(modifier = Modifier.height(10.dp))

            // Venue Name & Booking Reference
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
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Payment Method
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.CreditCard,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = transaction.paymentMethod,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Medium
                    )
                }

                // Amount
                Text(
                    text = "₹${transaction.amount.toInt()}",
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 18.sp,
                    color = if (statusLabel == "FAILED") MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                )
            }

            // Cryptographic Verification & Webhook Badge
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (transaction.isSignatureVerified) {
                    Surface(
                        color = Color(0xFFE8F5E9),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Lock,
                                contentDescription = null,
                                tint = Color(0xFF2E7D32),
                                modifier = Modifier.size(11.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "HMAC-SHA256 Verified",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF2E7D32)
                            )
                        }
                    }
                } else {
                    Surface(
                        color = Color(0xFFFFEBEE),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.Warning,
                                contentDescription = null,
                                tint = Color(0xFFC62828),
                                modifier = Modifier.size(11.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Signature Unverified",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFFC62828)
                            )
                        }
                    }
                }

                if (!transaction.webhookEvent.isNullOrBlank()) {
                    Surface(
                        color = Color(0xFFE0F7FA),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.CloudSync,
                                contentDescription = null,
                                tint = Color(0xFF00838F),
                                modifier = Modifier.size(11.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = transaction.webhookEvent,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFF00838F)
                            )
                        }
                    }
                }
            }

            // Failure Reason Callout
            if (!transaction.failureReason.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = Color(0xFFFFEBEE),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(8.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Icon(
                            Icons.Default.Warning,
                            contentDescription = null,
                            tint = Color(0xFFC62828),
                            modifier = Modifier.size(15.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = transaction.failureReason,
                            color = Color(0xFFC62828),
                            fontSize = 11.sp,
                            lineHeight = 15.sp
                        )
                    }
                }
            }

            // Quick Actions: Summary Tax Invoice & Sharing
            if (transaction.paymentStatus.equals("SUCCESS", ignoreCase = true) ||
                transaction.paymentStatus.equals("PAID", ignoreCase = true) ||
                transaction.paymentStatus.equals("COMPLETED", ignoreCase = true)
            ) {
                Spacer(modifier = Modifier.height(12.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedButton(
                        onClick = onViewInvoice,
                        modifier = Modifier.testTag("view_invoice_btn_${transaction.transactionId}"),
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Icon(
                            Icons.Default.ReceiptLong,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Tax Invoice", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(
                            onClick = {
                                com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator.exportInvoicePdf(context, transaction)
                            },
                            modifier = Modifier
                                .size(32.dp)
                                .testTag("export_pdf_item_${transaction.transactionId}")
                        ) {
                            Icon(
                                Icons.Default.PictureAsPdf,
                                contentDescription = "Export PDF Document",
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                        IconButton(
                            onClick = {
                                com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator.shareTransactionInvoice(context, transaction)
                            },
                            modifier = Modifier
                                .size(32.dp)
                                .testTag("share_invoice_item_${transaction.transactionId}")
                        ) {
                            Icon(
                                Icons.Default.Share,
                                contentDescription = "Share Invoice",
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        IconButton(
                            onClick = onDelete,
                            modifier = Modifier
                                .size(32.dp)
                                .testTag("delete_tx_btn_${transaction.transactionId}")
                        ) {
                            Icon(
                                Icons.Default.DeleteOutline,
                                contentDescription = "Delete Record",
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Bottom sheet modal displaying full verified receipt details from Room.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentReceiptDetailModal(
    transaction: PaymentTransactionEntity,
    onDismiss: () -> Unit,
    onViewInvoice: () -> Unit,
    onViewBooking: (String) -> Unit
) {
    val context = LocalContext.current
    val dateFormat = remember { SimpleDateFormat("EEEE, dd MMM yyyy - hh:mm:ss a", Locale.getDefault()) }
    val formattedFullDate = remember(transaction.timestamp) {
        dateFormat.format(Date(transaction.timestamp))
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Transaction Receipt",
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp
                )
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, contentDescription = "Close")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Amount Callout Card with Lottie visual feedback
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (transaction.paymentStatus.equals("SUCCESS", true)) {
                        PaymentSuccessLottieAnimation(
                            size = 84.dp,
                            modifier = Modifier.padding(bottom = 4.dp)
                        )
                    }

                    Text(
                        text = "Total Amount Paid",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "₹${transaction.amount}",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 28.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Surface(
                        color = when {
                            transaction.paymentStatus.equals("SUCCESS", true) || transaction.paymentStatus.equals("PAID", true) -> Color(0xFFE8F5E9)
                            transaction.paymentStatus.equals("REFUNDED", true) -> Color(0xFFFFF3E0)
                            else -> Color(0xFFFFEBEE)
                        },
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = transaction.paymentStatus.uppercase(),
                            color = when {
                                transaction.paymentStatus.equals("SUCCESS", true) || transaction.paymentStatus.equals("PAID", true) -> Color(0xFF2E7D32)
                                transaction.paymentStatus.equals("REFUNDED", true) -> Color(0xFFE65100)
                                else -> Color(0xFFC62828)
                            },
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Key-Value Receipt Breakdown
            ReceiptDetailRow("Transaction ID", transaction.transactionId, isMonospace = true)
            if (transaction.bookingId.isNotBlank()) {
                ReceiptDetailRow("Booking ID", "#${transaction.bookingId}")
            }
            if (transaction.venueName.isNotBlank()) {
                ReceiptDetailRow("Venue", transaction.venueName)
            }
            ReceiptDetailRow("Payment Method", transaction.paymentMethod)
            if (!transaction.razorpayOrderId.isNullOrBlank()) {
                ReceiptDetailRow("Gateway Order ID", transaction.razorpayOrderId, isMonospace = true)
            }
            ReceiptDetailRow(
                "Signature Verification",
                if (transaction.isSignatureVerified) "✓ HMAC-SHA256 Verified" else "⚠ Unverified / Failed",
                isError = !transaction.isSignatureVerified
            )
            if (!transaction.razorpaySignature.isNullOrBlank()) {
                ReceiptDetailRow("Signature Hash", transaction.razorpaySignature, isMonospace = true)
            }
            if (!transaction.webhookEvent.isNullOrBlank()) {
                ReceiptDetailRow("Webhook Event", transaction.webhookEvent)
            }
            ReceiptDetailRow("Timestamp", formattedFullDate)
            if (transaction.customerName.isNotBlank()) {
                ReceiptDetailRow("Billed To", "${transaction.customerName} (${transaction.customerEmail})")
            }

            if (!transaction.failureReason.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                ReceiptDetailRow("Failure Reason", transaction.failureReason, isError = true)
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Summary Invoice generation action for successful payments
            if (transaction.paymentStatus.equals("SUCCESS", ignoreCase = true) ||
                transaction.paymentStatus.equals("PAID", ignoreCase = true) ||
                transaction.paymentStatus.equals("COMPLETED", ignoreCase = true)
            ) {
                Button(
                    onClick = onViewInvoice,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .testTag("receipt_view_summary_invoice_btn"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary
                    )
                ) {
                    Icon(Icons.Default.ReceiptLong, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("View Summary Tax Invoice", fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.height(8.dp))

                OutlinedButton(
                    onClick = {
                        com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator.exportInvoicePdf(context, transaction)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(46.dp)
                        .testTag("receipt_export_pdf_btn"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.PictureAsPdf, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Export & Download PDF", fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.height(10.dp))
            }

            if (transaction.bookingId.isNotBlank()) {
                OutlinedButton(
                    onClick = { onViewBooking(transaction.bookingId) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.ConfirmationNumber, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("View Booking Details", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

/**
 * Interactive dialog allowing developers and testers to inspect and simulate
 * Razorpay webhook payload validation against HMAC-SHA256 signatures before updating Room.
 */
@Composable
fun RazorpayWebhookValidatorDialog(
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var selectedEvent by remember { mutableStateOf("payment.captured") }
    var orderId by remember { mutableStateOf("order_test_908123") }
    var paymentId by remember { mutableStateOf("pay_test_776102") }
    var bookingId by remember { mutableStateOf("bk_wh_test_44") }
    var amount by remember { mutableStateOf("1200") }
    var simulateTamperedSignature by remember { mutableStateOf(false) }
    var validationLog by remember { mutableStateOf<String?>(null) }
    var isValidationSuccess by remember { mutableStateOf<Boolean?>(null) }

    fun generatePayloadJson(): String {
        val amountInPaise = ((amount.toDoubleOrNull() ?: 1000.0) * 100).toLong()
        return """
        {
          "entity": "event",
          "account_id": "acc_bms_live_test",
          "event": "$selectedEvent",
          "contains": ["payment"],
          "payload": {
            "payment": {
              "entity": {
                "id": "$paymentId",
                "entity": "payment",
                "amount": $amountInPaise,
                "currency": "INR",
                "status": "${if (selectedEvent == "payment.failed") "failed" else "captured"}",
                "order_id": "$orderId",
                "method": "upi",
                "notes": {
                  "booking_id": "$bookingId"
                }
              }
            }
          }
        }
        """.trimIndent()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Security,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Webhook & Signature Validator", fontSize = 17.sp, fontWeight = FontWeight.Bold)
            }
        },
        text = {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 440.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                item {
                    Text(
                        "Test real-time cryptographic validation of Razorpay webhooks and HMAC-SHA256 signatures before updating Room database.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                item {
                    Text("Select Webhook Event:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        listOf("payment.captured", "payment.failed", "order.paid").forEach { event ->
                            FilterChip(
                                selected = selectedEvent == event,
                                onClick = { selectedEvent = event },
                                label = { Text(event, fontSize = 10.sp) }
                            )
                        }
                    }
                }

                item {
                    OutlinedTextField(
                        value = orderId,
                        onValueChange = { orderId = it },
                        label = { Text("Order ID") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                item {
                    OutlinedTextField(
                        value = paymentId,
                        onValueChange = { paymentId = it },
                        label = { Text("Payment ID") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                item {
                    OutlinedTextField(
                        value = amount,
                        onValueChange = { amount = it },
                        label = { Text("Amount (₹)") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Simulate Tampered Signature (Security Attack)", fontSize = 12.sp, modifier = Modifier.weight(1f))
                        Switch(
                            checked = simulateTamperedSignature,
                            onCheckedChange = { simulateTamperedSignature = it }
                        )
                    }
                }

                validationLog?.let { log ->
                    item {
                        Surface(
                            color = if (isValidationSuccess == true) Color(0xFFE8F5E9) else Color(0xFFFFEBEE),
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(10.dp)) {
                                Text(
                                    text = if (isValidationSuccess == true) "✅ VALIDATION PASSED" else "❌ VALIDATION FAILED",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    color = if (isValidationSuccess == true) Color(0xFF2E7D32) else Color(0xFFC62828)
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = log,
                                    fontSize = 11.sp,
                                    fontFamily = FontFamily.Monospace,
                                    color = if (isValidationSuccess == true) Color(0xFF2E7D32) else Color(0xFFC62828)
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val rawPayload = generatePayloadJson()
                    val validSignature = com.bookmyspace.bookmyspace.data.payment.PaymentSignatureValidator.generateWebhookSignature(rawPayload)
                    val signatureToPass = if (simulateTamperedSignature) "tampered_sig_${UUID.randomUUID().toString().take(12)}" else validSignature

                    // Execute validation via PaymentHandler validation layer
                    val handler = com.bookmyspace.bookmyspace.data.payment.PaymentHandler.getInstance()
                    val result = handler.processWebhookPayload(rawPayload, signatureToPass)

                    when (result) {
                        is com.bookmyspace.bookmyspace.data.payment.WebhookValidationResult.Success -> {
                            isValidationSuccess = true
                            validationLog = "Signature: ${signatureToPass.take(16)}...\nStatus: ${result.status}\nRoom DB Updated: Yes"
                            Toast.makeText(context, "Webhook verified & saved to Room DB", Toast.LENGTH_SHORT).show()
                        }
                        is com.bookmyspace.bookmyspace.data.payment.WebhookValidationResult.SignatureMismatch -> {
                            isValidationSuccess = false
                            validationLog = "Signature mismatch detected!\nExpected: ${result.expectedSignature.take(16)}...\nReceived: ${signatureToPass.take(16)}...\nRoom DB: Flagged as FAILED"
                        }
                        is com.bookmyspace.bookmyspace.data.payment.WebhookValidationResult.MalformedPayload -> {
                            isValidationSuccess = false
                            validationLog = "Malformed JSON payload: ${result.error}"
                        }
                    }
                }
            ) {
                Text("Verify & Process Webhook")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Close")
            }
        }
    )
}

@Composable
private fun ReceiptDetailRow(
    label: String,
    value: String,
    isMonospace: Boolean = false,
    isError: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(0.4f)
        )
        Text(
            text = value,
            fontSize = 13.sp,
            fontWeight = if (isMonospace) FontWeight.Bold else FontWeight.Medium,
            fontFamily = if (isMonospace) FontFamily.Monospace else FontFamily.Default,
            color = if (isError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(0.6f)
        )
    }
}

private data class StatusVisual(
    val bgColor: Color,
    val textColor: Color,
    val icon: ImageVector,
    val label: String
)
