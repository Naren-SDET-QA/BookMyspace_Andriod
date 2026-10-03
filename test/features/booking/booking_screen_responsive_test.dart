import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/booking_screen.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_booking_repository.dart';

/// Responsive presentation of the real BookingScreen with the built-in
/// Function Hall, Hotel and Sports templates (dev categories store no custom
/// listing config, so these are the forms users get). Data comes from the
/// repository double; no booking logic is exercised beyond rendering and
/// selecting a slot.

SlotAvailability _slot(int hour, {String reason = 'available'}) =>
    SlotAvailability(
      slotId: 's$hour',
      label: 'Slot $hour',
      startTime: '${hour.toString().padLeft(2, '0')}:00:00',
      endTime: '${(hour + 1).toString().padLeft(2, '0')}:00:00',
      priceAmount: 1500,
      isAvailable: reason == 'available',
      reason: reason,
    );

/// Eight slots a day; 22:00 is booked every day so the forecast has a
/// signal on any day the suite runs.
final _slots = [
  for (final h in [8, 10, 12, 14, 16, 18, 20]) _slot(h),
  _slot(22, reason: 'booked'),
];

Venue _venue(String slug) => Venue(
  id: 'v-$slug',
  name: 'Sunrise $slug venue with a fairly long display name',
  latitude: 0,
  longitude: 0,
  category: VenueCategory(id: 'c-$slug', slug: slug, name: slug),
);

Future<void> _pump(
  WidgetTester tester,
  Venue venue,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(
          MockBookingRepository(slots: _slots),
        ),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: BookingScreen(venue: venue),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// No overflow, nothing past the right edge, and no clipped labels in
/// whatever is currently built.
void _expectCleanLayout(WidgetTester tester, Size size) {
  expect(tester.takeException(), isNull);
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    if (!p.attached || !p.hasSize) continue;
    final box = p.localToGlobal(Offset.zero) & p.size;
    // Ignore paragraphs scrolled horizontally inside the date strip.
    final inStrip = find
        .ancestor(of: find.byWidget(e.widget), matching: find.byType(ListView))
        .evaluate()
        .any((l) => (l.widget as ListView).scrollDirection == Axis.horizontal);
    if (!inStrip) {
      expect(box.right, lessThanOrEqualTo(size.width + 0.5),
          reason: 'past right edge: "${p.text.toPlainText()}"');
    }
  }
}

Finder get _phoneScroll => find.byKey(const Key('booking_phone_scroll'));

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(of: _phoneScroll, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(target, 120, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  const phones = {
    'small phone 320x568': Size(320, 568),
    'small phone 320x640': Size(320, 640),
    'phone 375x667': Size(375, 667),
    'phone 390x844': Size(390, 844),
    'phone 430x932': Size(430, 932),
  };

  group('phone heights: whole form scrolls to every section', () {
    for (final slug in const ['function_hall', 'hotel']) {
      for (final entry in phones.entries) {
        for (final scale in const [1.0, 1.5]) {
          testWidgets('$slug on ${entry.key} at ${scale}x', (tester) async {
            await _check(tester, _venue(slug), entry.value, scale);
          });
        }
      }
      for (final width in const [320.0, 375.0, 390.0, 430.0]) {
        testWidgets('$slug ${width.toInt()}x640 at 2x text', (tester) async {
          await _check(tester, _venue(slug), Size(width, 640), 2);
        });
      }
    }
  });

  group('landscape and tablet', () {
    const sizes = {
      'phone landscape 568x320': Size(568, 320),
      'phone landscape 844x390': Size(844, 390),
      'tablet portrait 600x960': Size(600, 960),
      'tablet portrait 768x1024': Size(768, 1024),
      'tablet landscape 840x600': Size(840, 600),
      'tablet landscape 1024x768': Size(1024, 768),
    };
    for (final entry in sizes.entries) {
      for (final scale in const [1.0, 1.5]) {
        testWidgets('function_hall ${entry.key} at ${scale}x', (tester) async {
          await _pump(tester, _venue('function_hall'), entry.value,
              textScale: scale);
          _expectCleanLayout(tester, entry.value);
        });
      }
    }
  });

  group('booking field dropdowns fit at tablet/desktop widths', () {
    for (final width in const [600.0, 768.0, 840.0, 1024.0, 1200.0, 1280.0,
        1440.0, 1920.0]) {
      for (final slug in const ['sports', 'function_hall']) {
        testWidgets('$slug ${width.toInt()}px', (tester) async {
          final size = Size(width, 900);
          await _pump(tester, _venue(slug), size);
          _expectCleanLayout(tester, size);
          final key = slug == 'sports' ? 'equipment' : 'facilities';
          final dropdown = find.byKey(Key('booking_field_$key'));
          expect(dropdown, findsOneWidget);
          final rect = tester.getRect(dropdown);
          expect(rect.height, greaterThanOrEqualTo(48));
          // Pick the longest option and re-check: the selected label must
          // stay inside the field.
          await tester.ensureVisible(dropdown);
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          final option = slug == 'sports' ? 'Bring your own' : 'Decoration';
          await tester.tap(find.text(option).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final label = tester.getRect(
            find.descendant(of: dropdown, matching: find.text(option)).first,
          );
          expect(label.right, lessThanOrEqualTo(rect.right));
        });
      }
    }
  });
}

/// Phone check: every section reachable by scrolling, targets >= 48px, and
/// the last slot not hidden behind the confirm bar.
Future<void> _check(
  WidgetTester tester,
  Venue venue,
  Size size,
  double scale,
) async {
  final semantics = tester.ensureSemantics();
  try {
    await _checkBody(tester, venue, size, scale);
  } finally {
    semantics.dispose();
  }
}

Future<void> _checkBody(
  WidgetTester tester,
  Venue venue,
  Size size,
  double scale,
) async {
  await _pump(tester, venue, size, textScale: scale);
  expect(_phoneScroll, findsOneWidget, reason: 'phone layout scrolls');
  _expectCleanLayout(tester, size);

  // Date strip: reachable, every chip fully visible vertically, >=48px.
  final today = DateFormat.yMMMd().format(DateTime.now());
  final chip = find.bySemanticsLabel(RegExp('^${RegExp.escape(today)}'));
  await _scrollTo(tester, chip);
  _expectCleanLayout(tester, size);
  expect(tester.getSize(chip.first).height, greaterThanOrEqualTo(48));
  for (final e in find
      .descendant(of: chip.first, matching: find.byType(RichText))
      .evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    expect(p.didExceedMaxLines, isFalse);
    final chipRect = tester.getRect(chip.first);
    final textRect = p.localToGlobal(Offset.zero) & p.size;
    expect(textRect.bottom, lessThanOrEqualTo(chipRect.bottom + 0.5),
        reason: 'date chip text clipped at ${scale}x');
  }

  // Coupon Apply button stays tappable.
  final apply = find.widgetWithText(OutlinedButton, 'Apply');
  if (apply.evaluate().isNotEmpty) {
    expect(tester.getSize(apply.first).height, greaterThanOrEqualTo(48));
  }

  // Peak Booking Hours reachable.
  final card = find.byKey(const Key('peak_booking_hours_card'));
  await _scrollTo(tester, card);
  expect(tester.getRect(card).top, lessThan(size.height));
  expect(
    tester.getSize(find.byKey(const Key('peak_booking_hours_toggle'))).height,
    greaterThanOrEqualTo(48),
  );

  // Every slot reachable; select the first free one.
  final first = find.text('Slot 8');
  await _scrollTo(tester, first);
  await tester.tap(first);
  await tester.pumpAndSettle();
  _expectCleanLayout(tester, size);

  // With the confirm bar showing, the very last slot can still be scrolled
  // fully above it (content is not trapped behind the fixed control).
  final last = find.text('Slot 22');
  await _scrollTo(tester, last);
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: _phoneScroll, matching: find.byType(Scrollable)).first,
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pumpAndSettle();
  final bodyBottom = tester.getRect(_phoneScroll).bottom;
  final lastTile = tester.getRect(last);
  expect(lastTile.bottom, lessThanOrEqualTo(bodyBottom),
      reason: 'last slot hidden behind the confirm bar');
  final confirm = find.byType(FilledButton);
  expect(confirm, findsWidgets);
  expect(tester.getRect(confirm.last).top, greaterThanOrEqualTo(bodyBottom - 0.5));
  expect(tester.getSize(confirm.last).height, greaterThanOrEqualTo(48));
  _expectCleanLayout(tester, size);
}
