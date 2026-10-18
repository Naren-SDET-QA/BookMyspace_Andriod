import 'package:bookmyspace/features/marketplace/domain/marketplace_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search normalizes input and sends bounded server filters', () {
    final query = MarketplaceQuery(
      text: '  music  ',
      city: ' Hyderabad ',
      category: MarketplaceCategory.events,
      maxPrice: 1500,
      from: DateTime.utc(2026, 11, 1),
      sort: MarketplaceSort.priceLow,
    );
    expect(query.toParams(), containsPair('p_query', 'music'));
    expect(query.toParams(), containsPair('p_city', 'Hyderabad'));
    expect(query.toParams(), containsPair('p_category', 'events'));
    expect(query.toParams(), containsPair('p_max_price', 1500));
    expect(query.toParams(), containsPair('p_sort', 'price_low'));
    expect(query.toParams(), containsPair('p_limit', 24));
    expect(query.nextPage().offset, 24);
  });

  test('rejects invalid filters before sending a request', () {
    for (final action in <void Function()>[
      () => MarketplaceQuery(pageSize: 0),
      () => MarketplaceQuery(pageSize: 49),
      () => MarketplaceQuery(offset: -1),
      () => MarketplaceQuery(maxPrice: -1),
      () => MarketplaceQuery(maxPrice: double.nan),
      () => MarketplaceQuery(minPrice: 100, maxPrice: 50),
      () => MarketplaceQuery(from: DateTime(2030), until: DateTime(2029)),
    ]) {
      expect(action, throwsArgumentError);
    }
  });

  test('same filters have value equality for provider caching', () {
    expect(MarketplaceQuery(text: ' music '), MarketplaceQuery(text: 'music'));
    expect(
      MarketplaceQuery(city: 'Hyderabad'),
      isNot(MarketplaceQuery(city: 'Chennai')),
    );
    expect(MarketplaceQuery().nextPage(), isNot(MarketplaceQuery()));
  });

  test('catalog links use typed entity identity and never backend URLs', () {
    final item = MarketplaceItem.fromJson({
      'id': '00000000-0000-4000-8000-000000000001',
      'entity_type': 'event',
      'category': 'events',
      'title': 'Music night',
      'city': 'Hyderabad',
      'price': 499,
      'currency': 'INR',
      'starts_at': '2030-01-01T18:00:00Z',
      'image_url': 'javascript:alert(1)',
      'route': 'https://untrusted.example',
    });
    expect(item.location, '/events/00000000-0000-4000-8000-000000000001');
    expect(item.imageUrl, isEmpty);
    expect(item.price, 499);
    expect(item.startsAt, DateTime.utc(2030, 1, 1, 18));
  });

  test(
    'unknown or corrupt catalog records are rejected, never booked as venues',
    () {
      expect(
        () => MarketplaceItem.fromJson({'entity_type': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => MarketplaceItem.fromJson({
          'id': '../admin',
          'entity_type': 'venue',
          'title': 'Bad',
        }),
        throwsFormatException,
      );
    },
  );
}
