import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/offers/domain/coupon.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';
import 'package:bookmyspace/features/offers/presentation/screens/past_coupons_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCouponRepository implements CouponRepository {
  _FakeCouponRepository({
    this.active = const [],
    this.redeemed = const [],
  });

  final List<Coupon> active;
  final List<RedeemedCoupon> redeemed;

  @override
  Future<List<Coupon>> activeCoupons({int limit = 10}) async => active;

  @override
  Future<List<RedeemedCoupon>> customerRedeemedCoupons() async => redeemed;
}

void main() {
  const testUser = AuthUser(
    id: 'user-123',
    email: 'customer@bookmyspace.app',
    fullName: 'Test Customer',
  );

  testWidgets('PastCouponsScreen renders empty state when no coupons used',
      (tester) async {
    final repo = _FakeCouponRepository(
      active: [
        Coupon(
          id: 'c1',
          code: 'WELCOME10',
          discountType: 'percentage',
          discountValue: 10,
          description: '10% off on your first booking',
        ),
      ],
      redeemed: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(testUser),
          couponRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: PastCouponsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Past Coupons Used'), findsOneWidget);
    expect(find.text('No Coupons Used Yet'), findsOneWidget);
    expect(find.text('View Available Offers'), findsOneWidget);

    // Tap 'View Available Offers' and verify sheet opens with WELCOME10
    await tester.tap(find.text('View Available Offers'));
    await tester.pumpAndSettle();

    expect(find.text('Available Active Coupons'), findsOneWidget);
    expect(find.text('WELCOME10'), findsOneWidget);
    expect(find.text('10% off on your first booking'), findsOneWidget);
  });

  testWidgets('PastCouponsScreen displays savings summary and redeemed coupons',
      (tester) async {
    final repo = _FakeCouponRepository(
      active: const [],
      redeemed: [
        RedeemedCoupon(
          bookingId: 'b-001',
          couponCode: 'FESTIVE500',
          couponDescription: 'Festive Season ₹500 discount',
          discountAmount: 500,
          totalAmount: 2500,
          venueName: 'Gachibowli Badminton Arena',
          bookingStatus: 'confirmed',
          redeemedAt: DateTime(2026, 9, 20, 14, 30),
        ),
        RedeemedCoupon(
          bookingId: 'b-002',
          couponCode: 'SAVE100',
          couponDescription: 'Flat ₹100 off on weekend slots',
          discountAmount: 100,
          totalAmount: 900,
          venueName: 'Jubilee Turf Club',
          bookingStatus: 'completed',
          redeemedAt: DateTime(2026, 9, 25, 10, 0),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(testUser),
          couponRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: PastCouponsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify savings summary card (500 + 100 = 600)
    expect(find.text('Lifetime Coupon Savings'), findsOneWidget);
    expect(find.text('₹600'), findsOneWidget);
    expect(find.text('2 promo codes successfully redeemed'), findsOneWidget);

    // Verify redeemed items list
    expect(find.text('Redeemed Coupons (2)'), findsOneWidget);
    expect(find.text('FESTIVE500'), findsOneWidget);
    expect(find.text('-₹500 SAVED'), findsOneWidget);
    expect(find.text('Gachibowli Badminton Arena'), findsOneWidget);

    expect(find.text('SAVE100'), findsOneWidget);
    expect(find.text('-₹100 SAVED'), findsOneWidget);
    expect(find.text('Jubilee Turf Club'), findsOneWidget);
  });
}
