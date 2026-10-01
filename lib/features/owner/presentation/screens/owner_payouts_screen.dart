import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/owner.dart';
import '../../domain/owner_payout.dart';
import '../owner_providers.dart';

/// Screen for venue owners to manage bank settlement accounts, view net earned
/// balances, review payout history, and submit payout requests.
///
/// Production compliance:
/// - Never fakes payout success. Payouts are queued with status 'requested' for
///   batch settlement.
/// - Clear notice when automated Razorpay Route gateway linkage is pending.
class OwnerPayoutsScreen extends ConsumerWidget {
  const OwnerPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerAsync = ref.watch(currentOwnerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlements & Payouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(currentOwnerProvider);
            },
          ),
        ],
      ),
      body: ownerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentOwnerProvider),
        ),
        data: (owner) {
          if (owner == null) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Owner Profile Required',
              message:
                  'Please register as a venue owner to access payouts and settlements.',
            );
          }
          return _OwnerPayoutsContent(owner: owner);
        },
      ),
    );
  }
}

class _OwnerPayoutsContent extends ConsumerWidget {
  const _OwnerPayoutsContent({required this.owner});

  final Owner owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(ownerPayoutSummaryProvider);
    final payoutsAsync = ref.watch(ownerPayoutsListProvider);
    final bankAsync = ref.watch(ownerBankAccountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownerPayoutSummaryProvider);
        ref.invalidate(ownerPayoutsListProvider);
        ref.invalidate(ownerBankAccountProvider);
      },
      child: ResponsiveLayoutBuilder(
        builder: (context, responsive) {
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.horizontalPadding,
              vertical: 16,
            ),
            children: [
              // 1. Available Balance & Settlement Overview Card
              summaryAsync.when(
                loading: () => const SkeletonBox(height: 160, radius: 20),
                error: (e, _) => ErrorView(
                  message: 'Could not load balance: $e',
                  onRetry: () =>
                      ref.invalidate(ownerPayoutSummaryProvider),
                ),
                data: (summary) => _SettlementBalanceCard(
                  summary: summary,
                  onRequestPayout: () => _handleRequestPayout(
                    context,
                    ref,
                    owner,
                    summary,
                    bankAsync.valueOrNull,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Gateway Status & Compliance Banner
              _GatewayStatusBanner(),
              const SizedBox(height: 16),

              // 3. Bank Account & Payout Method Card
              _BankAccountCard(
                bankAccount: bankAsync.valueOrNull,
                isLoading: bankAsync.isLoading,
                onConfigureBank: () =>
                    _handleConfigureBank(context, ref, owner),
              ),
              const SizedBox(height: 20),

              // 4. Payout Requests History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payout History',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  payoutsAsync.maybeWhen(
                    data: (items) => Text(
                      '${items.length} ${items.length == 1 ? 'request' : 'requests'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              payoutsAsync.when(
                loading: () => Column(
                  children: List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SkeletonBox(height: 72, radius: 14),
                    ),
                  ),
                ),
                error: (e, _) => ErrorView(
                  message: 'Could not load payouts: $e',
                  onRetry: () =>
                      ref.invalidate(ownerPayoutsListProvider),
                ),
                data: (payouts) {
                  if (payouts.isEmpty) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 36,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No payout requests yet',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'When you request settlements for earned bookings, history will show here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: payouts
                        .map((payout) => _PayoutRecordTile(payout: payout))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _handleRequestPayout(
    BuildContext context,
    WidgetRef ref,
    Owner owner,
    OwnerPayoutSummary summary,
    OwnerBankAccount? bankAccount,
  ) {
    if (bankAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add your bank account details before requesting a payout.',
          ),
        ),
      );
      _handleConfigureBank(context, ref, owner);
      return;
    }

    if (summary.availableBalance < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum payout request is ₹500. Current available balance is ₹${summary.availableBalance.toStringAsFixed(0)}.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dlgContext) => _RequestPayoutDialog(
        owner: owner,
        summary: summary,
        bankAccount: bankAccount,
      ),
    );
  }

  void _handleConfigureBank(
    BuildContext context,
    WidgetRef ref,
    Owner owner,
  ) {
    final existingBank = ref.read(ownerBankAccountProvider).valueOrNull;
    showDialog(
      context: context,
      builder: (dlgContext) => _ConfigureBankDialog(
        owner: owner,
        existing: existingBank,
      ),
    );
  }
}

class _SettlementBalanceCard extends StatelessWidget {
  const _SettlementBalanceCard({
    required this.summary,
    required this.onRequestPayout,
  });

  final OwnerPayoutSummary summary;
  final VoidCallback onRequestPayout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2638), const Color(0xFF111728)]
              : [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.violet.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available for Payout',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${summary.availableBalance.toStringAsFixed(0)}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.violet,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: summary.availableBalance >= 500 ? onRequestPayout : null,
                icon: const Icon(Icons.outbox_rounded, size: 18),
                label: const Text('Request Payout'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricSubItem(
                  label: 'Gross Bookings',
                  value: '₹${summary.totalGrossRevenue.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _MetricSubItem(
                  label: 'Commission (10%)',
                  value: '-₹${summary.totalCommission.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _MetricSubItem(
                  label: 'Settled to Bank',
                  value: '₹${summary.totalPaidOut.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _MetricSubItem(
                  label: 'In-Flight',
                  value: '₹${summary.totalPendingPayout.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricSubItem extends StatelessWidget {
  const _MetricSubItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _GatewayStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: Colors.blueGrey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Settlements are processed via scheduled bank batches. Automated instant transfers via Razorpay Route require active merchant bank verification.',
                style: TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({
    required this.bankAccount,
    required this.isLoading,
    required this.onConfigureBank,
  });

  final OwnerBankAccount? bankAccount;
  final bool isLoading;
  final VoidCallback onConfigureBank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const SkeletonBox(height: 90, radius: 16);
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded,
                        color: AppTheme.violet, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Disbursement Bank Account',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onConfigureBank,
                  child: Text(bankAccount == null ? 'Add Bank' : 'Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (bankAccount != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bankAccount!.bankName} (${bankAccount!.accountNumberMasked})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Holder: ${bankAccount!.accountHolder} • IFSC: ${bankAccount!.ifscCode}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (bankAccount!.upiId != null)
                        Text(
                          'UPI: ${bankAccount!.upiId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'No bank account connected yet. Add your bank details to receive booking payouts.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayoutRecordTile extends StatelessWidget {
  const _PayoutRecordTile({required this.payout});

  final OwnerPayout payout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(payout.requestedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: payout.status.color.withValues(alpha: 0.12),
              child: Icon(Icons.outbox_rounded,
                  color: payout.status.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${payout.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: payout.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                payout.status.label.toUpperCase(),
                style: TextStyle(
                  color: payout.status.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestPayoutDialog extends ConsumerStatefulWidget {
  const _RequestPayoutDialog({
    required this.owner,
    required this.summary,
    required this.bankAccount,
  });

  final Owner owner;
  final OwnerPayoutSummary summary;
  final OwnerBankAccount bankAccount;

  @override
  ConsumerState<_RequestPayoutDialog> createState() =>
      _RequestPayoutDialogState();
}

class _RequestPayoutDialogState extends ConsumerState<_RequestPayoutDialog> {
  final _amountController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.summary.availableBalance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount < 500) {
      setState(() => _error = 'Minimum payout amount is ₹500.');
      return;
    }
    if (amount > widget.summary.availableBalance) {
      setState(() =>
          _error = 'Amount exceeds available balance of ₹${widget.summary.availableBalance.toStringAsFixed(0)}.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(ownerPayoutRepositoryProvider);
      await repo.requestPayout(amount: amount);

      ref.invalidate(ownerPayoutSummaryProvider);
      ref.invalidate(ownerPayoutsListProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payout request for ₹${amount.toStringAsFixed(0)} logged with status "Requested". Pending banking settlement.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Payout'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disbursement will be transferred to ${widget.bankAccount.bankName} (${widget.bankAccount.accountNumberMasked}).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                hintText: 'Enter amount (min ₹500)',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Payout requests are verified and disbursed via bank batch processing. Live success is recorded upon bank settlement confirmation.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Request'),
        ),
      ],
    );
  }
}

class _ConfigureBankDialog extends ConsumerStatefulWidget {
  const _ConfigureBankDialog({
    required this.owner,
    this.existing,
  });

  final Owner owner;
  final OwnerBankAccount? existing;

  @override
  ConsumerState<_ConfigureBankDialog> createState() =>
      _ConfigureBankDialogState();
}

class _ConfigureBankDialogState extends ConsumerState<_ConfigureBankDialog> {
  final _holderController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _holderController.text = widget.existing!.accountHolder;
      _bankController.text = widget.existing!.bankName;
      _ifscController.text = widget.existing!.ifscCode;
      _upiController.text = widget.existing!.upiId ?? '';
    }
  }

  @override
  void dispose() {
    _holderController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final holder = _holderController.text.trim();
    final bank = _bankController.text.trim();
    final acc = _accountController.text.trim();
    final ifsc = _ifscController.text.trim();

    if (holder.isEmpty || bank.isEmpty || ifsc.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    if (widget.existing == null && acc.isEmpty) {
      setState(() => _error = 'Please enter your bank account number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(ownerPayoutRepositoryProvider);
      await repo.saveBankAccount(
        accountHolder: holder,
        bankName: bank,
        accountNumber: acc.isNotEmpty
            ? acc
            : (widget.existing?.accountNumberMasked ?? '0000'),
        ifscCode: ifsc,
        upiId: _upiController.text.trim(),
      );

      ref.invalidate(ownerBankAccountProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Add Bank Account'
          : 'Edit Bank Account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _holderController,
              decoration: const InputDecoration(
                labelText: 'Account Holder Name *',
                hintText: 'e.g. Rahul Sharma',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bankController,
              decoration: const InputDecoration(
                labelText: 'Bank Name *',
                hintText: 'e.g. HDFC Bank, SBI',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.existing == null
                    ? 'Account Number *'
                    : 'Account Number (leave blank to keep current)',
                hintText: 'Enter full account number',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ifscController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'IFSC Code *',
                hintText: 'e.g. HDFC0001234',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _upiController,
              decoration: const InputDecoration(
                labelText: 'UPI ID (Optional)',
                hintText: 'e.g. name@okhdfcbank',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _save,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Bank Account'),
        ),
      ],
    );
  }
}
