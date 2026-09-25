import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/payment_transaction.dart';
import 'payment_status_chip.dart';

/// Compact card presentation of one ledger row, used on narrow (mobile)
/// widths. Read-only — no tap-to-mutate affordances.
class TransactionRowCard extends StatelessWidget {
  const TransactionRowCard({super.key, required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: transaction.hasReconciliationException
            ? Border.all(color: scheme.error.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  transaction.bookingReference,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${transaction.currency} ${transaction.amount.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (transaction.venueName != null) ...[
            const SizedBox(height: 2),
            Text(
              transaction.venueName!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PaymentStatusChip(
                label: transaction.paymentStatus,
                tone: toneForPaymentStatus(transaction.paymentStatus),
              ),
              PaymentStatusChip(
                label: transaction.bookingStatus,
                tone: toneForBookingStatus(transaction.bookingStatus),
              ),
              if (transaction.hasReconciliationException)
                PaymentStatusChip(
                  label: transaction.reconciliationFlag,
                  tone: toneForReconciliationFlag(transaction.reconciliationFlag),
                ),
              if (!transaction.webhookReceived)
                PaymentStatusChip(
                  label: l10n.webhookMissing,
                  tone: ChipTone.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
