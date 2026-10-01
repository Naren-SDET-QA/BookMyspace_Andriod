class InvoiceDocument {
  const InvoiceDocument({
    required this.id,
    required this.number,
    required this.documentType,
    required this.status,
    required this.currency,
    required this.subtotal,
    required this.discount,
    required this.taxTotal,
    required this.feeTotal,
    required this.total,
    required this.paid,
    required this.due,
    required this.refund,
    required this.config,
    required this.snapshot,
    required this.issuedAt,
    this.sacCode = '',
    this.sellerGstin = '',
    this.taxMode = '',
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.amountInWords = '',
  });
  final String id, number, documentType, status, currency;
  final double subtotal, discount, taxTotal, feeTotal, total, paid, due, refund;
  final Map<String, dynamic> config, snapshot;
  final DateTime issuedAt;
  final String sacCode, sellerGstin, taxMode, amountInWords;
  final double cgst, sgst, igst;

  factory InvoiceDocument.fromJson(Map<String, dynamic> json) =>
      InvoiceDocument(
        id: json['id'] as String? ?? '',
        number: json['invoice_number'] as String? ?? '',
        documentType: json['document_type'] as String? ?? 'receipt',
        status: json['status'] as String? ?? 'issued',
        currency: json['currency'] as String? ?? 'INR',
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        taxTotal: (json['tax_total'] as num?)?.toDouble() ?? 0,
        feeTotal: (json['fee_total'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        paid: (json['paid'] as num?)?.toDouble() ?? 0,
        due: (json['due'] as num?)?.toDouble() ?? 0,
        refund: (json['refund'] as num?)?.toDouble() ?? 0,
        config: Map<String, dynamic>.from(
          json['config_snapshot'] as Map? ?? const {},
        ),
        snapshot: Map<String, dynamic>.from(
          json['invoice_snapshot'] as Map? ?? const {},
        ),
        issuedAt:
            DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
            DateTime(1970),
        sacCode: json['sac_code']?.toString() ?? '',
        sellerGstin: json['seller_gstin']?.toString() ?? '',
        taxMode: json['tax_mode']?.toString() ?? '',
        cgst: (json['cgst_amount'] as num?)?.toDouble() ?? 0,
        sgst: (json['sgst_amount'] as num?)?.toDouble() ?? 0,
        igst: (json['igst_amount'] as num?)?.toDouble() ?? 0,
        amountInWords: json['amount_in_words']?.toString() ?? '',
      );
}

abstract interface class InvoiceRepository {
  Future<Map<String, dynamic>> config();
  Future<void> saveConfig(Map<String, dynamic> config);
  Future<InvoiceDocument> invoice(String id);
  Future<String> issue({
    required String bookingId,
    required String documentType,
    required Map<String, dynamic> snapshot,
    String? parentInvoiceId,
  });
  Future<String> issueCommerce({
    required String referenceId,
    String documentType = 'receipt',
    Map<String, dynamic> snapshot = const {},
  });
}
