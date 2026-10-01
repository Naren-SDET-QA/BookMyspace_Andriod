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
        description: _normalizeDescription(json['description']),
        maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
        minBookingAmount: (json['min_booking_amount'] as num?)?.toDouble(),
        endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      );

  /// Repairs the one known legacy UTF-8/Windows-1252 mojibake sequence.
  ///
  /// This is intentionally narrow: it does not guess at arbitrary encoding
  /// errors or invent copy when the backend description is absent. The
  /// backend migration remains the source-of-truth repair for stored rows.
  static String _normalizeDescription(Object? raw) {
    final description = raw?.toString() ?? '';
    return description.replaceAll('\u00e2\u201a\u00b9', '\u20b9');
  }
}

abstract interface class CouponRepository {
  Future<List<Coupon>> activeCoupons({int limit = 10});
  Future<List<RedeemedCoupon>> customerRedeemedCoupons();
}

/// A coupon redeemed by a customer on a booking.
class RedeemedCoupon {
  const RedeemedCoupon({
    required this.bookingId,
    required this.couponCode,
    required this.couponDescription,
    required this.discountAmount,
    required this.totalAmount,
    required this.venueName,
    required this.bookingStatus,
    required this.redeemedAt,
  });

  final String bookingId;
  final String couponCode;
  final String couponDescription;
  final double discountAmount;
  final double totalAmount;
  final String venueName;
  final String bookingStatus;
  final DateTime redeemedAt;

  factory RedeemedCoupon.fromJson(Map<String, dynamic> json) => RedeemedCoupon(
        bookingId: json['booking_id'] as String? ?? json['id'] as String? ?? '',
        couponCode: json['coupon_code'] as String? ??
            json['code'] as String? ??
            'PROMO',
        couponDescription: json['coupon_description'] as String? ??
            json['description'] as String? ??
            '',
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
        venueName: json['venue_name'] as String? ??
            (json['venues'] is Map
                ? (json['venues'] as Map)['name'] as String? ?? ''
                : ''),
        bookingStatus: json['booking_status'] as String? ??
            json['status'] as String? ??
            'confirmed',
        redeemedAt: DateTime.tryParse(
              json['redeemed_at'] as String? ??
                  json['created_at'] as String? ??
                  '',
            ) ??
            DateTime.now(),
      );
}

