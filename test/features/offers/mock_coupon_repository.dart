import 'package:bookmyspace/features/offers/domain/coupon.dart';

class MockCouponRepository implements CouponRepository {
  MockCouponRepository({this.coupons = const []});

  final List<Coupon> coupons;

  @override
  Future<List<Coupon>> activeCoupons({int limit = 10}) async {
    return coupons.take(limit).toList();
  }
}
