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
              (coupon.endsAt == null ||
                  coupon.endsAt!.isAfter(DateTime.now())))
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
