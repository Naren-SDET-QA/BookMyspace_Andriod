import 'package:bookmyspace/features/offers/domain/coupon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coupon maps public coupon columns and formats value', () {
    final percent = Coupon.fromJson({
      'id': 'c1',
      'code': 'HALL10',
      'discount_type': 'percentage',
      'discount_value': 10,
      'description': 'Weekday halls',
    });
    expect(percent.code, 'HALL10');
    expect(percent.valueLabel, '10% off');

    final fixed = Coupon.fromJson({
      'id': 'c2',
      'code': 'FLAT500',
      'discount_type': 'fixed',
      'discount_value': 500,
    });
    expect(fixed.valueLabel, '₹500 off');

    final legacyDescription = Coupon.fromJson({
      'id': 'c3',
      'code': 'FESTIVE500',
      'discount_type': 'fixed',
      'discount_value': 500,
      'description': 'Flat â‚¹500 off on bookings above â‚¹10,000',
    });
    expect(
      legacyDescription.description,
      'Flat ₹500 off on bookings above ₹10,000',
    );
  });
}
