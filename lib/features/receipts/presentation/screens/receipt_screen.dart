import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../application/receipt_pdf.dart';
import '../../domain/receipt.dart';
import '../../domain/receipt_statement.dart';
import '../receipt_providers.dart';

/// The itemized receipt for a booking, with the PDF as a shareable artifact.
///
/// The screen and the PDF are rendered from the same [ReceiptStatement], so the
/// two cannot disagree about whether the document is a receipt or a statement,
/// or about which caveats it carries.
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _busy = false;
  String? _actionError;

  String _fileName(ReceiptStatement statement) {
    final reference = statement.isReceipt
        ? statement.numberLine
        : statement.document.bookingRef;
    final safe = reference.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    return '${statement.isReceipt ? 'receipt' : 'statement'}-$safe.pdf';
  }

  /// Runs a PDF action, surfacing a failure on screen rather than letting the
  /// button appear to have done nothing.
  Future<void> _run(Future<void> Function(ReceiptStatement) action) async {
    final result = ref.read(receiptProvider(widget.bookingId)).valueOrNull;
    if (result == null) return;

    setState(() {
      _busy = true;
      _actionError = null;
    });

    try {
      await action(ReceiptStatement(result));
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = 'The document could not be prepared. $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(ReceiptStatement statement) async {
    final bytes = await ReceiptPdf.build(
      ReceiptResult(
        document: statement.document,
        receiptIssued: statement.isReceipt,
        receiptNumber: statement.isReceipt ? statement.numberLine : null,
      ),
    );
    await Printing.sharePdf(bytes: bytes, filename: _fileName(statement));
  }

  Future<void> _print(ReceiptStatement statement) async {
    final bytes = await ReceiptPdf.build(
      ReceiptResult(
        document: statement.document,
        receiptIssued: statement.isReceipt,
        receiptNumber: statement.isReceipt ? statement.numberLine : null,
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _fileName(statement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(receiptProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          async.valueOrNull == null
              ? 'Receipt'
              : ReceiptStatement(async.value!).title,
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(receiptProvider(widget.bookingId)),
        ),
        data: (result) {
          final statement = ReceiptStatement(result);
          return Column(
            children: [
              if (_actionError != null) _ActionErrorBanner(message: _actionError!),
              Expanded(child: _ReceiptBody(statement: statement)),
              _ActionBar(
                busy: _busy,
                onShare: () => _run(_share),
                onPrint: () => _run(_print),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionErrorBanner extends StatelessWidget {
  const _ActionErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({required this.statement});

  final ReceiptStatement statement;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, responsive) {
        final document = statement.document;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            responsive.horizontalPadding,
            16,
            responsive.horizontalPadding,
            24,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(statement: statement),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'DOCUMENT',
                      children: [
                        _KeyValue('Booking reference', document.bookingRef),
                        _KeyValue('Booking status', _titleCase(document.status)),
                        _KeyValue('Issued on', _dateTime(document.issuedAt)),
                        _KeyValue('Currency', document.currency),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'BILLED TO',
                      children: [
                        _KeyValue('Name', _orDash(document.guest.name), bold: true),
                        if (_present(document.guest.email))
                          _KeyValue('Email', document.guest.email!),
                        if (_present(document.guest.phone))
                          _KeyValue('Phone', document.guest.phone!),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'VENUE',
                      children: [
                        _KeyValue('Name', _orDash(document.venue.name), bold: true),
                        if (document.venue.formattedAddress.isNotEmpty)
                          _KeyValue('Address', document.venue.formattedAddress),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'BOOKING',
                      children: [
                        _KeyValue('Space', _orDash(document.slot.label)),
                        _KeyValue(
                          'Date',
                          document.slot.bookDate == null
                              ? '—'
                              : _date(document.slot.bookDate!),
                        ),
                        _KeyValue(
                          'Time',
                          _timeRange(
                            document.slot.startTime,
                            document.slot.endTime,
                          ),
                        ),
                        _KeyValue(
                          'Quantity',
                          document.slot.quantity?.toString() ?? '—',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ItemisationCard(statement: statement),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'PAYMENT',
                      children: [
                        _KeyValue(
                          'Method',
                          _present(document.paymentMethod)
                              ? document.paymentMethod!.toUpperCase()
                              : '—',
                        ),
                        _KeyValue('Provider', _orDash(document.paymentProvider)),
                        _KeyValue('Reference', _orDash(document.paymentRef)),
                      ],
                    ),
                    if (statement.notes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'NOTES',
                        children: [
                          for (final note in statement.notes) _Bullet(note),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.statement});

  final ReceiptStatement statement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = statement.isReceipt ? AppTheme.brand : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                statement.isReceipt
                    ? Icons.receipt_long_rounded
                    : Icons.description_outlined,
                color: accent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statement.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statement.numberLine,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!statement.isReceipt) ...[
            const SizedBox(height: 12),
            Text(
              'No payment is recorded for this booking, so this is a statement '
              'of the amount charged rather than a receipt.',
              style: theme.textTheme.bodySmall?.copyWith(color: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemisationCard extends StatelessWidget {
  const _ItemisationCard({required this.statement});

  final ReceiptStatement statement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final document = statement.document;

    return _SectionCard(
      title: 'ITEMISATION',
      children: [
        for (final row in statement.rows)
          _AmountLine(
            label: row.label,
            amount: row.signedAmount,
            document: document,
          ),
        const SizedBox(height: 6),
        const Divider(height: 1),
        const SizedBox(height: 8),
        _AmountLine(
          label: statement.totalLabel,
          amount: statement.total,
          document: document,
          emphasised: true,
        ),
        if (statement.needsReconciliationNotice) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statement.reconciliationNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: AppTheme.brand,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.amount,
    required this.document,
    this.emphasised = false,
  });

  final String label;
  final double amount;
  final ReceiptDocument document;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasised
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(document.formatMoney(amount), style: style),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: theme.textTheme.bodySmall),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.onShare,
    required this.onPrint,
  });

  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.6),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPrint,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onShare,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Save / Share PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Formatting — mirrors the PDF renderer so both read the same way.
// -----------------------------------------------------------------------------

bool _present(String? value) => value != null && value.trim().isNotEmpty;

String _orDash(String? value) => _present(value) ? value!.trim() : '—';

String _date(DateTime value) => DateFormat('d MMM yyyy').format(value);

String _dateTime(DateTime? value) => value == null
    ? '—'
    : DateFormat('d MMM yyyy, h:mm a').format(value.toLocal());

String _timeRange(String? start, String? end) {
  final from = _clock(start);
  final to = _clock(end);
  if (from == null && to == null) return '—';
  if (from == null) return to!;
  if (to == null) return from;
  return '$from – $to';
}

String? _clock(String? raw) {
  if (!_present(raw)) return null;
  final parts = raw!.trim().split(':');
  if (parts.length < 2) return raw.trim();
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}

String _titleCase(String raw) {
  if (raw.isEmpty) return '—';
  return raw
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
