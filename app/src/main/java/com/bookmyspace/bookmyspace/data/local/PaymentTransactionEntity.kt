package com.bookmyspace.bookmyspace.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room database entity storing local payment transaction records and status.
 */
@Entity(tableName = "payment_transactions")
data class PaymentTransactionEntity(
    @PrimaryKey
    val transactionId: String,
    val bookingId: String,
    val venueId: String = "",
    val venueName: String = "",
    val amount: Double = 0.0,
    val currency: String = "INR",
    val paymentStatus: String = "SUCCESS", // "SUCCESS", "FAILED", "CANCELLED", "PENDING", "REFUNDED"
    val paymentMethod: String = "Razorpay",
    val razorpayOrderId: String? = null,
    val razorpaySignature: String? = null,
    val isSignatureVerified: Boolean = true,
    val webhookEvent: String? = null,
    val customerName: String = "",
    val customerEmail: String = "",
    val customerPhone: String = "",
    val failureReason: String? = null,
    val timestamp: Long = System.currentTimeMillis(),
    val notes: String = ""
)
