import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/payment_transaction.dart';
import '../providers/admin_payment_providers.dart';
import '../widgets/payment_status_chip.dart';
import '../widgets/transaction_filter_bar.dart';
import '../widgets/transaction_row_card.dart';

/// Read-only, paginated Transaction Ledger for Admin Payment Operations.
/// This screen never issues refunds, confirms bookings, or otherwise
/// mutates payment/booking state — every row here is observability only.
class AdminTransactionLedgerScreen extends ConsumerWidget {
  const AdminTransactionLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pageAsync = ref.watch(transactionLedgerProvider);
    final query = ref.watch(transactionLedgerQueryProvider);
    final notifier = ref.read(transactionLedgerQueryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminTransactionLedger)),
      body: Column(
        children: [
          TransactionFilterBar(
            filter: query.filter,
            onChanged: notifier.setFilter,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(transactionLedgerProvider.future),
              child: pageAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(transactionLedgerProvider),
                ),
                data: (page) => _LedgerBody(page: page),
              ),
            ),
          ),
          if (pageAsync.hasValue)
            _PaginationBar(
              page: pageAsync.value!,
              onPageChanged: notifier.setPage,
            ),
        ],
      ),
    );
  }
}

class _LedgerBody extends StatelessWidget {
  const _LedgerBody({required this.page});

  final PaymentTransactionPage page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (page.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: l10n.noTransactionsInPeriod,
            message: l10n.noTransactionsInPeriodMessage,
          ),
        ],
      );
    }

    return ResponsiveLayoutBuilder(
      builder: (context, responsive) {
        if (responsive.isCompact) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: page.items.length,
            itemBuilder: (context, index) =>
                TransactionRowCard(transaction: page.items[index]),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: responsive.availableWidth),
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.columnReference)),
                DataColumn(label: Text(l10n.columnVenue)),
                DataColumn(label: Text(l10n.columnAmount)),
                DataColumn(label: Text(l10n.paymentStatusLabel)),
                DataColumn(label: Text(l10n.bookingStatusLabel)),
                DataColumn(label: Text(l10n.approvalStatusLabel)),
                DataColumn(label: Text(l10n.webhookStatusLabel)),
                DataColumn(label: Text(l10n.columnCreatedAt)),
              ],
              rows: page.items.map((tx) {
                return DataRow(
                  color: tx.hasReconciliationException
                      ? WidgetStatePropertyAll(
                          Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.25),
                        )
                      : null,
                  cells: [
                    DataCell(Text(tx.bookingReference)),
                    DataCell(Text(tx.venueName ?? '-')),
                    DataCell(
                        Text('${tx.currency} ${tx.amount.toStringAsFixed(2)}')),
                    DataCell(PaymentStatusChip(
                      label: tx.paymentStatus,
                      tone: toneForPaymentStatus(tx.paymentStatus),
                    )),
                    DataCell(PaymentStatusChip(
                      label: tx.bookingStatus,
                      tone: toneForBookingStatus(tx.bookingStatus),
                    )),
                    DataCell(Text(tx.approvalStatus)),
                    DataCell(Icon(
                      tx.webhookReceived
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: tx.webhookReceived
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    )),
                    DataCell(Text(_formatDate(tx.paymentCreatedAt))),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.page, required this.onPageChanged});

  final PaymentTransactionPage page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${l10n.totalTransactions}: ${page.totalCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: page.hasPreviousPage
                      ? () => onPageChanged(page.page - 1)
                      : null,
                ),
                Text('${page.page} / ${page.totalPages}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: page.hasNextPage
                      ? () => onPageChanged(page.page + 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
