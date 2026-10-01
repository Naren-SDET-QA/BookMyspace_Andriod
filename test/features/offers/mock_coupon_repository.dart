import 'package:bookmyspace/features/offers/domain/coupon.dart';

class MockCouponRepository implements CouponRepository {
  MockCouponRepository({
    this.coupons = const [],
    this.redeemed = const [],
  });

  final List<Coupon> coupons;
  final List<RedeemedCoupon> redeemed;

  @override
  Future<List<Coupon>> activeCoupons({int limit = 10}) async {
    return coupons.take(limit).toList();
  }

  @override
  Future<List<RedeemedCoupon>> customerRedeemedCoupons() async {
    return redeemed;
  }
}

