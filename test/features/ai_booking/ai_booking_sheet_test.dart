import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/ai_booking/presentation/widgets/ai_booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: AiBookingSheet()),
  );
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

/// The English text for a key — what an `en` locale renders.
String _en(String key) => AppLocalizations.english(key);

void main() {
  testWidgets('opens with a greeting and quick suggestions', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text(_en('aiReplyGreeting')), findsOneWidget);
    expect(find.text(_en('aiQuick1')), findsOneWidget);
    expect(find.text(_en('aiQuick4')), findsOneWidget);
    // Nothing is offered for booking until the customer actually asks.
    expect(find.text(_en('aiShowResults')), findsNothing);
    expect(find.text(_en('aiOpenBookings')), findsNothing);
  });

  testWidgets('echoes the question and shows the slots it understood',
      (tester) async {
    await tester.pumpWidget(_host());
    await _ask(tester, 'badminton in Hyderabad under 1000');

    // The customer's own words are echoed back verbatim.
    expect(find.text('badminton in Hyderabad under 1000'), findsOneWidget);
    // Interpreted slots render as chips. Exact text, so neither the echo above
    // nor the composer's hint placeholder can satisfy these.
    expect(
      find.text('${_en('aiSlotCategory')}: ${_en('aiCatBadminton')}'),
      findsOneWidget,
    );
    expect(
      find.text('${_en('aiSlotLocation')}: ${_en('aiCityHyderabad')}'),
      findsOneWidget,
    );
    expect(
      find.text('${_en('aiSlotBudget')}: ≤ ₹1,000'),
      findsOneWidget,
    );
    // And there is a route through to the real results screen.
    expect(find.text(_en('aiShowResults')), findsOneWidget);
    expect(find.text(_en('aiReplyDiscover')), findsOneWidget);
  });

  testWidgets('renders the reply and the slots in the selected language',
      (tester) async {
    await tester.pumpWidget(_host(locale: const Locale('te')));
    await _ask(tester, 'badminton in Hyderabad under 1000');

    final te = AppLocalizations(const Locale('te'));
    expect(find.text(te.aiText('aiReplyDiscover')), findsOneWidget);
    // Exact chip text, so the composer's hint placeholder cannot satisfy it.
    expect(
      find.text(
          '${te.aiText('aiSlotCategory')}: ${te.aiText('aiCatBadminton')}'),
      findsOneWidget,
    );
    expect(
      find.text(
          '${te.aiText('aiSlotLocation')}: ${te.aiText('aiCityHyderabad')}'),
      findsOneWidget,
    );
    expect(find.text(te.aiShowResults), findsOneWidget);
  });

  testWidgets('a my-bookings request offers the bookings list instead',
      (tester) async {
    await tester.pumpWidget(_host());
    await _ask(tester, 'my bookings');

    expect(find.text(_en('aiReplyShowBookings')), findsOneWidget);
    expect(find.text(_en('aiOpenBookings')), findsOneWidget);
    expect(find.text(_en('aiShowResults')), findsNothing);
  });

  testWidgets('an unrecognised request asks again instead of inventing filters',
      (tester) async {
    await tester.pumpWidget(_host());
    await _ask(tester, 'zz');

    expect(find.text(_en('aiReplyUnrecognised')), findsOneWidget);
    expect(find.text(_en('aiShowResults')), findsNothing);
  });

  testWidgets('tapping a suggestion asks it', (tester) async {
    await tester.pumpWidget(_host());
    await _ask(tester, 'badminton in Hyderabad');

    // This reply suggests "My bookings" and "Clear filters".
    final chip = find.text(_en('aiQuick6'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text(_en('aiReplyClearFilters')), findsOneWidget);
  });
}
