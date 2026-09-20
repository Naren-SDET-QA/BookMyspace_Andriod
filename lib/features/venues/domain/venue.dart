import 'listing_template.dart';

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
    this.isActive = true,
    this.parentSection = 'general',
    this.description = '',
    this.imageUrl = '',
    this.imagePath = '',
    this.displayOrder = 0,
    this.supportedLanguages = const ['en'],
    this.nameTranslations = const {},
    this.descriptionTranslations = const {},
    this.listingConfig,
  });

  final String id;
  final String slug;
  final String name;
  final String? icon;
  final bool isActive;
  final String? parentSection;
  final String description;
  final String imageUrl;
  final String imagePath;
  final int displayOrder;
  final List<String> supportedLanguages;
  final Map<String, String> nameTranslations;
  final Map<String, String> descriptionTranslations;
  final ListingTemplateConfig? listingConfig;

  /// Resolved template: admin overlay on top of slug defaults.
  ListingTemplateConfig get listingTemplate => ListingTemplateConfig.resolve(
        slug: slug,
        parentSection: parentSection,
        stored: listingConfig,
      );

  factory VenueCategory.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};
    return VenueCategory(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      isActive: json['is_active'] as bool? ??
          metadata['active'] as bool? ??
          metadata['is_active'] as bool? ??
          true,
      parentSection: json['parent_section'] as String? ??
          metadata['parent_section'] as String? ??
          metadata['section'] as String? ??
          'general',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ??
          (metadata['section_sort_order'] as num?)?.toInt() ??
          0,
      supportedLanguages:
          _stringList(json['supported_languages'], fallback: const ['en']),
      nameTranslations: _stringMap(
        json['name_i18n'] ?? metadata['localized_names'],
      ),
      descriptionTranslations: _stringMap(json['description_i18n']),
      listingConfig: ListingTemplateConfig.tryParse(
        json['listing_config'] ?? metadata['listing'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        if (icon != null) 'icon': icon,
        'is_active': isActive,
        if (parentSection != null) 'parent_section': parentSection,
        'description': description,
        'image_url': imageUrl.isEmpty ? null : imageUrl,
        'image_path': imagePath.isEmpty ? null : imagePath,
        'display_order': displayOrder,
        'supported_languages': supportedLanguages,
        'name_i18n': nameTranslations,
        'description_i18n': descriptionTranslations,
        'metadata': {
          'active': isActive,
          if (parentSection != null) 'parent_section': parentSection,
          if (listingConfig != null) 'listing': listingConfig!.toJson(),
        },
      };

  VenueCategory copyWith({
    String? id,
    String? slug,
    String? name,
    String? icon,
    bool? isActive,
    String? parentSection,
    String? description,
    String? imageUrl,
    String? imagePath,
    bool clearImage = false,
    bool clearImagePath = false,
    int? displayOrder,
    List<String>? supportedLanguages,
    Map<String, String>? nameTranslations,
    Map<String, String>? descriptionTranslations,
    ListingTemplateConfig? listingConfig,
  }) {
    return VenueCategory(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      parentSection: parentSection ?? this.parentSection,
      description: description ?? this.description,
      imageUrl: clearImage ? '' : imageUrl ?? this.imageUrl,
      imagePath: clearImagePath ? '' : imagePath ?? this.imagePath,
      displayOrder: displayOrder ?? this.displayOrder,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      nameTranslations: nameTranslations ?? this.nameTranslations,
      descriptionTranslations:
          descriptionTranslations ?? this.descriptionTranslations,
      listingConfig: listingConfig ?? this.listingConfig,
    );
  }
}

/// A second-level catalogue item managed beneath a [VenueCategory].
class VenueSubsection {
  const VenueSubsection({
    required this.id,
    required this.categoryId,
    required this.slug,
    required this.name,
    this.icon,
    this.description = '',
    this.imageUrl = '',
    this.imagePath = '',
    this.isActive = true,
    this.displayOrder = 0,
    this.supportedLanguages = const ['en'],
    this.nameTranslations = const {},
    this.descriptionTranslations = const {},
  });

  final String id;
  final String categoryId;
  final String slug;
  final String name;
  final String? icon;
  final String description;
  final String imageUrl;
  final String imagePath;
  final bool isActive;
  final int displayOrder;
  final List<String> supportedLanguages;
  final Map<String, String> nameTranslations;
  final Map<String, String> descriptionTranslations;

  factory VenueSubsection.fromJson(Map<String, dynamic> json) {
    return VenueSubsection(
      id: json['id'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      supportedLanguages:
          _stringList(json['supported_languages'], fallback: const ['en']),
      nameTranslations: _stringMap(json['name_i18n']),
      descriptionTranslations: _stringMap(json['description_i18n']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'slug': slug,
        'name': name,
        if (icon != null) 'icon': icon,
        'description': description,
        'image_url': imageUrl.isEmpty ? null : imageUrl,
        'image_path': imagePath.isEmpty ? null : imagePath,
        'is_active': isActive,
        'display_order': displayOrder,
        'supported_languages': supportedLanguages,
        'name_i18n': nameTranslations,
        'description_i18n': descriptionTranslations,
      };

  VenueSubsection copyWith({
    String? categoryId,
    String? slug,
    String? name,
    String? icon,
    String? description,
    String? imageUrl,
    String? imagePath,
    bool clearImage = false,
    bool clearImagePath = false,
    bool? isActive,
    int? displayOrder,
    List<String>? supportedLanguages,
    Map<String, String>? nameTranslations,
    Map<String, String>? descriptionTranslations,
  }) {
    return VenueSubsection(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      imageUrl: clearImage ? '' : imageUrl ?? this.imageUrl,
      imagePath: clearImagePath ? '' : imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      nameTranslations: nameTranslations ?? this.nameTranslations,
      descriptionTranslations:
          descriptionTranslations ?? this.descriptionTranslations,
    );
  }
}

List<String> _stringList(Object? value, {required List<String> fallback}) {
  if (value is! List) return fallback;
  final values = value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  return values.isEmpty ? fallback : List.unmodifiable(values);
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return Map.unmodifiable(
    value.map((key, item) => MapEntry(key.toString(), item.toString())),
  );
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
    this.foodOptions = '',
    this.parkingCapacity = 0,
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.isVerified = false,
    this.isActive = true,
    this.category,
    this.images = const [],
    this.facilities = const [],
    this.operatingHours = const [],
    this.distanceKm,
    this.rules = '',
    this.cancellationPolicy,
    this.originalPrice,
    this.contactPhone = '',
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
  final String foodOptions;
  final int parkingCapacity;
  final double avgRating;
  final int ratingCount;
  final bool isVerified;
  final bool isActive;
  final VenueCategory? category;
  final List<VenueImage> images;
  final List<VenueFacility> facilities;
  final List<VenueOperatingHours> operatingHours;
  final double? distanceKm;
  final String rules;
  final Map<String, dynamic>? cancellationPolicy;
  final double? originalPrice;
  final String contactPhone;

  ListingTemplateConfig get listingTemplate => ListingTemplateConfig.resolve(
        slug: category?.slug,
        parentSection: category?.parentSection,
        stored: category?.listingConfig,
      );

  String get cancellationSummary {
    final policy = cancellationPolicy;
    if (policy == null || policy.isEmpty) return '';
    for (final key in const ['summary', 'text', 'description', 'policy']) {
      final value = policy[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  bool get hasDiscount =>
      originalPrice != null && originalPrice! > price && price > 0;

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
      cat = VenueCategory.fromJson(
          json['venue_categories'] as Map<String, dynamic>);
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
    String addr =
        json['address'] as String? ?? json['address_line1'] as String? ?? '';
    if (addr.isEmpty) {
      final parts = [
        json['city'] as String?,
        json['state'] as String?,
        (json['pincode'] ?? json['postal_code']) as String?,
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
      pincode: (json['pincode'] ?? json['postal_code']) as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      capacity: json['capacity'] as int? ?? 0,
      pricingBaseAmount: pricingBase,
      price: pricingBase,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 18.0,
      foodOptions: json['food_options'] as String? ?? '',
      parkingCapacity: (json['parking_capacity'] as num?)?.toInt() ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      category: cat,
      images: imagesList,
      facilities: facilitiesList,
      operatingHours: hoursList,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      rules: json['rules'] as String? ?? '',
      cancellationPolicy: json['cancellation_policy'] is Map
          ? Map<String, dynamic>.from(json['cancellation_policy'] as Map)
          : null,
      originalPrice: (json['original_price'] as num?)?.toDouble() ??
          (json['list_price'] as num?)?.toDouble(),
      contactPhone:
          json['contact_phone'] as String? ?? json['phone'] as String? ?? '',
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
    String? rules,
    Map<String, dynamic>? cancellationPolicy,
    double? originalPrice,
    String? contactPhone,
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
      rules: rules ?? this.rules,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      originalPrice: originalPrice ?? this.originalPrice,
      contactPhone: contactPhone ?? this.contactPhone,
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
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.pincode,
    this.facility,
    this.limit = 24,
    this.offset = 0,
  });

  final String query;
  final String? categorySlug;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final VenueSortBy sortBy;
  final double? latitude;
  final double? longitude;
  final int? radiusKm;
  final String? pincode;
  final String? facility;
  final int limit;
  final int offset;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasFilters =>
      query.isNotEmpty ||
      categorySlug != null ||
      city != null ||
      minPrice != null ||
      maxPrice != null ||
      sortBy != VenueSortBy.relevance ||
      hasCoordinates ||
      pincode != null ||
      facility != null;

  VenueSearchQuery copyWith({
    String? query,
    String? Function()? categorySlug,
    String? Function()? city,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    VenueSortBy? sortBy,
    double? Function()? latitude,
    double? Function()? longitude,
    int? Function()? radiusKm,
    String? Function()? pincode,
    String? Function()? facility,
    int? limit,
    int? offset,
  }) {
    return VenueSearchQuery(
      query: query ?? this.query,
      categorySlug: categorySlug != null ? categorySlug() : this.categorySlug,
      city: city != null ? city() : this.city,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      sortBy: sortBy ?? this.sortBy,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
      radiusKm: radiusKm != null ? radiusKm() : this.radiusKm,
      pincode: pincode != null ? pincode() : this.pincode,
      facility: facility != null ? facility() : this.facility,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VenueSearchQuery &&
            query == other.query &&
            categorySlug == other.categorySlug &&
            city == other.city &&
            minPrice == other.minPrice &&
            maxPrice == other.maxPrice &&
            sortBy == other.sortBy &&
            latitude == other.latitude &&
            longitude == other.longitude &&
            radiusKm == other.radiusKm &&
            pincode == other.pincode &&
            facility == other.facility &&
            limit == other.limit &&
            offset == other.offset;
  }

  @override
  int get hashCode => Object.hash(
        query,
        categorySlug,
        city,
        minPrice,
        maxPrice,
        sortBy,
        latitude,
        longitude,
        radiusKm,
        pincode,
        facility,
        limit,
        offset,
      );
}
