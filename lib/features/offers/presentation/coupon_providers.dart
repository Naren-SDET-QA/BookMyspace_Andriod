import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/coupon.dart';
import '../infrastructure/supabase_coupon_repository.dart';

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return SupabaseCouponRepository(ref.watch(supabaseProvider));
});

final activeCouponsProvider = FutureProvider<List<Coupon>>((ref) {
  return ref.watch(couponRepositoryProvider).activeCoupons();
});
