/// Directory records readable by administrators under deployed RLS.
class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.roles = const [],
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final List<String> roles;
  final DateTime? createdAt;

  String get displayName =>
      fullName.trim().isNotEmpty ? fullName.trim() : (email.isNotEmpty ? email : id);
}

class AdminOwnerRecord {
  const AdminOwnerRecord({
    required this.id,
    required this.name,
    required this.ownerUserId,
    this.orgType = '',
    this.city = '',
    this.identityVerification = '',
    this.businessVerification = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final String orgType;
  final String city;
  final String identityVerification;
  final String businessVerification;
  final bool isActive;
}

class AdminVenueRecord {
  const AdminVenueRecord({
    required this.id,
    required this.name,
    this.city = '',
    this.isActive = true,
    this.avgRating = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final String city;
  final bool isActive;
  final double avgRating;
  final int ratingCount;
}
