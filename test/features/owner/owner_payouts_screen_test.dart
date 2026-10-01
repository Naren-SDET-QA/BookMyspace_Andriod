import 'package:bookmyspace/features/owner/domain/owner.dart';
import 'package:bookmyspace/features/owner/domain/owner_payout.dart';
import 'package:bookmyspace/features/owner/presentation/owner_providers.dart';
import 'package:bookmyspace/features/owner/presentation/screens/owner_payouts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOwnerPayoutRepository implements OwnerPayoutRepository {
  _FakeOwnerPayoutRepository({
    required this.summary,
    required this.payouts,
    this.bankAccount,
  });

  OwnerPayoutSummary summary;
  final List<OwnerPayout> payouts;
  OwnerBankAccount? bankAccount;

  @override
  Future<String> getOwnerOrgId() async => 'org-123';

  @override
  Future<OwnerPayoutSummary> getPayoutSummary([String? orgId]) async => summary;

  @override
  Future<List<OwnerPayout>> getPayouts([String? orgId]) async => payouts;

  @override
  Future<OwnerBankAccount?> getBankAccount([String? orgId]) async => bankAccount;

  @override
  Future<void> saveBankAccount({
    String? orgId,
    required String accountHolder,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
  }) async {
    bankAccount = OwnerBankAccount(
      id: 'bank-1',
      orgId: orgId ?? 'org-123',
      accountHolder: accountHolder,
      bankName: bankName,
      accountNumberMasked: '•••• •••• ${accountNumber.substring(accountNumber.length - 4)}',
      ifscCode: ifscCode,
      upiId: upiId,
      isVerified: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<OwnerPayout> requestPayout({
    String? orgId,
    required double amount,
  }) async {
    final newPayout = OwnerPayout(
      id: 'payout-new',
      orgId: orgId ?? 'org-123',
      amount: amount,
      commissionAmount: amount * 0.10,
      status: PayoutStatus.requested,
      provider: 'razorpay',
      requestedAt: DateTime.now(),
    );
    payouts.insert(0, newPayout);
    return newPayout;
  }
}

void main() {
  const testOwner = Owner(
    id: 'owner-123',
    userId: 'user-123',
    name: 'Rajesh Kumar',
    email: 'rajesh@turfarena.in',
  );

  testWidgets('OwnerPayoutsScreen displays balance, bank details, and payout history',
      (tester) async {
    final fakeRepo = _FakeOwnerPayoutRepository(
      summary: const OwnerPayoutSummary(
        totalGrossRevenue: 10000,
        totalCommission: 1000,
        totalPaidOut: 4000,
        totalPendingPayout: 2000,
        availableBalance: 3000,
      ),
      payouts: [
        OwnerPayout(
          id: 'p-1',
          orgId: 'org-123',
          amount: 2000,
          commissionAmount: 200,
          status: PayoutStatus.requested,
          provider: 'razorpay',
          requestedAt: DateTime(2026, 9, 28, 12, 0),
        ),
        OwnerPayout(
          id: 'p-2',
          orgId: 'org-123',
          amount: 4000,
          commissionAmount: 400,
          status: PayoutStatus.paid,
          provider: 'razorpay',
          requestedAt: DateTime(2026, 9, 15, 10, 0),
          processedAt: DateTime(2026, 9, 16, 11, 0),
        ),
      ],
      bankAccount: OwnerBankAccount(
        id: 'bank-1',
        orgId: 'org-123',
        accountHolder: 'Rajesh Kumar',
        bankName: 'HDFC Bank',
        accountNumberMasked: '•••• •••• 4589',
        ifscCode: 'HDFC0001234',
        upiId: 'rajesh@okhdfcbank',
        isVerified: true,
        createdAt: DateTime(2026, 9, 1, 10, 0),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentOwnerProvider.overrideWith((ref) async => testOwner),
          ownerPayoutRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(home: OwnerPayoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Balance Card
    expect(find.text('Settlements & Payouts'), findsOneWidget);
    expect(find.text('Available for Payout'), findsOneWidget);
    expect(find.text('₹3000'), findsOneWidget);
    expect(find.text('Gross Bookings'), findsOneWidget);
    expect(find.text('₹10000'), findsOneWidget);
    expect(find.text('Commission (10%)'), findsOneWidget);
    expect(find.text('-₹1000'), findsOneWidget);
    expect(find.text('Settled to Bank'), findsOneWidget);
    expect(find.text('₹4000'), findsWidgets);

    // Verify Bank Account Section
    expect(find.text('Disbursement Bank Account'), findsOneWidget);
    expect(find.text('HDFC Bank (•••• •••• 4589)'), findsOneWidget);
    expect(find.text('Holder: Rajesh Kumar • IFSC: HDFC0001234'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);

    // Verify Payouts List
    expect(find.text('Payout History'), findsOneWidget);
    expect(find.text('REQUESTED'), findsOneWidget);
    expect(find.text('SETTLED / PAID'), findsOneWidget);

    // Tap 'Request Payout' and verify dialog opens
    await tester.tap(find.text('Request Payout'));
    await tester.pumpAndSettle();

    expect(find.text('Disbursement will be transferred to HDFC Bank (•••• •••• 4589).'), findsOneWidget);
    expect(find.text('Submit Request'), findsOneWidget);

    // Submit Payout Request
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();

    // Verify dialog dismissed and status is requested (never fake instant success)
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Requested'), findsWidgets);
  });
}
