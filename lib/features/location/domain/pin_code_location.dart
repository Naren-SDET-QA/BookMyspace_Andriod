class PinCodeOffice {
  const PinCodeOffice({
    required this.name,
    required this.pincode,
    this.branchType = '',
    this.deliveryStatus = '',
    this.circle = '',
    this.district = '',
    this.division = '',
    this.region = '',
    this.block = '',
    this.state = '',
    this.country = 'India',
  });

  final String name;
  final String pincode;
  final String branchType;
  final String deliveryStatus;
  final String circle;
  final String district;
  final String division;
  final String region;
  final String block;
  final String state;
  final String country;

  String get city => name.trim();

  String get mandal => block.trim();

  List<(String, String)> get hierarchy {
    final items = <(String, String)>[
      if (state.trim().isNotEmpty) ('State', state.trim()),
      if (district.trim().isNotEmpty) ('District', district.trim()),
      if (block.trim().isNotEmpty) ('Mandal / Taluk', block.trim()),
      if (name.trim().isNotEmpty) ('City / Area', name.trim()),
      if (pincode.trim().isNotEmpty) ('PIN', pincode.trim()),
    ];
    return items;
  }

  String get displayLabel {
    final parts = <String>[
      if (name.trim().isNotEmpty) name.trim(),
      if (district.trim().isNotEmpty && district.trim() != name.trim())
        district.trim(),
      if (state.trim().isNotEmpty) state.trim(),
      if (pincode.trim().isNotEmpty) pincode.trim(),
    ];
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PinCodeOffice &&
            name == other.name &&
            pincode == other.pincode &&
            district == other.district &&
            block == other.block;
  }

  @override
  int get hashCode => Object.hash(name, pincode, district, block);

  factory PinCodeOffice.fromJson(Map<String, dynamic> json) {
    return PinCodeOffice(
      name: json['name'] as String? ?? json['Name'] as String? ?? '',
      pincode: json['pincode'] as String? ?? json['Pincode'] as String? ?? '',
      branchType:
          json['branchType'] as String? ?? json['BranchType'] as String? ?? '',
      deliveryStatus: json['deliveryStatus'] as String? ??
          json['DeliveryStatus'] as String? ??
          '',
      circle: json['circle'] as String? ?? json['Circle'] as String? ?? '',
      district:
          json['district'] as String? ?? json['District'] as String? ?? '',
      division:
          json['division'] as String? ?? json['Division'] as String? ?? '',
      region: json['region'] as String? ?? json['Region'] as String? ?? '',
      block: json['block'] as String? ?? json['Block'] as String? ?? '',
      state: json['state'] as String? ?? json['State'] as String? ?? '',
      country:
          json['country'] as String? ?? json['Country'] as String? ?? 'India',
    );
  }
}

enum PinLookupStatus { idle, loading, success, empty, invalid, error }

class PinLookupResult {
  const PinLookupResult({
    required this.status,
    this.pincode = '',
    this.offices = const [],
    this.message,
  });

  final PinLookupStatus status;
  final String pincode;
  final List<PinCodeOffice> offices;
  final String? message;

  bool get isSuccess => status == PinLookupStatus.success && offices.isNotEmpty;
}

abstract interface class PinCodeRepository {
  Future<PinLookupResult> lookup(String pincode);
}

final indianPinPattern = RegExp(r'^[1-9][0-9]{5}$');

String? validateIndianPin(String raw) {
  final pin = raw.trim();
  if (pin.isEmpty) return 'Enter a 6-digit Indian PIN code.';
  if (!indianPinPattern.hasMatch(pin)) {
    return 'Enter a valid 6-digit Indian PIN code.';
  }
  return null;
}
