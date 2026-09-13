import 'package:flutter/material.dart';

/// Small colored chip for a payment/booking status value. Colors are
/// derived from the theme's semantic colors, not hardcoded brand hex
/// values, so the chip stays correct in light and dark mode.
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.label, required this.tone});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    switch (tone) {
      case ChipTone.positive:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        break;
      case ChipTone.warning:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        break;
      case ChipTone.negative:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        break;
      case ChipTone.neutral:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum ChipTone { positive, warning, negative, neutral }

ChipTone toneForPaymentStatus(String status) {
  switch (status) {
    case 'captured':
      return ChipTone.positive;
    case 'pending':
    case 'authorized':
      return ChipTone.warning;
    case 'failed':
      return ChipTone.negative;
    case 'refunded':
    case 'partially_refunded':
      return ChipTone.neutral;
    default:
      return ChipTone.neutral;
  }
}

ChipTone toneForBookingStatus(String status) {
  switch (status) {
    case 'confirmed':
    case 'completed':
      return ChipTone.positive;
    case 'pending':
    case 'held':
    case 'awaiting_owner_approval':
      return ChipTone.warning;
    case 'cancelled':
    case 'owner_rejected':
    case 'approval_expired':
    case 'no_show':
      return ChipTone.negative;
    default:
      return ChipTone.neutral;
  }
}

ChipTone toneForReconciliationFlag(String flag) {
  return flag == 'ok' ? ChipTone.positive : ChipTone.negative;
}
