/// Public coupon row from `public.coupons`.
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.description = '',
    this.maxDiscountAmount,
    this.minBookingAmount,
    this.endsAt,
  });

  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final String description;
  final double? maxDiscountAmount;
  final double? minBookingAmount;
  final DateTime? endsAt;

  bool get isPercentage => discountType == 'percentage';

  String get valueLabel {
    if (isPercentage) {
      final amount = discountValue == discountValue.roundToDouble()
          ? discountValue.round().toString()
          : discountValue.toString();
      return '$amount% off';
    }
    final amount = discountValue == discountValue.roundToDouble()
        ? discountValue.round().toString()
        : discountValue.toStringAsFixed(0);
    return '₹$amount off';
  }

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        discountType: json['discount_type'] as String? ?? 'fixed',
        discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
        minBookingAmount: (json['min_booking_amount'] as num?)?.toDouble(),
        endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      );
}

abstract interface class CouponRepository {
  Future<List<Coupon>> activeCoupons({int limit = 10});
}
