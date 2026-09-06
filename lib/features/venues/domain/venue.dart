/// Sorting options for venue discovery.
enum VenueSortBy {
  relevance,
  priceAsc,
  priceDesc,
  rating,
  distance,
}

/// Category metadata for venues.
class VenueCategory {
  const VenueCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.icon,
  });

  final String id;
  final String slug;
  final String name;
  final String? icon;

  factory VenueCategory.fromJson(Map<String, dynamic> json) {
    return VenueCategory(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name': name,
    if (icon != null) 'icon': icon,
  };
}

/// Image model associated with a venue.
class VenueImage {
  const VenueImage({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.altText,
    this.isCover = false,
    this.sortOrder = 0,
  });

  final String id;
  final String url;
  final String? thumbnailUrl;
  final String? altText;
  final bool isCover;
  final int sortOrder;

  factory VenueImage.fromJson(Map<String, dynamic> json) {
    return VenueImage(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      altText: json['alt_text'] as String?,
      isCover: json['is_cover'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (altText != null) 'alt_text': altText,
    'is_cover': isCover,
    'sort_order': sortOrder,
  };
}

/// Facility/amenity available at a venue.
class VenueFacility {
  const VenueFacility({
    required this.facility,
    this.isAvailable = true,
  });

  final String facility;
  final bool isAvailable;

  factory VenueFacility.fromJson(Map<String, dynamic> json) {
    return VenueFacility(
      facility: json['facility'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'facility': facility,
    'is_available': isAvailable,
  };
}

/// Operating hours for a venue on a given day of the week.
class VenueOperatingHours {
  const VenueOperatingHours({
    required this.dayOfWeek,
    this.opensAt,
    this.closesAt,
    this.isClosed = false,
  });

  final int dayOfWeek;
  final String? opensAt;
  final String? closesAt;
  final bool isClosed;

  factory VenueOperatingHours.fromJson(Map<String, dynamic> json) {
    return VenueOperatingHours(
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'day_of_week': dayOfWeek,
    if (opensAt != null) 'opens_at': opensAt,
    if (closesAt != null) 'closes_at': closesAt,
    'is_closed': isClosed,
  };
}

/// Main Venue domain model.
class Venue {
  const Venue({
    required this.id,
    required this.name,
    this.slug = '',
    this.description = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    required this.latitude,
    required this.longitude,
    this.capacity = 0,
    this.pricingBaseAmount = 0.0,
    this.price = 0.0,
    this.taxRate = 18.0,
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.isVerified = false,
    this.isActive = true,
    this.category,
    this.images = const [],
    this.facilities = const [],
    this.operatingHours = const [],
    this.distanceKm,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final int capacity;
  final double pricingBaseAmount;
  final double price;
  final double taxRate;
  final double avgRating;
  final int ratingCount;
  final bool isVerified;
  final bool isActive;
  final VenueCategory? category;
  final List<VenueImage> images;
  final List<VenueFacility> facilities;
  final List<VenueOperatingHours> operatingHours;
  final double? distanceKm;

  String get addressLine1 => address.isNotEmpty ? address : city;
  String get addressLine2 => '$city, $state $pincode'.trim();

  /// Returns the cover image url or empty string.
  String get coverImageUrl {
    if (images.isEmpty) return '';
    try {
      final cover = images.firstWhere((i) => i.isCover);
      return cover.url;
    } catch (_) {
      return images.first.url;
    }
  }

  factory Venue.fromJson(Map<String, dynamic> json) {
    // Parse category
    VenueCategory? cat;
    if (json['venue_categories'] is Map<String, dynamic>) {
      cat = VenueCategory.fromJson(json['venue_categories'] as Map<String, dynamic>);
    } else if (json['category'] is Map<String, dynamic>) {
      cat = VenueCategory.fromJson(json['category'] as Map<String, dynamic>);
    }

    // Parse images
    final imagesList = <VenueImage>[];
    if (json['venue_images'] is List) {
      for (final item in json['venue_images'] as List) {
        if (item is Map<String, dynamic>) {
          imagesList.add(VenueImage.fromJson(item));
        }
      }
    } else if (json['images'] is List) {
      for (final item in json['images'] as List) {
        if (item is Map<String, dynamic>) {
          imagesList.add(VenueImage.fromJson(item));
        }
      }
    }

    // Parse facilities
    final facilitiesList = <VenueFacility>[];
    if (json['venue_facilities'] is List) {
      for (final item in json['venue_facilities'] as List) {
        if (item is Map<String, dynamic>) {
          facilitiesList.add(VenueFacility.fromJson(item));
        }
      }
    }

    // Parse operating hours
    final hoursList = <VenueOperatingHours>[];
    if (json['venue_operating_hours'] is List) {
      for (final item in json['venue_operating_hours'] as List) {
        if (item is Map<String, dynamic>) {
          hoursList.add(VenueOperatingHours.fromJson(item));
        }
      }
    }

    final pricingBase = (json['pricing_base_amount'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        0.0;

    // Build compound address if not explicitly present
    String addr = json['address'] as String? ?? '';
    if (addr.isEmpty) {
      final parts = [
        json['city'] as String?,
        json['state'] as String?,
        json['pincode'] as String?,
      ].where((s) => s != null && s.trim().isNotEmpty).map((s) => s!.trim());
      addr = parts.join(', ');
    }

    return Venue(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: addr,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      capacity: json['capacity'] as int? ?? 0,
      pricingBaseAmount: pricingBase,
      price: pricingBase,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 18.0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      category: cat,
      images: imagesList,
      facilities: facilitiesList,
      operatingHours: hoursList,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  Venue copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? address,
    String? city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    int? capacity,
    double? pricingBaseAmount,
    double? price,
    double? taxRate,
    double? avgRating,
    int? ratingCount,
    bool? isVerified,
    bool? isActive,
    VenueCategory? category,
    List<VenueImage>? images,
    List<VenueFacility>? facilities,
    List<VenueOperatingHours>? operatingHours,
    double? distanceKm,
  }) {
    return Venue(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacity: capacity ?? this.capacity,
      pricingBaseAmount: pricingBaseAmount ?? this.pricingBaseAmount,
      price: price ?? this.price,
      taxRate: taxRate ?? this.taxRate,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      category: category ?? this.category,
      images: images ?? this.images,
      facilities: facilities ?? this.facilities,
      operatingHours: operatingHours ?? this.operatingHours,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}

/// Search and filter query parameters for venues.
class VenueSearchQuery {
  const VenueSearchQuery({
    this.query = '',
    this.categorySlug,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.sortBy = VenueSortBy.relevance,
  });

  final String query;
  final String? categorySlug;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final VenueSortBy sortBy;

  bool get hasFilters =>
      query.isNotEmpty ||
      categorySlug != null ||
      city != null ||
      minPrice != null ||
      maxPrice != null ||
      sortBy != VenueSortBy.relevance;

  VenueSearchQuery copyWith({
    String? query,
    String? Function()? categorySlug,
    String? Function()? city,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    VenueSortBy? sortBy,
  }) {
    return VenueSearchQuery(
      query: query ?? this.query,
      categorySlug: categorySlug != null ? categorySlug() : this.categorySlug,
      city: city != null ? city() : this.city,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}
