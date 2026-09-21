import 'package:bookmyspace/features/owner/presentation/screens/owner_categories_screen.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const category = VenueCategory(
    id: 'c1',
    slug: 'function-halls',
    name: 'Function Halls',
    icon: '🏛️',
    description: 'Spacious halls for weddings',
  );

  testWidgets('admin categories console renders on phone and desktop',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [Size(320, 720), Size(1280, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allVenueCategoriesProvider.overrideWith(
              (ref) => Stream.value(const [category]),
            ),
            allVenueSubsectionsCatalogProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            allVenueSubsectionsProvider.overrideWith(
              (ref, id) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(home: OwnerCategoriesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manage Categories'), findsOneWidget);
      expect(find.text('Add Category'), findsOneWidget);
      expect(find.text('Function Halls'), findsWidgets);
      expect(find.text('Live Preview (App View)'), findsOneWidget);
    }
  });
}
