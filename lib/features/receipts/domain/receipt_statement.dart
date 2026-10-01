import 'receipt.dart';

/// The words a receipt is allowed to say.
///
/// Every decision about what the document claims lives here rather than in the
/// PDF renderer or the screen, so the printed document and the on-screen view
/// cannot disagree about whether something is a receipt, what it is called, or
/// which caveats it carries.
///
/// The recurring principle: never state something the data does not support.
/// A booking with no captured payment is a *statement*, not a receipt. A field
/// nobody recorded is listed as omitted rather than printed as a zero. A
/// breakdown that does not add up says so instead of being presented as
/// arithmetic that works.
class ReceiptStatement {
  const ReceiptStatement(this.result);

  final ReceiptResult result;

  ReceiptDocument get document => result.document;

  /// True when a receipt number exists, i.e. payment was captured and recorded.
  bool get isReceipt => result.receiptIssued;

  String get title => isReceipt ? 'Payment Receipt' : 'Payment Statement';

  /// The number, or an explicit statement of why there is none.
  ///
  /// Never a blank: an empty receipt number on a payment document reads as an
  /// oversight rather than as a fact about the booking.
  String get numberLine {
    final number = result.receiptNumber;
    if (number != null && number.trim().isNotEmpty) return number.trim();
    return isReceipt ? 'Number pending' : 'No receipt number issued';
  }

  /// The itemised charge lines, in print order.
  List<ReceiptRow> get rows => document.lineItems.rows();

  String get totalLabel => 'Total paid';

  double get total => document.totalPaid;

  /// The itemised lines disagree with the amount charged.
  ///
  /// Recomputed from the rows rather than trusting the server's flag, so a
  /// server that stops sending `reconciles` cannot make the notice disappear.
  bool get needsReconciliationNotice => !document.lineItemsReconcile;

  /// What to print when [needsReconciliationNotice] is true.
  String get reconciliationNotice {
    final components = document.lineItems.componentTotal;
    final difference = document.unreconciledDifference;
    return 'The itemised lines total ${document.formatMoney(components)}, '
        'which differs from the amount charged by '
        '${document.formatMoney(difference.abs())}. '
        'The amount charged is the authoritative figure.';
  }

  /// Everything this document cannot state, said out loud.
  ///
  /// Order matters: the reason it is not a receipt comes first, because that is
  /// the single most important thing a reader needs to know.
  List<String> get notes {
    final notes = <String>[];

    if (!isReceipt) {
      notes.add(
        'No captured payment is recorded for this booking, so no receipt '
        'number has been issued. This document is a statement of the amount '
        'charged, not evidence of payment.',
      );
    }

    if (document.platformFeeOmitted) {
      notes.add(
        'Platform fees are not itemised. No platform commission is recorded '
        'for this booking, and a zero-valued line would assert a fact that was '
        'never captured.',
      );
    }

    final rate = document.lineItems.taxRateReference;
    if (rate != null) {
      notes.add(
        "The venue's configured tax rate at the time of issue was "
        '${formatRate(rate)}%. It is shown for reference only: the tax amount '
        'above is the amount actually charged and is not re-derived from this '
        'rate.',
      );
    }

    notes.add(
      'This document is generated from an immutable snapshot taken when the '
      'receipt was first issued, so it does not change if the booking, venue '
      'or pricing is edited later.',
    );

    return notes;
  }

  /// A rate without trailing zeros, so 18.00 prints as `18` and 12.50 as `12.5`.
  static String formatRate(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
