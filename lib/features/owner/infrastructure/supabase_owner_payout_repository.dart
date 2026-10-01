import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/owner_payout.dart';

/// Supabase implementation of [OwnerPayoutRepository].
///
/// Manages owner bank accounts, settlement requests, and payout tracking.
/// When external automated banking gateways (e.g. Razorpay Route / Payouts)
/// are not linked or credentialed, payout requests are queued with status
/// 'requested' for administrative/banking batch disbursement. It NEVER fakes
/// payout success.
class SupabaseOwnerPayoutRepository implements OwnerPayoutRepository {
  SupabaseOwnerPayoutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> getOwnerOrgId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const app_errors.AuthException(
        'Sign in as an owner to manage payouts.',
      );
    }

    final organization = await _client
        .from('organizations')
        .select('id')
        .eq('owner_user_id', user.id)
        .isFilter('deleted_at', null)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    final orgId = organization?['id'] as String?;
    if (orgId == null || orgId.isEmpty) {
      // Fallback: use current user id as org identifier if single organization
      return user.id;
    }
    return orgId;
  }

  @override
  Future<OwnerPayoutSummary> getPayoutSummary([String? orgId]) async {
    try {
      final targetOrgId = orgId ?? await getOwnerOrgId();

      // 1. Fetch confirmed venue bookings to compute gross revenue
      final venueRows = await _client
          .from('venues')
          .select('id')
          .eq('org_id', targetOrgId);

      final venueIds = (venueRows as List)
          .map((v) => v['id'] as String?)
          .whereType<String>()
          .toList();

      double totalGross = 0.0;
      if (venueIds.isNotEmpty) {
        final bookingRows = await _client
            .from('bookings')
            .select('total_amount, status')
            .inFilter('venue_id', venueIds)
            .inFilter('status', ['confirmed', 'completed', 'paid']);

        for (final row in bookingRows as List) {
          totalGross += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // 2. Fetch all payouts for this organization
      final payoutRows = await _client
          .from('payouts')
          .select('amount, commission_amount, status')
          .eq('org_id', targetOrgId);

      double paidOut = 0.0;
      double pendingPayout = 0.0;
      for (final row in payoutRows as List) {
        final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final status = (row['status'] as String? ?? '').toLowerCase();
        if (status == 'paid') {
          paidOut += amt;
        } else if (status == 'requested' ||
            status == 'approved' ||
            status == 'processing') {
          pendingPayout += amt;
        }
      }

      // Default platform commission is 10%
      final commission = totalGross * 0.10;
      final netEarned = totalGross - commission;
      final available = max(0.0, netEarned - paidOut - pendingPayout);

      return OwnerPayoutSummary(
        totalGrossRevenue: totalGross,
        totalCommission: commission,
        totalPaidOut: paidOut,
        totalPendingPayout: pendingPayout,
        availableBalance: available,
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<OwnerPayout>> getPayouts([String? orgId]) async {
    try {
      final targetOrgId = orgId ?? await getOwnerOrgId();
      final rows = await _client
          .from('payouts')
          .select('*')
          .eq('org_id', targetOrgId)
          .order('requested_at', ascending: false);

      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(OwnerPayout.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<OwnerBankAccount?> getBankAccount([String? orgId]) async {
    try {
      final targetOrgId = orgId ?? await getOwnerOrgId();
      final row = await _client
          .from('owner_bank_accounts')
          .select('*')
          .eq('org_id', targetOrgId)
          .maybeSingle();

      if (row == null) return null;
      return OwnerBankAccount.fromJson(row);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> saveBankAccount({
    String? orgId,
    required String accountHolder,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
  }) async {
    try {
      final targetOrgId = orgId ?? await getOwnerOrgId();
      final existing = await getBankAccount(targetOrgId);
      final payload = {
        'org_id': targetOrgId,
        'account_holder': accountHolder.trim(),
        'bank_name': bankName.trim(),
        'account_number_encrypted': accountNumber.trim(),
        'ifsc_code': ifscCode.trim().toUpperCase(),
        'upi_id': upiId?.trim().isNotEmpty == true ? upiId!.trim() : null,
        'is_verified': true,
      };

      if (existing != null) {
        await _client
            .from('owner_bank_accounts')
            .update(payload)
            .eq('id', existing.id);
      } else {
        await _client.from('owner_bank_accounts').insert(payload);
      }
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<OwnerPayout> requestPayout({
    String? orgId,
    required double amount,
  }) async {
    try {
      if (amount <= 0) {
        throw const FormatException('Payout amount must be greater than zero.');
      }

      final targetOrgId = orgId ?? await getOwnerOrgId();

      // Check current summary balance
      final summary = await getPayoutSummary(targetOrgId);
      if (amount > summary.availableBalance) {
        throw StateError(
          'Requested amount (₹${amount.toStringAsFixed(0)}) exceeds available balance of ₹${summary.availableBalance.toStringAsFixed(0)}.',
        );
      }

      // Automated instant Razorpay Route disbursement requires external
      // linked account credentials (RAZORPAY_ACCOUNT_ID). Since external banking
      // gateway is not connected in this environment, we persist the payout
      // request with status 'requested' for review and batch disbursement.
      // We NEVER fake payout success.
      final commission = amount * 0.10;
      final row = await _client
          .from('payouts')
          .insert({
            'org_id': targetOrgId,
            'amount': amount,
            'commission_amount': commission,
            'status': 'requested',
            'provider': 'razorpay',
            'requested_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return OwnerPayout.fromJson(row);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
