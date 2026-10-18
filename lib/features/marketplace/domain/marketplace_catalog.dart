enum MarketplaceCategory {
  all,
  events,
  venues,
  sports,
  restaurants,
  experiences,
  courses,
}

enum MarketplaceSort {
  relevance('relevance'),
  priceLow('price_low'),
  priceHigh('price_high'),
  rating('rating'),
  soonest('soonest');

  const MarketplaceSort(this.dbValue);
  final String dbValue;
}

/// Value object used as a Riverpod family key. Prices are discovery filters,
/// never checkout totals. The database controls ordering and pagination.
class MarketplaceQuery {
  MarketplaceQuery({
    String text = '',
    String? city,
    this.category = MarketplaceCategory.all,
    this.sort = MarketplaceSort.relevance,
    this.minPrice,
    this.maxPrice,
    this.from,
    this.until,
    this.pageSize = 24,
    this.offset = 0,
  }) : text = text.trim(),
       city = city?.trim() ?? '' {
    if (pageSize < 1 ||
        pageSize > 48 ||
        offset < 0 ||
        offset > 10000 ||
        text.length > 200 ||
        this.city.length > 100 ||
        (minPrice != null && (!minPrice!.isFinite || minPrice! < 0)) ||
        (maxPrice != null && (!maxPrice!.isFinite || maxPrice! < 0)) ||
        (minPrice != null && maxPrice != null && minPrice! > maxPrice!) ||
        (from != null && until != null && from!.isAfter(until!))) {
      throw ArgumentError('Invalid marketplace search filters');
    }
  }

  final String text, city;
  final MarketplaceCategory category;
  final MarketplaceSort sort;
  final double? minPrice, maxPrice;
  final DateTime? from, until;
  final int pageSize, offset;

  Map<String, dynamic> toParams() => {
    'p_query': text,
    'p_city': city,
    'p_category': category.name,
    'p_sort': sort.dbValue,
    'p_min_price': minPrice,
    'p_max_price': maxPrice,
    'p_from': from?.toUtc().toIso8601String(),
    'p_until': until?.toUtc().toIso8601String(),
    'p_limit': pageSize,
    'p_offset': offset,
  };

  MarketplaceQuery nextPage() => MarketplaceQuery(
    text: text,
    city: city,
    category: category,
    sort: sort,
    minPrice: minPrice,
    maxPrice: maxPrice,
    from: from,
    until: until,
    pageSize: pageSize,
    offset: offset + pageSize,
  );

  @override
  bool operator ==(Object other) =>
      other is MarketplaceQuery &&
      text == other.text &&
      city == other.city &&
      category == other.category &&
      sort == other.sort &&
      minPrice == other.minPrice &&
      maxPrice == other.maxPrice &&
      from == other.from &&
      until == other.until &&
      pageSize == other.pageSize &&
      offset == other.offset;

  @override
  int get hashCode => Object.hash(
    text,
    city,
    category,
    sort,
    minPrice,
    maxPrice,
    from,
    until,
    pageSize,
    offset,
  );
}

enum MarketplaceEntity { venue, event, course }

/// Read-only projection of an existing published entity; no shadow inventory.
class MarketplaceItem {
  const MarketplaceItem({
    required this.id,
    required this.entity,
    required this.category,
    required this.title,
    required this.city,
    required this.price,
    this.currency = 'INR',
    this.imageUrl = '',
    this.description = '',
    this.rating,
    this.startsAt,
  });

  final String id, title, city, currency, imageUrl, description;
  final MarketplaceEntity entity;
  final MarketplaceCategory category;
  final double price;
  final double? rating;
  final DateTime? startsAt;

  String get key => '${entity.name}:$id';
  String get location => switch (entity) {
    MarketplaceEntity.event => '/events/$id',
    MarketplaceEntity.course => '/courses/$id',
    MarketplaceEntity.venue => '/venues/$id',
  };

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    final entity = MarketplaceEntity.values
        .where((e) => e.name == json['entity_type'])
        .firstOrNull;
    final category = MarketplaceCategory.values
        .where((e) => e.name == json['category'])
        .firstOrNull;
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final price = (json['price'] as num?)?.toDouble();
    if (entity == null ||
        category == null ||
        category == MarketplaceCategory.all ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id) ||
        title.isEmpty ||
        price == null ||
        !price.isFinite ||
        price < 0) {
      throw const FormatException('Invalid marketplace catalog response');
    }
    final rawImage = json['image_url']?.toString() ?? '';
    final uri = Uri.tryParse(rawImage);
    return MarketplaceItem(
      id: id,
      entity: entity,
      category: category,
      title: title,
      city: json['city']?.toString() ?? '',
      price: price,
      currency: json['currency']?.toString() ?? 'INR',
      description: json['description']?.toString() ?? '',
      imageUrl: uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
          ? rawImage
          : '',
      rating: (json['rating'] as num?)?.toDouble(),
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? ''),
    );
  }
}

abstract interface class MarketplaceRepository {
  Future<List<MarketplaceItem>> search(MarketplaceQuery query);
}
