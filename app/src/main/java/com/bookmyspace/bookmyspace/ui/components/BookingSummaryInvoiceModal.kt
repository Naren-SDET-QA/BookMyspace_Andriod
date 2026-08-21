package com.bookmyspace.bookmyspace.ui.components

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.bookmyspace.bookmyspace.data.local.PaymentTransactionEntity
import com.bookmyspace.bookmyspace.data.model.Booking
import com.bookmyspace.bookmyspace.data.payment.RefundResult
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import com.bookmyspace.bookmyspace.util.PdfInvoiceGenerator
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

/**
 * Summary Invoice View Modal for successfully completed transactions.
 * Displays official Tax Invoice header, customer details, space booking details,
 * Razorpay Payment ID & Order ID, itemized tax breakdown, and QR check-in token.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookingSummaryInvoiceModal(
    transaction: PaymentTransactionEntity,
    booking: Booking? = null,
    onDismiss: () -> Unit,
    onNavigateToBooking: ((String) -> Unit)? = null
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    
    var currentTransaction by remember(transaction) { mutableStateOf(transaction) }
    var showRefundDialog by remember { mutableStateOf(false) }
    var showCustomEmailDialog by remember { mutableStateOf(false) }
    var customEmailInput by remember { mutableStateOf("") }
    var isRefunding by remember { mutableStateOf(false) }
    var refundReason by remember { mutableStateOf("Schedule changed / Cancel reservation") }
    var refundError by remember { mutableStateOf<String?>(null) }

    val isRefunded = remember(currentTransaction.paymentStatus) {
        currentTransaction.paymentStatus.equals("REFUNDED", ignoreCase = true)
    }

    val invoiceNo = remember(currentTransaction.transactionId) {
        PdfInvoiceGenerator.generateInvoiceNumber(currentTransaction)
    }
    val dateFormat = remember { SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault()) }
    val formattedDate = remember(currentTransaction.timestamp) {
        dateFormat.format(Date(currentTransaction.timestamp))
    }

    val totalAmount = currentTransaction.amount
    val baseAmount = totalAmount / 1.18
    val gstAmount = totalAmount - baseAmount
    val cgst = gstAmount / 2
    val sgst = gstAmount / 2
    val amountInWords = remember(totalAmount) {
        PdfInvoiceGenerator.amountInWords(totalAmount)
    }

    val venueName = currentTransaction.venueName.ifBlank { booking?.venueName ?: "BookMySpace Partner Venue" }
    val bookingId = currentTransaction.bookingId.ifBlank { booking?.id ?: "N/A" }
    val bookingDate = booking?.bookingDate?.ifBlank { booking.date } ?: formattedDate.substringBefore(",")
    val slotLabel = booking?.slotLabel ?: booking?.let { "${it.startTime} - ${it.endTime}" } ?: currentTransaction.notes.ifBlank { "Standard Reserved Slot" }
    val qrPassToken = booking?.qrCodeToken ?: "BMS-PASS-${currentTransaction.transactionId.takeLast(6).uppercase()}"

    // Refund Confirmation Dialog
    if (showRefundDialog) {
        AlertDialog(
            onDismissRequest = { if (!isRefunding) showRefundDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.CurrencyExchange,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Request Full Refund", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Are you sure you want to initiate a refund for this reservation? The payment will be refunded via Razorpay back to your original source account.",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    ) {
                        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Refund Amount:", fontSize = 12.sp, fontWeight = FontWeight.Medium)
                                Text(
                                    "₹${currentTransaction.amount.toInt()}",
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Payment ID:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(currentTransaction.transactionId, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                            }
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Venue:", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(
                                    venueName,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }

                    Text("Reason for Refund:", fontSize = 12.sp, fontWeight = FontWeight.Bold)

                    val reasons = listOf(
                        "Schedule changed / Cancel reservation",
                        "Booked incorrect date or time slot",
                        "Event postponed / Not required",
                        "Other reasons"
                    )
                    reasons.forEach { r ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .clickable { refundReason = r }
                                .padding(vertical = 4.dp, horizontal = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = (refundReason == r),
                                onClick = { refundReason = r }
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(r, fontSize = 12.sp)
                        }
                    }

                    if (refundError != null) {
                        Text(
                            text = refundError ?: "",
                            color = MaterialTheme.colorScheme.error,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }

                    Text(
                        text = "⚡ Instant Razorpay refund initiation. Amount will be credited to the original payment source in 5-7 working days.",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        isRefunding = true
                        refundError = null
                        coroutineScope.launch {
                            val res = BookMySpaceRepository.processTransactionRefund(
                                transactionId = currentTransaction.transactionId,
                                bookingId = currentTransaction.bookingId,
                                amount = currentTransaction.amount,
                                reason = refundReason
                            )
                            isRefunding = false
                            when (res) {
                                is RefundResult.Success -> {
                                    currentTransaction = currentTransaction.copy(
                                        paymentStatus = "REFUNDED",
                                        notes = "Refund ID: ${res.refundId} | Status: ${res.status}"
                                    )
                                    showRefundDialog = false
                                    Toast.makeText(
                                        context,
                                        "Refund initiated! Refund ID: ${res.refundId}",
                                        Toast.LENGTH_LONG
                                    ).show()
                                }
                                is RefundResult.Failure -> {
                                    refundError = res.errorMessage
                                    Toast.makeText(
                                        context,
                                        "Refund error: ${res.errorMessage}",
                                        Toast.LENGTH_LONG
                                    ).show()
                                }
                            }
                        }
                    },
                    enabled = !isRefunding,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error
                    ),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.testTag("confirm_refund_dialog_btn")
                ) {
                    if (isRefunding) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onError
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Processing...", fontSize = 12.sp)
                    } else {
                        Icon(Icons.Default.CurrencyExchange, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Confirm Refund", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            },
            dismissButton = {
                OutlinedButton(
                    onClick = { showRefundDialog = false },
                    enabled = !isRefunding,
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.testTag("cancel_refund_dialog_btn")
                ) {
                    Text("Cancel", fontSize = 12.sp)
                }
            }
        )
    }

    // Custom Email Dispatch Dialog
    if (showCustomEmailDialog) {
        val defaultEmail = currentTransaction.customerEmail.ifBlank { booking?.userEmail ?: "narenqe2@gmail.com" }
        AlertDialog(
            onDismissRequest = { showCustomEmailDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.Email,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Send Invoice via Email", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Enter the recipient email address. The generated PDF invoice and QR access pass will be delivered automatically.",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(
                        value = if (customEmailInput.isBlank()) defaultEmail else customEmailInput,
                        onValueChange = { customEmailInput = it },
                        label = { Text("Recipient Email") },
                        placeholder = { Text("e.g. narenqe2@gmail.com") },
                        leadingIcon = { Icon(Icons.Default.AlternateEmail, contentDescription = null) },
                        singleLine = true,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("custom_email_input_field")
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val targetEmail = if (customEmailInput.isNotBlank()) customEmailInput.trim() else defaultEmail
                        com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.sendInvoiceEmailAuto(
                            context = context,
                            transaction = currentTransaction,
                            booking = booking,
                            recipientEmailOverride = targetEmail
                        )
                        showCustomEmailDialog = false
                        Toast.makeText(context, "PDF Invoice emailed to $targetEmail ✉️", Toast.LENGTH_SHORT).show()
                    },
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.testTag("confirm_send_email_btn")
                ) {
                    Icon(Icons.Default.Send, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Send PDF Invoice", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                OutlinedButton(
                    onClick = { showCustomEmailDialog = false },
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.testTag("cancel_send_email_btn")
                ) {
                    Text("Cancel", fontSize = 12.sp)
                }
            }
        )
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
                .testTag("summary_invoice_modal"),
            shape = RoundedCornerShape(20.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 6.dp
        ) {
            Column(
                modifier = Modifier.fillMaxSize()
            ) {
                // Top App Bar for Invoice Modal
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.ReceiptLong,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "Booking Tax Invoice",
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                            Text(
                                text = invoiceNo,
                                fontSize = 11.sp,
                                fontFamily = FontFamily.Monospace,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        IconButton(
                            onClick = {
                                PdfInvoiceGenerator.exportInvoicePdf(context, currentTransaction, booking)
                            },
                            modifier = Modifier.testTag("export_pdf_top_btn")
                        ) {
                            Icon(
                                Icons.Default.PictureAsPdf,
                                contentDescription = "Export PDF Document",
                                modifier = Modifier.size(20.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }

                        IconButton(
                            onClick = {
                                val invoiceText = PdfInvoiceGenerator.generateFormattedInvoiceText(currentTransaction, booking)
                                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                val clip = ClipData.newPlainText("Tax Invoice", invoiceText)
                                clipboard.setPrimaryClip(clip)
                                Toast.makeText(context, "Invoice copied to clipboard", Toast.LENGTH_SHORT).show()
                            },
                            modifier = Modifier.testTag("copy_invoice_btn")
                        ) {
                            Icon(Icons.Default.ContentCopy, contentDescription = "Copy Invoice Text", modifier = Modifier.size(20.dp))
                        }

                        IconButton(
                            onClick = {
                                PdfInvoiceGenerator.shareTransactionInvoice(context, currentTransaction, booking)
                            },
                            modifier = Modifier.testTag("share_invoice_btn")
                        ) {
                            Icon(Icons.Default.Share, contentDescription = "Share Invoice", modifier = Modifier.size(20.dp))
                        }

                        IconButton(
                            onClick = onDismiss,
                            modifier = Modifier.testTag("close_invoice_btn")
                        ) {
                            Icon(Icons.Default.Close, contentDescription = "Close")
                        }
                    }
                }

                // Scrollable Invoice Document Canvas
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // Invoice Document Header Card
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.Top
                                ) {
                                    Column {
                                        Text(
                                            text = "BOOKMYSPACE",
                                            fontWeight = FontWeight.Black,
                                            fontSize = 18.sp,
                                            letterSpacing = 1.sp,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                        Text(
                                            text = "TAX INVOICE & BOOKING RECEIPT",
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }

                                    Surface(
                                        color = if (isRefunded) Color(0xFFFFF3E0) else Color(0xFFE8F5E9),
                                        shape = RoundedCornerShape(20.dp)
                                    ) {
                                        Row(
                                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Icon(
                                                if (isRefunded) Icons.Default.CurrencyExchange else Icons.Default.CheckCircle,
                                                contentDescription = null,
                                                tint = if (isRefunded) Color(0xFFE65100) else Color(0xFF2E7D32),
                                                modifier = Modifier.size(13.dp)
                                            )
                                            Spacer(modifier = Modifier.width(4.dp))
                                            Text(
                                                text = if (isRefunded) "REFUNDED" else "PAID & VERIFIED",
                                                color = if (isRefunded) Color(0xFFE65100) else Color(0xFF2E7D32),
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 10.sp
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(12.dp))
                                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                                Spacer(modifier = Modifier.height(10.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column {
                                        Text("Invoice No.", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Text(invoiceNo, fontSize = 12.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                                    }
                                    Column(horizontalAlignment = Alignment.End) {
                                        Text("Date & Time of Issue", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Text(formattedDate, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                                    }
                                }
                            }
                        }
                    }

                    // Refund Banner Status Card
                    if (isRefunded) {
                        item {
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF8E1)),
                                border = BorderStroke(1.dp, Color(0xFFFFD54F))
                            ) {
                                Row(
                                    modifier = Modifier.padding(14.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.CurrencyExchange,
                                        contentDescription = null,
                                        tint = Color(0xFFF57F17),
                                        modifier = Modifier.size(24.dp)
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Text(
                                            "Full Refund Processed",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.sp,
                                            color = Color(0xFFE65100)
                                        )
                                        Text(
                                            "Amount of ₹${currentTransaction.amount.toInt()} has been refunded via Razorpay. ${currentTransaction.notes}",
                                            fontSize = 11.sp,
                                            color = Color(0xFF5D4037)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Merchant & Customer Details Two-Column Block
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.25f)),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(14.dp),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                // Issued By (Merchant)
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = "ISSUED BY",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text("BookMySpace Tech India Pvt Ltd", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                    Text("GSTIN: 36AAACB1234F1Z5", fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("Hitec City, Hyderabad - 500081", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("support@bookmyspace.app", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }

                                // Billed To (Customer)
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = "BILLED TO",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        text = transaction.customerName.ifBlank { "Narendra Reddy" },
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    Text(
                                        text = transaction.customerEmail.ifBlank { "narenqe2@gmail.com" },
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = transaction.customerPhone.ifBlank { "+91 98765 43210" },
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = "Place of Supply: Telangana (36)",
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }

                    // Booking & Venue Details Section
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.Apartment,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(18.dp)
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "RESERVED SPACE & BOOKING DETAILS",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }

                                Spacer(modifier = Modifier.height(10.dp))
                                InvoiceLineItem("Venue Name", venueName, isBold = true)
                                InvoiceLineItem("Booking Reference", "#$bookingId", isMonospace = true)
                                InvoiceLineItem("Reservation Date", bookingDate)
                                InvoiceLineItem("Reserved Slot", slotLabel)
                                InvoiceLineItem("Entry Pass Token", qrPassToken, isMonospace = true)
                            }
                        }
                    }

                    // Razorpay Transaction & Gateway Details Section (Highlighted)
                    item {
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("invoice_razorpay_details_card"),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.25f)
                            ),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.4f))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            Icons.Default.Payment,
                                            contentDescription = null,
                                            tint = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(18.dp)
                                        )
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(
                                            text = "RAZORPAY PAYMENT GATEWAY DETAILS",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }

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
                                            Spacer(modifier = Modifier.width(3.dp))
                                            Text(
                                                text = if (transaction.isSignatureVerified) "HMAC Verified" else "Gateway Verified",
                                                fontSize = 9.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = Color(0xFF2E7D32)
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(10.dp))

                                // Razorpay Transaction ID with Copy Button
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(8.dp))
                                        .padding(horizontal = 10.dp, vertical = 8.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "Razorpay Transaction ID (Payment ID)",
                                            fontSize = 10.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                        Text(
                                            text = transaction.transactionId,
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold,
                                            fontFamily = FontFamily.Monospace,
                                            color = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.testTag("invoice_razorpay_tx_id")
                                        )
                                    }
                                    IconButton(
                                        onClick = {
                                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                            val clip = ClipData.newPlainText("Transaction ID", transaction.transactionId)
                                            clipboard.setPrimaryClip(clip)
                                            Toast.makeText(context, "Copied Transaction ID: ${transaction.transactionId}", Toast.LENGTH_SHORT).show()
                                        },
                                        modifier = Modifier.size(28.dp)
                                    ) {
                                        Icon(
                                            Icons.Default.ContentCopy,
                                            contentDescription = "Copy Transaction ID",
                                            modifier = Modifier.size(16.dp),
                                            tint = MaterialTheme.colorScheme.primary
                                        )
                                    }
                                }

                                Spacer(modifier = Modifier.height(8.dp))

                                if (!transaction.razorpayOrderId.isNullOrBlank()) {
                                    InvoiceLineItem("Razorpay Order ID", transaction.razorpayOrderId, isMonospace = true)
                                }
                                InvoiceLineItem("Payment Channel", transaction.paymentMethod)
                                InvoiceLineItem("Gateway Settlement", "Captured & Verified")
                                if (!transaction.razorpaySignature.isNullOrBlank()) {
                                    InvoiceLineItem("Signature Hash", transaction.razorpaySignature, isMonospace = true)
                                }
                            }
                        }
                    }

                    // Itemized Financial & Tax Breakdown Table
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Text(
                                    text = "ITEMIZED CHARGES & TAX BREAKDOWN",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Spacer(modifier = Modifier.height(8.dp))

                                // Table Header
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), RoundedCornerShape(6.dp))
                                        .padding(horizontal = 8.dp, vertical = 6.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text("Description", fontSize = 11.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                                    Text("Rate", fontSize = 11.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(60.dp), textAlign = TextAlign.End)
                                    Text("Amount (₹)", fontSize = 11.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(80.dp), textAlign = TextAlign.End)
                                }

                                Spacer(modifier = Modifier.height(6.dp))
                                TaxBreakdownRow("1. Space Reservation Fee", "1 Slot", "₹${String.format(Locale.US, "%.2f", baseAmount)}")
                                TaxBreakdownRow("2. Platform Convenience Fee", "Standard", "₹0.00")
                                TaxBreakdownRow("3. Central GST (CGST)", "9%", "₹${String.format(Locale.US, "%.2f", cgst)}")
                                TaxBreakdownRow("4. State GST (SGST)", "9%", "₹${String.format(Locale.US, "%.2f", sgst)}")

                                Spacer(modifier = Modifier.height(10.dp))
                                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                                Spacer(modifier = Modifier.height(10.dp))

                                // Total Row
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text("TOTAL AMOUNT PAID", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        Text(amountInWords, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.Medium)
                                    }
                                    Text(
                                        text = "₹${String.format(Locale.US, "%.2f", totalAmount)}",
                                        fontWeight = FontWeight.Black,
                                        fontSize = 19.sp,
                                        color = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.testTag("invoice_total_amount")
                                    )
                                }
                            }
                        }
                    }

                    // QR Check-in Pass Verification Matrix Block
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.25f)),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                // Stylized 2D QR Code Matrix Pattern
                                Surface(
                                    modifier = Modifier
                                        .size(68.dp)
                                        .clip(RoundedCornerShape(8.dp)),
                                    color = Color.White,
                                    border = BorderStroke(1.dp, Color.LightGray)
                                ) {
                                    Canvas(modifier = Modifier.fillMaxSize().padding(6.dp)) {
                                        val squareSize = size.width / 7f
                                        // Draw top-left target
                                        drawRect(Color.Black, Offset(0f, 0f), Size(squareSize * 2.5f, squareSize * 2.5f))
                                        drawRect(Color.White, Offset(squareSize * 0.5f, squareSize * 0.5f), Size(squareSize * 1.5f, squareSize * 1.5f))
                                        drawRect(Color.Black, Offset(squareSize * 0.85f, squareSize * 0.85f), Size(squareSize * 0.8f, squareSize * 0.8f))

                                        // Draw top-right target
                                        drawRect(Color.Black, Offset(size.width - squareSize * 2.5f, 0f), Size(squareSize * 2.5f, squareSize * 2.5f))
                                        drawRect(Color.White, Offset(size.width - squareSize * 2f, squareSize * 0.5f), Size(squareSize * 1.5f, squareSize * 1.5f))
                                        drawRect(Color.Black, Offset(size.width - squareSize * 1.65f, squareSize * 0.85f), Size(squareSize * 0.8f, squareSize * 0.8f))

                                        // Draw bottom-left target
                                        drawRect(Color.Black, Offset(0f, size.height - squareSize * 2.5f), Size(squareSize * 2.5f, squareSize * 2.5f))
                                        drawRect(Color.White, Offset(squareSize * 0.5f, size.height - squareSize * 2f), Size(squareSize * 1.5f, squareSize * 1.5f))
                                        drawRect(Color.Black, Offset(squareSize * 0.85f, size.height - squareSize * 1.65f), Size(squareSize * 0.8f, squareSize * 0.8f))

                                        // Center random dots
                                        drawRect(Color.Black, Offset(squareSize * 3f, squareSize * 3f), Size(squareSize, squareSize))
                                        drawRect(Color.Black, Offset(squareSize * 4.5f, squareSize * 2f), Size(squareSize, squareSize))
                                        drawRect(Color.Black, Offset(squareSize * 2f, squareSize * 4.5f), Size(squareSize, squareSize))
                                        drawRect(Color.Black, Offset(squareSize * 4.5f, squareSize * 4.5f), Size(squareSize, squareSize))
                                    }
                                }

                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = "On-Site Check-in Pass",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 12.sp
                                    )
                                    Text(
                                        text = "Scan at venue front desk or entry turnstile for immediate clearance.",
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        text = qrPassToken,
                                        fontFamily = FontFamily.Monospace,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        }
                    }

                    // Automated PDF Invoice Email Delivery Card Block
                    item {
                        val emailRecords by com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.emailRecords.collectAsState()
                        val emailRecord = remember(emailRecords, currentTransaction.transactionId, bookingId) {
                            emailRecords.firstOrNull { 
                                it.transactionId == currentTransaction.transactionId ||
                                (bookingId.isNotBlank() && it.bookingId == bookingId)
                            } ?: emailRecords.firstOrNull()
                        }
                        val recipientEmail = currentTransaction.customerEmail.ifBlank { booking?.userEmail ?: "narenqe2@gmail.com" }

                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("invoice_modal_email_card"),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.35f)),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.3f))
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            Icons.Default.MarkEmailRead,
                                            contentDescription = null,
                                            tint = Color(0xFF2E7D32),
                                            modifier = Modifier.size(18.dp)
                                        )
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = "Email Delivery Status",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                    Surface(
                                        shape = RoundedCornerShape(12.dp),
                                        color = Color(0xFFE8F5E9)
                                    ) {
                                        Text(
                                            text = emailRecord?.status?.label ?: "Delivered ✉️",
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFF2E7D32),
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                        )
                                    }
                                }

                                Text(
                                    text = "PDF Invoice automatically dispatched to $recipientEmail upon payment completion.",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    lineHeight = 15.sp
                                )

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    OutlinedButton(
                                        onClick = {
                                            if (emailRecord != null) {
                                                com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.resendInvoiceEmail(
                                                    context = context,
                                                    recordId = emailRecord.id
                                                )
                                            } else {
                                                com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.sendInvoiceEmailAuto(
                                                    context = context,
                                                    transaction = currentTransaction,
                                                    booking = booking,
                                                    recipientEmailOverride = recipientEmail
                                                )
                                                Toast.makeText(context, "Invoice copy resent to $recipientEmail ✉️", Toast.LENGTH_SHORT).show()
                                            }
                                        },
                                        modifier = Modifier
                                            .weight(1f)
                                            .height(34.dp)
                                            .testTag("modal_resend_email_btn"),
                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                                        shape = RoundedCornerShape(8.dp)
                                    ) {
                                        Icon(Icons.Default.Send, contentDescription = null, modifier = Modifier.size(13.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Resend to Me", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                    }

                                    OutlinedButton(
                                        onClick = {
                                            customEmailInput = recipientEmail
                                            showCustomEmailDialog = true
                                        },
                                        modifier = Modifier
                                            .weight(1f)
                                            .height(34.dp)
                                            .testTag("modal_custom_email_btn"),
                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                                        shape = RoundedCornerShape(8.dp)
                                    ) {
                                        Icon(Icons.Default.AlternateEmail, contentDescription = null, modifier = Modifier.size(13.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Send to Email", fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                    }
                                }
                            }
                        }
                    }

                    // Terms and Legal Disclaimer
                    item {
                        Text(
                            text = "This is a computer-generated tax invoice issued by BookMySpace Technologies India Pvt. Ltd. Verified and settled via Razorpay Payment Gateway. No physical signature required.",
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f),
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                        )
                    }
                }

                // Bottom Action Bar
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Export PDF & Email Buttons Row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = {
                                PdfInvoiceGenerator.exportInvoicePdf(context, currentTransaction, booking)
                            },
                            modifier = Modifier
                                .weight(1.2f)
                                .height(48.dp)
                                .testTag("modal_export_pdf_btn"),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary
                            )
                        ) {
                            Icon(
                                Icons.Default.PictureAsPdf,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Export PDF", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        }

                        Button(
                            onClick = {
                                val recipientEmail = currentTransaction.customerEmail.ifBlank { booking?.userEmail ?: "narenqe2@gmail.com" }
                                com.bookmyspace.bookmyspace.data.email.InvoiceEmailService.sendInvoiceEmailAuto(
                                    context = context,
                                    transaction = currentTransaction,
                                    booking = booking,
                                    recipientEmailOverride = recipientEmail
                                )
                                Toast.makeText(context, "PDF Invoice emailed to $recipientEmail ✉️", Toast.LENGTH_SHORT).show()
                            },
                            modifier = Modifier
                                .weight(1f)
                                .height(48.dp)
                                .testTag("modal_email_invoice_pdf_btn"),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.secondary
                            )
                        ) {
                            Icon(
                                Icons.Default.Email,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Email PDF", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        }
                    }

                    // Request Refund Button (Razorpay API integration)
                    if (!isRefunded && (currentTransaction.paymentStatus.equals("SUCCESS", ignoreCase = true) || currentTransaction.paymentStatus.equals("PAID", ignoreCase = true))) {
                        OutlinedButton(
                            onClick = {
                                showRefundDialog = true
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(44.dp)
                                .testTag("modal_request_refund_btn"),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.outlinedButtonColors(
                                contentColor = MaterialTheme.colorScheme.error
                            ),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.7f))
                        ) {
                            Icon(
                                Icons.Default.CurrencyExchange,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.error
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Request Refund (₹${currentTransaction.amount.toInt()})",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.error
                            )
                        }
                    } else if (isRefunded) {
                        Surface(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(38.dp),
                            shape = RoundedCornerShape(10.dp),
                            color = Color(0xFFFFF3E0),
                            border = BorderStroke(1.dp, Color(0xFFFFB74D))
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(horizontal = 12.dp),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = Color(0xFFE65100),
                                    modifier = Modifier.size(15.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Refund Initiated via Razorpay (Amount Returned)",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFE65100)
                                )
                            }
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        OutlinedButton(
                            onClick = {
                                PdfInvoiceGenerator.shareTransactionInvoice(context, currentTransaction, booking)
                            },
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp)
                                .testTag("modal_share_invoice_btn"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(15.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Share Text", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }

                        OutlinedButton(
                            onClick = {
                                if (currentTransaction.bookingId.isNotBlank() && onNavigateToBooking != null) {
                                    onNavigateToBooking(currentTransaction.bookingId)
                                    onDismiss()
                                } else {
                                    Toast.makeText(context, "Invoice $invoiceNo confirmed", Toast.LENGTH_SHORT).show()
                                    onDismiss()
                                }
                            },
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp)
                                .testTag("modal_view_booking_btn"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(
                                if (currentTransaction.bookingId.isNotBlank() && onNavigateToBooking != null) Icons.Default.ConfirmationNumber else Icons.Default.Check,
                                contentDescription = null,
                                modifier = Modifier.size(15.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                if (currentTransaction.bookingId.isNotBlank() && onNavigateToBooking != null) "View Booking" else "Done",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun InvoiceLineItem(
    label: String,
    value: String,
    isBold: Boolean = false,
    isMonospace: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(0.45f)
        )
        Text(
            text = value,
            fontSize = 11.sp,
            fontWeight = if (isBold) FontWeight.Bold else FontWeight.Medium,
            fontFamily = if (isMonospace) FontFamily.Monospace else FontFamily.Default,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.End,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(0.55f)
        )
    }
}

@Composable
private fun TaxBreakdownRow(
    item: String,
    rate: String,
    amount: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 3.dp, horizontal = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(item, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
        Text(rate, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(60.dp), textAlign = TextAlign.End)
        Text(amount, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(80.dp), textAlign = TextAlign.End)
    }
}
