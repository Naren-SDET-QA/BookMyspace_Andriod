import 'package:flutter/material.dart';

/// Status of an owner payout/settlement.
enum PayoutStatus {
  requested,
  approved,
  processing,
  paid,
  failed;

  static PayoutStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'approved':
        return PayoutStatus.approved;
      case 'processing':
        return PayoutStatus.processing;
      case 'paid':
        return PayoutStatus.paid;
      case 'failed':
        return PayoutStatus.failed;
      case 'requested':
      default:
        return PayoutStatus.requested;
    }
  }

  String get label {
    switch (this) {
      case PayoutStatus.requested:
        return 'Requested';
      case PayoutStatus.approved:
        return 'Approved';
      case PayoutStatus.processing:
        return 'Processing';
      case PayoutStatus.paid:
        return 'Settled / Paid';
      case PayoutStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case PayoutStatus.requested:
        return Colors.orange;
      case PayoutStatus.approved:
        return Colors.indigo;
      case PayoutStatus.processing:
        return Colors.blue;
      case PayoutStatus.paid:
        return const Color(0xFF2E7D32);
      case PayoutStatus.failed:
        return Colors.red;
    }
  }
}

/// A settlement / payout record from `public.payouts`.
class OwnerPayout {
  const OwnerPayout({
    required this.id,
    required this.orgId,
    required this.amount,
    required this.commissionAmount,
    required this.status,
    required this.provider,
    this.providerPayoutId,
    required this.requestedAt,
    this.processedAt,
  });

  final String id;
  final String orgId;
  final double amount;
  final double commissionAmount;
  final PayoutStatus status;
  final String provider;
  final String? providerPayoutId;
  final DateTime requestedAt;
  final DateTime? processedAt;

  double get netAmount => amount - commissionAmount;

  factory OwnerPayout.fromJson(Map<String, dynamic> json) => OwnerPayout(
        id: json['id'] as String? ?? '',
        orgId: json['org_id'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        commissionAmount:
            (json['commission_amount'] as num?)?.toDouble() ?? 0.0,
        status: PayoutStatus.fromString(json['status'] as String?),
        provider: json['provider'] as String? ?? 'razorpay',
        providerPayoutId: json['provider_payout_id'] as String?,
        requestedAt: DateTime.tryParse(json['requested_at'] as String? ?? '') ??
            DateTime.now(),
        processedAt:
            DateTime.tryParse(json['processed_at'] as String? ?? ''),
      );
}

/// Bank account record from `public.owner_bank_accounts`.
class OwnerBankAccount {
  const OwnerBankAccount({
    required this.id,
    required this.orgId,
    required this.accountHolder,
    required this.bankName,
    required this.accountNumberMasked,
    required this.ifscCode,
    this.upiId,
    required this.isVerified,
    required this.createdAt,
  });

  final String id;
  final String orgId;
  final String accountHolder;
  final String bankName;
  final String accountNumberMasked;
  final String ifscCode;
  final String? upiId;
  final bool isVerified;
  final DateTime createdAt;

  factory OwnerBankAccount.fromJson(Map<String, dynamic> json) {
    final rawNumber = json['account_number_encrypted'] as String? ??
        json['account_number'] as String? ??
        '';
    final masked = rawNumber.length > 4
        ? '•••• •••• ${rawNumber.substring(rawNumber.length - 4)}'
        : '••••';
    return OwnerBankAccount(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      accountHolder: json['account_holder'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      accountNumberMasked: masked,
      ifscCode: json['ifsc_code'] as String? ?? '',
      upiId: json['upi_id'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Summary of an owner's financial settlement state.
class OwnerPayoutSummary {
  const OwnerPayoutSummary({
    required this.totalGrossRevenue,
    required this.totalCommission,
    required this.totalPaidOut,
    required this.totalPendingPayout,
    required this.availableBalance,
  });

  final double totalGrossRevenue;
  final double totalCommission;
  final double totalPaidOut;
  final double totalPendingPayout;
  final double availableBalance;

  double get netEarned => totalGrossRevenue - totalCommission;
}

abstract interface class OwnerPayoutRepository {
  Future<String> getOwnerOrgId();
  Future<OwnerPayoutSummary> getPayoutSummary([String? orgId]);
  Future<List<OwnerPayout>> getPayouts([String? orgId]);
  Future<OwnerBankAccount?> getBankAccount([String? orgId]);
  Future<void> saveBankAccount({
    String? orgId,
    required String accountHolder,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
  });
  Future<OwnerPayout> requestPayout({
    String? orgId,
    required double amount,
  });
}

