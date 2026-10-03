import 'dart:async';

import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/admin/domain/listing_moderation.dart';
import 'package:bookmyspace/features/admin/infrastructure/supabase_listing_moderation_repository.dart';
import 'package:bookmyspace/features/admin/presentation/admin_moderation_providers.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_oversight_screen.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OversightRow _row(
  String id,
  String status, {
  String title = 'Sunrise Function Hall',
}) => OversightRow(
  id: id,
  title: title,
  subtitle: 'BMS-$id',
  status: status,
  amount: 25000,
  reference: 'BMS-$id',
  customerName: 'Ravi Kumar',
  ownerName: 'Lakshmi Rao',
  ownerContact: '9000000001',
);

/// Fake backend: keeps booking statuses so a refresh after a decision shows
/// the new state, like the real provider re-reading `bookings`.
class _FakeRepo implements SupabaseListingModerationRepository {
  _FakeRepo(List<OversightRow> rows) : rows = [...rows];

  List<OversightRow> rows;
  final approved = <String>[];
  final rejected = <String, String>{};
  int loads = 0;

  /// When set, the next approve/reject throws this instead.
  AppException? nextError;

  /// When set, approve waits for it (to test the busy state).
  Completer<void>? gate;

  void _setStatus(String id, String status) {
    rows = [
      for (final r in rows)
        r.id == id
            ? OversightRow(
                id: r.id,
                title: r.title,
                subtitle: r.subtitle,
                status: status,
                amount: r.amount,
                reference: r.reference,
                customerName: r.customerName,
                ownerName: r.ownerName,
                ownerContact: r.ownerContact,
              )
            : r,
    ];
  }

  @override
  Future<List<OversightRow>> bookings({int limit = 50}) async {
    loads++;
    return rows;
  }

  @override
  Future<void> adminApproveBooking(String bookingId) async {
    approved.add(bookingId);
    if (gate != null) await gate!.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      // Someone else (the owner) approved first.
      _setStatus(bookingId, 'pending');
      throw error;
    }
    _setStatus(bookingId, 'pending');
  }

  @override
  Future<void> adminRejectBooking(
    String bookingId, {
    required String reason,
  }) async {
    rejected[bookingId] = reason;
    _setStatus(bookingId, 'owner_rejected');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(_FakeRepo repo, Set<AppRole> roles) => ProviderScope(
  overrides: [
    listingModerationRepositoryProvider.overrideWithValue(repo),
    currentUserRolesProvider.overrideWith((ref) async => roles),
  ],
  child: const MaterialApp(
    home: AdminOversightScreen(kind: AdminOversightKind.bookings),
  ),
);

final _approve = AdminBookingsManagementView.approveKey;
final _decline = AdminBookingsManagementView.declineKey;

List<OversightRow> _standardRows() => [
  _row('hall1', 'awaiting_owner_approval'),
  _row('hotel1', 'awaiting_owner_approval', title: 'Lake Hotel'),
  _row('hall2', 'pending'),
  _row('hall3', 'owner_rejected'),
  _row('hall4', 'confirmed'),
];

void main() {
  group('who sees Approve / Decline', () {
    for (final role in [AppRole.superAdministrator, AppRole.administrator]) {
      testWidgets('${role.databaseValue} sees them on every request awaiting '
          'approval, with the owner details', (tester) async {
        await tester.pumpWidget(_app(_FakeRepo(_standardRows()), {role}));
        await tester.pumpAndSettle();

        // Every category goes to the admin as well as the owner.
        for (final id in ['hall1', 'hotel1']) {
          expect(find.byKey(_approve(id)), findsOneWidget);
          expect(find.byKey(_decline(id)), findsOneWidget);
        }
        expect(find.text('Owner: Lakshmi Rao · 9000000001'), findsWidgets);
        // Already processed rows never show decision buttons.
        for (final id in ['hall2', 'hall3', 'hall4']) {
          expect(find.byKey(_approve(id)), findsNothing);
          expect(find.byKey(_decline(id)), findsNothing);
        }
        expect(find.text('Approve'), findsWidgets);
        expect(find.text('Decline'), findsWidgets);
      });
    }

    for (final roles in [
      <AppRole>{},
      {AppRole.customer},
      {AppRole.customer, AppRole.venueOwner},
      {AppRole.supportAgent},
    ]) {
      testWidgets('no buttons for ${roles.map((r) => r.name).join('+')}', (
        tester,
      ) async {
        await tester.pumpWidget(_app(_FakeRepo(_standardRows()), roles));
        await tester.pumpAndSettle();
        expect(find.text('Approve'), findsNothing);
        expect(find.text('Decline'), findsNothing);
      });
    }
  });

  testWidgets('approve calls the repository, refreshes and removes buttons', (
    tester,
  ) async {
    final repo = _FakeRepo(_standardRows());
    await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
    await tester.pumpAndSettle();
    final loadsBefore = repo.loads;

    await tester.tap(find.byKey(_approve('hall1')));
    await tester.pumpAndSettle();

    expect(repo.approved, ['hall1']);
    expect(repo.loads, greaterThan(loadsBefore));
    expect(
      find.text('Request approved. The customer can now pay.'),
      findsOneWidget,
    );
    expect(find.byKey(_approve('hall1')), findsNothing);
    expect(find.byKey(_decline('hall1')), findsNothing);
  });

  testWidgets('a second tap while approving does not call twice', (
    tester,
  ) async {
    final repo = _FakeRepo(_standardRows())..gate = Completer<void>();
    await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_approve('hall1')));
    await tester.pump();
    await tester.tap(find.byKey(_approve('hall1')), warnIfMissed: false);
    await tester.tap(find.byKey(_decline('hall1')), warnIfMissed: false);
    await tester.pump();
    expect(repo.approved, ['hall1']);
    expect(repo.rejected, isEmpty);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_approve('hall1')), findsNothing);
  });

  testWidgets('owner approved first: admin sees "already processed" and the '
      'row refreshes', (tester) async {
    final repo = _FakeRepo(_standardRows())
      ..nextError = const BusinessException(
        'This request has already been processed.',
        code: 'ALREADY_PROCESSED',
      );
    await tester.pumpWidget(_app(repo, {AppRole.administrator}));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_approve('hall1')));
    await tester.pumpAndSettle();

    expect(
      find.text('This request has already been processed.'),
      findsOneWidget,
    );
    expect(find.byKey(_approve('hall1')), findsNothing);
    expect(find.byKey(_decline('hall1')), findsNothing);
  });

  group('decline', () {
    testWidgets('needs confirmation: "Keep request" changes nothing', (
      tester,
    ) async {
      final repo = _FakeRepo(_standardRows());
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_decline('hall1')));
      await tester.pumpAndSettle();
      expect(find.text('Decline request'), findsWidgets);
      await tester.tap(find.text('Keep request'));
      await tester.pumpAndSettle();

      expect(repo.rejected, isEmpty);
      expect(find.byKey(_approve('hall1')), findsOneWidget);
    });

    testWidgets('a reason is required', (tester) async {
      final repo = _FakeRepo(_standardRows());
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_decline('hall1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('admin-decline-reason')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('admin-decline-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a reason'), findsOneWidget);
      expect(repo.rejected, isEmpty);
    });

    testWidgets('confirmed decline sends the reason and refreshes', (
      tester,
    ) async {
      final repo = _FakeRepo(_standardRows());
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_decline('hall1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('admin-decline-reason')),
        'Hall closed for maintenance',
      );
      await tester.tap(find.byKey(const Key('admin-decline-confirm')));
      await tester.pumpAndSettle();

      expect(repo.rejected, {'hall1': 'Hall closed for maintenance'});
      expect(
        find.text('Request declined. The slot was released.'),
        findsOneWidget,
      );
      expect(find.byKey(_decline('hall1')), findsNothing);
    });
  });

  test('error codes map to clear messages', () {
    String m(String c) =>
        SupabaseListingModerationRepository.adminDecisionMessage(c);
    expect(m('ALREADY_PROCESSED'), 'This request has already been processed.');
    expect(m('INVALID_STATUS'), contains('no longer awaiting'));
    expect(m('APPROVAL_EXPIRED'), contains('expired'));
    expect(m('NOT_OWNER_OR_NOT_FOUND'), contains('not allowed'));
    expect(m('SOMETHING'), contains('SOMETHING'));
  });

  group('responsive', () {
    const widths = [320, 375, 390, 430, 600, 768, 840, 1024, 1200, 1280, 1440,
      1920];

    Future<void> check(
      WidgetTester tester, {
      required Size size,
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final repo = _FakeRepo(_standardRows());
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final approve = find.byKey(_approve('hall1'));
      final decline = find.byKey(_decline('hall1'));
      await tester.ensureVisible(approve);
      await tester.pumpAndSettle();
      for (final button in [approve, decline]) {
        final rect = tester.getRect(button);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.height, greaterThanOrEqualTo(36));
      }
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(repo.approved, ['hall1']);
      expect(tester.takeException(), isNull);
    }

    for (final w in widths) {
      testWidgets('width $w', (tester) async {
        await check(tester, size: Size(w.toDouble(), w < 600 ? 800 : 900));
      });
    }

    testWidgets('phone landscape 844x390', (tester) async {
      await check(tester, size: const Size(844, 390));
    });

    testWidgets('tablet landscape 1024x768', (tester) async {
      await check(tester, size: const Size(1024, 768));
    });

    for (final scale in [1.5, 2.0]) {
      testWidgets('${scale}x text at 320x568', (tester) async {
        await check(tester, size: const Size(320, 568), textScale: scale);
      });
    }
  });
}
