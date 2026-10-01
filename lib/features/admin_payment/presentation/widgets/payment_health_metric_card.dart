import 'package:flutter/material.dart';

/// A single metric tile on the Payment Health dashboard. Purely
/// presentational — the value it renders always comes from the real
/// `admin_get_payment_health` RPC response, never a placeholder.
class PaymentHealthMetricCard extends StatelessWidget {
  const PaymentHealthMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasis ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: emphasis ? scheme.onPrimaryContainer : scheme.primary,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasis ? scheme.onPrimaryContainer : null,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: emphasis
                      ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                      : scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
