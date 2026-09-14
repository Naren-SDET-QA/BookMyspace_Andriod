import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookmyspace/features/cms/presentation/screens/owner_facility_builder_screen.dart';
import 'package:bookmyspace/features/venue_sections/presentation/venue_section_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'owner_facility_controller_test.dart' as fixtures;

void main() {
  for (final width in [375.0, 1200.0]) {
    testWidgets('wizard creates a facility and validates at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = fixtures.FakeSections();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            venueSectionRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
              home: OwnerFacilityBuilderScreen(
                  venueId: 'venue', venueName: 'My venue'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add facility type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a title.'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'), 'Workshop');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Workshop'), findsOneWidget);
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(repo.row?.config['facility_types'], isNotEmpty);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      for (final name in ['Seating', 'Amenities']) {
        await tester.tap(find.text('Add section'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Name'), name);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Move Amenities up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add subsection'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'), 'Parking');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Parking'), findsNothing);
      repo.fail = true;
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your edits are still here'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      final saved = (repo.row!.config['facility_types'] as List).single as Map;
      final sections = saved['sections'] as List;
      expect((sections.first as Map)['title']['base'], 'Amenities');
      expect(((sections.first as Map)['subsections'] as List).single['enabled'],
          false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('delete removes a section, a subsection and a facility type',
      (tester) async {
    final repo = fixtures.FakeSections();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          venueSectionRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
            home: OwnerFacilityBuilderScreen(
                venueId: 'venue', venueName: 'My venue'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add facility type'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Clinic');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    for (final name in ['Rooms', 'Parking']) {
      await tester.tap(find.text('Add section'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    // Deleting asks first, and only removes from the working copy.
    await tester.tap(find.byTooltip('Delete Parking'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete "Parking"'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Parking'), findsNothing);
    expect(find.text('Rooms'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add subsection'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Wi-Fi');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Wi-Fi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Wi-Fi'), findsNothing);

    // The saved draft carries the surviving section and no subsection.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    final saved = (repo.row!.config['facility_types'] as List).single as Map;
    final sections = saved['sections'] as List;
    expect(sections, hasLength(1));
    expect((sections.single as Map)['title']['base'], 'Rooms');
    expect((sections.single as Map)['subsections'], isEmpty);

    // Deleting the last facility type clears the list.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Clinic'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Clinic'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
