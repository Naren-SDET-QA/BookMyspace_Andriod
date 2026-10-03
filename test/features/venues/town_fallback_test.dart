import 'package:bookmyspace/features/venues/infrastructure/town_fallback_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('district fallback describes the wider area', () {
    const f = TownFallback(
      townName: 'Ongole',
      scopeName: 'Prakasam',
      scopeLevel: 'district_county',
      venues: [],
    );
    expect(f.inTown, isFalse);
    expect(f.scopeLabel, 'district');
  });

  test('town match is reported as in town', () {
    const f = TownFallback(
      townName: 'Bapatla',
      scopeName: 'Bapatla',
      scopeLevel: 'city_town',
      venues: [],
    );
    expect(f.inTown, isTrue);
    expect(f.scopeLabel, isEmpty);
  });

  test('state fallback label', () {
    const f = TownFallback(
      townName: 'Ongole',
      scopeName: 'Andhra Pradesh',
      scopeLevel: 'state_province',
      venues: [],
    );
    expect(f.scopeLabel, 'state');
  });
}
