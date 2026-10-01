import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/payment_transaction.dart';

/// Filter controls for the Transaction Ledger. Purely a filter editor —
/// it has no mutation affordances of any kind.
class TransactionFilterBar extends StatefulWidget {
  const TransactionFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final PaymentTransactionFilter filter;
  final ValueChanged<PaymentTransactionFilter> onChanged;

  @override
  State<TransactionFilterBar> createState() => _TransactionFilterBarState();
}

class _TransactionFilterBarState extends State<TransactionFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filter.search);
  }

  @override
  void didUpdateWidget(covariant TransactionFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter.search != _searchController.text &&
        widget.filter.search == null) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('adminPaymentLedgerSearchField'),
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.searchByReferenceOrOrderId,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (value) {
              widget.onChanged(
                widget.filter.copyWith(
                  search: value.trim().isEmpty ? null : value.trim(),
                  clearSearch: value.trim().isEmpty,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusDropdown(
                  label: l10n.paymentStatusLabel,
                  value: widget.filter.paymentStatus,
                  options: kPaymentStatusValues,
                  onChanged: (value) => widget.onChanged(
                    widget.filter.copyWith(
                      paymentStatus: value,
                      clearPaymentStatus: value == null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusDropdown(
                  label: l10n.bookingStatusLabel,
                  value: widget.filter.bookingStatus,
                  options: kBookingStatusValues,
                  onChanged: (value) => widget.onChanged(
                    widget.filter.copyWith(
                      bookingStatus: value,
                      clearBookingStatus: value == null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String?>(
      initialSelection: value,
      label: Text(label),
      onSelected: onChanged,
      dropdownMenuEntries: [
        DropdownMenuEntry(value: null, label: label),
        ...options.map(
          (option) => DropdownMenuEntry(value: option, label: option),
        ),
      ],
    );
  }
}
