import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/support/domain/help_faq.dart';
import 'package:bookmyspace/features/support/domain/support_ticket.dart';
import 'package:bookmyspace/features/support/presentation/screens/support_screen.dart';
import 'package:bookmyspace/features/support/presentation/support_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

HelpTopic? _topic(String q) => HelpFaqCatalog.match(q)?.topic;

void main() {
  group('HelpFaqCatalog.match', () {
    test('matches each topic by keyword', () {
      expect(_topic('How do refunds work?'), HelpTopic.refundPolicy);
      expect(_topic('I want to CANCEL my booking'), HelpTopic.refundPolicy);
      expect(_topic('wallet balance'), HelpTopic.walletReferral);
      expect(_topic('refer a friend'), HelpTopic.walletReferral);
      expect(_topic('any coupon available'), HelpTopic.promoCodes);
      expect(_topic('where is my QR code'), HelpTopic.qrCheckIn);
      expect(_topic('how to check in at venue'), HelpTopic.qrCheckIn);
      expect(_topic('can I pay with UPI'), HelpTopic.paymentMethods);
      expect(_topic('looking for a PG near me'), HelpTopic.pgHostel);
      expect(_topic('hostel rooms'), HelpTopic.pgHostel);
      expect(_topic('list my venue as owner'), HelpTopic.listProperty);
      expect(_topic('talk to a human agent'), HelpTopic.contactSupport);
    });

    test('returns null for empty or unknown queries', () {
      expect(HelpFaqCatalog.match(''), isNull);
      expect(HelpFaqCatalog.match('   '), isNull);
      expect(HelpFaqCatalog.match('weather tomorrow'), isNull);
    });

    test('matches only at word starts', () {
      // "display" contains "pay" but not at a word start.
      expect(_topic('display settings'), isNull);
    });

    test('more keyword hits win over earlier entries', () {
      expect(
        _topic('refund to my wallet balance credit'),
        HelpTopic.walletReferral,
      );
    });

    test('refund answer uses the app tiered policy, not invented numbers', () {
      final refund = HelpFaqCatalog.forTopic(HelpTopic.refundPolicy);
      expect(refund.answer, contains('48 hours'));
      expect(refund.answer, contains('50%'));
      expect(refund.answer, isNot(contains('90%')));
    });

    test('every action deep-links to a known route', () {
      const known = {
        AppRoutes.bookings,
        AppRoutes.referrals,
        AppRoutes.home,
        AppRoutes.paymentHistory,
        AppRoutes.pgList,
        AppRoutes.unifiedRegistration,
        AppRoutes.support,
      };
      for (final a in HelpFaqCatalog.answers) {
        expect(a.hasAction, isTrue, reason: a.topic.name);
        expect(known, contains(a.actionRoute), reason: a.topic.name);
      }
      expect(
        HelpFaqCatalog.answers.map((a) => a.topic).toSet(),
        HelpTopic.values.toSet(),
      );
    });
  });

  group('Support hub screen', () {
    Widget app({SupportContact contact = const SupportContact()}) {
      final router = GoRouter(
        initialLocation: AppRoutes.support,
        routes: [
          GoRoute(
            path: AppRoutes.support,
            builder: (_, __) => const SupportTicketsScreen(),
          ),
          GoRoute(
            path: AppRoutes.paymentHistory,
            builder: (_, __) => const Scaffold(body: Text('payments-page')),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          moduleEnabledProvider.overrideWith((ref, id) => true),
          myTicketsProvider.overrideWith((ref) async => <SupportTicket>[]),
          supportContactProvider.overrideWithValue(contact),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    testWidgets('shows FAQ, hides contact buttons without config', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('support-call')), findsNothing);
      expect(find.byKey(const Key('support-email')), findsNothing);
      await tester.tap(find.text('How do cancellations and refunds work?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('48 hours or more'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows call/email when contact configured', (tester) async {
      await tester.pumpWidget(
        app(
          contact: const SupportContact(
            phone: '+911234567890',
            email: 'help@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('support-call')), findsOneWidget);
      expect(find.byKey(const Key('support-email')), findsOneWidget);
    });

    testWidgets('assistant answers and deep-links', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('support-open-assistant')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('help-assistant-input')),
        'Can I pay by UPI?',
      );
      await tester.tap(find.byKey(const Key('help-assistant-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Razorpay checkout'), findsOneWidget);

      await tester.tap(find.byKey(const Key('help-action-paymentMethods')));
      await tester.pumpAndSettle();
      expect(find.text('payments-page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
