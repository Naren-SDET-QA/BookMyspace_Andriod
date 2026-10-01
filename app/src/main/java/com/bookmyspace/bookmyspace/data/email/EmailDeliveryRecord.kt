package com.bookmyspace.bookmyspace.data.email

enum class EmailDeliveryStatus(val label: String, val badgeColorHex: String) {
    QUEUED("Queued", "#FFA000"),
    SENDING("Sending...", "#1976D2"),
    SENT("Sent", "#2E7D32"),
    DELIVERED("Delivered to Inbox ✉️", "#2E7D32"),
    FAILED("Delivery Failed", "#C62828")
}

data class EmailDeliveryRecord(
    val id: String,
    val recipientEmail: String,
    val recipientName: String,
    val bookingId: String,
    val transactionId: String,
    val invoiceNumber: String,
    val venueName: String,
    val amount: Double,
    val timestamp: Long = System.currentTimeMillis(),
    val status: EmailDeliveryStatus = EmailDeliveryStatus.DELIVERED,
    val subject: String,
    val htmlContent: String,
    val plainTextContent: String,
    val attachmentFileName: String,
    val attachmentSizeBytes: Long = 0L,
    val attachmentPath: String? = null,
    val providerResponse: String? = "250 2.0.0 OK: message queued 1029482-bms-smtp-relay",
    val sentAt: Long = System.currentTimeMillis(),
    val deliveredAt: Long = System.currentTimeMillis(),
    val retryCount: Int = 0,
    val errorMessage: String? = null
)
