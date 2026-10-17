import 'dart:convert';

import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/marketplace/domain/marketplace_catalog.dart';
import 'package:bookmyspace/features/marketplace/infrastructure/supabase_marketplace_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'RPC carries bounded filters/platform and decodes typed results',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://catalog.example.invalid',
        'test-publishable-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'id': '00000000-0000-4000-8000-000000000001',
                'entity_type': 'course',
                'category': 'courses',
                'title': 'Music',
                'price': 900,
                'currency': 'INR',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseMarketplaceRepository(client, platform: 'ios');
      final result = await repository.search(
        MarketplaceQuery(city: 'Hyderabad', text: 'Music'),
      );
      expect(requests.single.url.path, '/rest/v1/rpc/marketplace_search');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_city'], 'Hyderabad');
      expect(body['p_limit'], 24);
      expect(body['p_platform'], 'ios');
      expect(
        result.single.location,
        '/courses/00000000-0000-4000-8000-000000000001',
      );
    },
  );

  test(
    'database failure surfaces as typed error without sample fallback',
    () async {
      final client = SupabaseClient(
        'https://catalog.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'catalog unavailable', 'code': '42501'}),
            403,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseMarketplaceRepository(client).search(MarketplaceQuery()),
        throwsA(isA<AppException>()),
      );
    },
  );
}
