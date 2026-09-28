class InvoiceArtifact {
  const InvoiceArtifact({
    required this.invoiceNumber,
    this.invoiceId,
    this.signedUrl,
    this.emailQueued = false,
    this.notificationQueued = false,
    this.taxDetails,
  });

  final String invoiceNumber;
  final String? invoiceId;
  final String? signedUrl;

  /// True when generate-invoice enqueued `email_outbox` with the service role.
  /// The client never inserts into `email_outbox`.
  final bool emailQueued;

  /// True when the server queued a notification. Client never writes notifications.
  final bool notificationQueued;

  /// The server-frozen GST classification used for the issued document.
  final Map<String, dynamic>? taxDetails;

  bool get canOpenPdf => signedUrl != null && signedUrl!.isNotEmpty;
  bool get canShare => canOpenPdf;

  factory InvoiceArtifact.fromJson(Map<String, dynamic> json) {
    final invoice = json['invoice'] is Map
        ? Map<String, dynamic>.from(json['invoice'] as Map)
        : json;
    return InvoiceArtifact(
      invoiceNumber: invoice['invoice_number'] as String? ?? '',
      invoiceId: invoice['id'] as String?,
      signedUrl: json['signed_url'] as String?,
      emailQueued: json['email_queued'] == true,
      notificationQueued: json['notification_queued'] == true,
      taxDetails: json['tax_details'] is Map
          ? Map<String, dynamic>.from(json['tax_details'] as Map)
          : null,
    );
  }
}

abstract interface class InvoiceRepository {
  Future<InvoiceArtifact> generate(String bookingId);

  Future<bool> resend(String invoiceId, {String? recipientEmail});
}
