import 'package:bookmyspace/features/owner/presentation/widgets/listing_template_editor.dart';
import 'package:bookmyspace/features/venues/domain/listing_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ListingPreviewDevice device,
    {String? accent, String slug = 'hotel_stay'}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: ListingTemplatePreview(
          config: ListingTemplateConfig.defaultsFor(slug: slug).copyWith(
            accentColor: accent,
            clearAccent: accent == null,
          ),
          categoryName: 'Sunrise Hotels',
          device: device,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('preview renders config CTAs on every device frame',
      (tester) async {
    for (final device in ListingPreviewDevice.values) {
      await tester.pumpWidget(_app(device));
      await tester.pump();

      expect(find.text('Sunrise Hotels'), findsOneWidget);
      expect(find.text('Book Stay'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      // Config-driven field labels appear as chips.
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Guests'), findsOneWidget);
      expect(find.byType(ListingTemplatePreview), findsOneWidget);
    }
  });

  testWidgets('preview hides call/chat buttons when config disables them',
      (tester) async {
    final config = ListingTemplateConfig.defaultsFor(slug: 'temple')
        .copyWith(showCall: false, showChat: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListingTemplatePreview(
            config: config,
            categoryName: 'Temple',
            device: ListingPreviewDevice.mobile,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Call'), findsNothing);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('Book Darshan'), findsOneWidget);
  });

  testWidgets('invalid accent color falls back to theme violet safely',
      (tester) async {
    await tester.pumpWidget(_app(
      ListingPreviewDevice.tablet,
      accent: 'not-a-color',
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
