import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/coupon.dart';

class SupabaseCouponRepository implements CouponRepository {
  SupabaseCouponRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Coupon>> activeCoupons({int limit = 10}) async {
    try {
      final rows = await _client
          .from('coupons')
          .select(
            'id, code, description, discount_type, discount_value, max_discount_amount, min_booking_amount, ends_at, is_active',
          )
          .eq('is_active', true)
          .order('ends_at', ascending: true)
          .limit(limit);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Coupon.fromJson)
          .where((coupon) =>
              coupon.code.isNotEmpty &&
              coupon.discountValue > 0 &&
              (coupon.endsAt == null || coupon.endsAt!.isAfter(DateTime.now())))
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<RedeemedCoupon>> customerRedeemedCoupons() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      // 1. Try authoritative RPC if available
      try {
        final rpcData = await _client.rpc<List<dynamic>>(
          'get_customer_coupon_history',
        );
        return rpcData
            .whereType<Map<String, dynamic>>()
            .map(RedeemedCoupon.fromJson)
            .toList();
      } catch (_) {
        // 2. Direct fallback: query bookings where user_id = user.id and discount_amount > 0
        final rows = await _client
            .from('bookings')
            .select('''
              id,
              discount_amount,
              total_amount,
              status,
              created_at,
              venues (id, name, city),
              booking_coupons (
                discount_amount,
                coupons (code, description)
              )
            ''')
            .eq('user_id', user.id)
            .gt('discount_amount', 0)
            .order('created_at', ascending: false);

        return rows.whereType<Map<String, dynamic>>().map((row) {
          String code = 'PROMO';
          String desc = 'Promotional discount';
          final bcList = row['booking_coupons'];
          if (bcList is List && bcList.isNotEmpty) {
            final firstBc = bcList.first as Map<String, dynamic>;
            final c = firstBc['coupons'];
            if (c is Map<String, dynamic>) {
              code = c['code'] as String? ?? code;
              desc = c['description'] as String? ?? desc;
            }
          }
          final venueMap = row['venues'] as Map<String, dynamic>?;
          final venueName =
              venueMap?['name'] as String? ?? 'BookMySpace Venue';

          return RedeemedCoupon(
            bookingId: row['id'] as String? ?? '',
            couponCode: code,
            couponDescription: desc,
            discountAmount:
                (row['discount_amount'] as num?)?.toDouble() ?? 0.0,
            totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0.0,
            venueName: venueName,
            bookingStatus: row['status'] as String? ?? 'confirmed',
            redeemedAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ??
                    DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}

