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

/// Booking categories that use request-to-book, with a venue for each.
const _categories = <String, String>{
  'Function Hall': 'Sunrise Function Hall',
  'Hotel / Stay': 'Lake View Hotel',
  'PG': 'Green Nest PG',
  'Institute': 'Bright Future Institute',
  'Sports ground': 'City Turf Arena',
  'Meeting room': 'Hub Meeting Room',
  'Coworking': 'Desk Coworking Space',
};

/// Owner columns exactly as the repository reads them: the venue's
/// `organizations(name, owner_user_id)` embed and the owner's `profiles` row.
const _lakshmiOrg = {'name': 'Rao Events Pvt Ltd', 'owner_user_id': 'o1'};
const _lakshmiProfile = {
  'full_name': 'Lakshmi Rao',
  'phone': '9000000001',
  'email': 'lakshmi@raoevents.in',
};

({String name, String contact}) _owner({
  Object? organization = _lakshmiOrg,
  Map<String, dynamic>? profile = _lakshmiProfile,
}) => SupabaseListingModerationRepository.ownerDetails(
  organization: organization,
  ownerProfile: profile,
);

OversightRow _row(
  String id,
  String status, {
  String title = 'Sunrise Function Hall',
  ({String name, String contact})? owner,
}) {
  final o = owner ?? _owner();
  return OversightRow(
    id: id,
    title: title,
    subtitle: 'BMS-$id',
    status: status,
    amount: 25000,
    reference: 'BMS-$id',
    customerName: 'Ravi Kumar',
    ownerName: o.name,
    ownerContact: o.contact,
  );
}

/// Fake backend for the admin screen: keeps booking statuses so a refresh
/// after a decision shows the new state, like the real provider re-reading
/// `bookings`. Approval moves a request to `pending` (waiting for payment),
/// as `approve_venue_booking` does; it never confirms.
class _FakeRepo implements SupabaseListingModerationRepository {
  _FakeRepo(List<OversightRow> rows) : rows = [...rows];

  List<OversightRow> rows;
  final approved = <String>[];
  final rejected = <String, String>{};
  int loads = 0;

  /// When set, the next approve/reject throws this. [statusAfterError]
  /// simulates what the server state is by then (e.g. the owner approved).
  AppException? nextError;
  String? statusAfterError;

  /// When set, approve waits for it (to test the busy state).
  Completer<void>? gate;

  String statusOf(String id) => rows.firstWhere((r) => r.id == id).status;

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

  void _throwIfScripted(String id) {
    final error = nextError;
    if (error == null) return;
    nextError = null;
    final after = statusAfterError;
    if (after != null) _setStatus(id, after);
    throw error;
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
    _throwIfScripted(bookingId);
    _setStatus(bookingId, 'pending');
  }

  @override
  Future<void> adminRejectBooking(
    String bookingId, {
    required String reason,
  }) async {
    rejected[bookingId] = reason;
    _throwIfScripted(bookingId);
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

Key _approve(String id) => AdminBookingsManagementView.approveKey(id);
Key _decline(String id) => AdminBookingsManagementView.declineKey(id);
Key _ownerLine(String id) => Key('admin-booking-owner-$id');

const _admins = {
  'super administrator': AppRole.superAdministrator,
  'administrator': AppRole.administrator,
};

List<OversightRow> _standardRows() => [
  _row('hall1', 'awaiting_owner_approval'),
  _row('hotel1', 'awaiting_owner_approval', title: 'Lake View Hotel'),
  _row('hall2', 'pending'),
  _row('hall3', 'owner_rejected'),
  _row('hall4', 'confirmed'),
];

Future<void> _declineWithReason(
  WidgetTester tester,
  String id,
  String reason,
) async {
  await tester.tap(find.byKey(_decline(id)));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('admin-decline-reason')), reason);
  await tester.tap(find.byKey(const Key('admin-decline-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  group('every category: administrators approve and decline', () {
    for (final MapEntry(key: category, value: venue) in _categories.entries) {
      for (final MapEntry(key: who, value: role) in _admins.entries) {
        testWidgets('$category: $who approves -> waiting for payment', (
          tester,
        ) async {
          final repo = _FakeRepo([
            _row('r1', 'awaiting_owner_approval', title: venue),
          ]);
          await tester.pumpWidget(_app(repo, {role}));
          await tester.pumpAndSettle();
          expect(find.text(venue), findsOneWidget);

          await tester.tap(find.byKey(_approve('r1')));
          await tester.pumpAndSettle();

          expect(repo.approved, ['r1']);
          expect(repo.statusOf('r1'), 'pending');
          expect(repo.statusOf('r1'), isNot('confirmed'));
          expect(
            find.text('Request approved. The customer can now pay.'),
            findsOneWidget,
          );
          expect(find.byKey(_approve('r1')), findsNothing);
          expect(find.byKey(_decline('r1')), findsNothing);
          // Refreshed row now shows the waiting-for-payment status.
          expect(find.textContaining('pending'), findsOneWidget);
        });

        testWidgets('$category: $who declines with a reason', (tester) async {
          final repo = _FakeRepo([
            _row('r1', 'awaiting_owner_approval', title: venue),
          ]);
          await tester.pumpWidget(_app(repo, {role}));
          await tester.pumpAndSettle();

          await _declineWithReason(tester, 'r1', 'Venue closed that day');

          expect(repo.rejected, {'r1': 'Venue closed that day'});
          expect(repo.statusOf('r1'), 'owner_rejected');
          expect(
            find.text('Request declined. The slot was released.'),
            findsOneWidget,
          );
          expect(find.byKey(_approve('r1')), findsNothing);
        });
      }
    }

    testWidgets('a mixed list offers decisions on every awaiting request only',
        (tester) async {
      final rows = [
        for (final (i, venue) in _categories.values.indexed)
          _row('r$i', 'awaiting_owner_approval', title: venue),
        _row('paid', 'confirmed'),
        _row('unpaid', 'pending'),
        _row('declined', 'owner_rejected'),
        _row('expired', 'approval_expired'),
        _row('cancelled', 'cancelled'),
      ];
      tester.view.physicalSize = const Size(1280, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(_FakeRepo(rows), {AppRole.superAdministrator}),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < _categories.length; i++) {
        expect(find.byKey(_approve('r$i')), findsOneWidget);
        expect(find.byKey(_decline('r$i')), findsOneWidget);
      }
      for (final id in ['paid', 'unpaid', 'declined', 'expired', 'cancelled']) {
        expect(find.byKey(_approve(id)), findsNothing, reason: id);
        expect(find.byKey(_decline(id)), findsNothing, reason: id);
      }
    });
  });

  group('unauthorized users cannot decide', () {
    for (final roles in [
      <AppRole>{},
      {AppRole.customer},
      {AppRole.customer, AppRole.venueOwner},
      {AppRole.supportAgent},
      {AppRole.instituteOwner},
    ]) {
      final label = roles.isEmpty
          ? 'signed out / no role'
          : roles.map((r) => r.name).join('+');
      testWidgets('no Approve/Decline for $label', (tester) async {
        await tester.pumpWidget(_app(_FakeRepo(_standardRows()), roles));
        await tester.pumpAndSettle();
        expect(find.text('Approve'), findsNothing);
        expect(find.text('Decline'), findsNothing);
      });
    }

    testWidgets(
      'a server refusal (NOT_OWNER_OR_NOT_FOUND) is shown and changes nothing',
      (tester) async {
        final repo = _FakeRepo(_standardRows())
          ..nextError = const BusinessException(
            'You are not allowed to decide this request.',
            code: 'NOT_OWNER_OR_NOT_FOUND',
          );
        await tester.pumpWidget(_app(repo, {AppRole.administrator}));
        await tester.pumpAndSettle();
        final loadsBefore = repo.loads;

        await tester.tap(find.byKey(_approve('hall1')));
        await tester.pumpAndSettle();

        expect(
          find.text('You are not allowed to decide this request.'),
          findsOneWidget,
        );
        expect(repo.statusOf('hall1'), 'awaiting_owner_approval');
        // Not a stale-state code: no forced refresh, buttons stay.
        expect(repo.loads, loadsBefore);
        expect(find.byKey(_approve('hall1')), findsOneWidget);
      },
    );
  });

  group('first decision wins', () {
    testWidgets('owner approved first: admin Approve -> already processed, '
        'row refreshed', (tester) async {
      final repo = _FakeRepo(_standardRows())
        ..nextError = const BusinessException(
          'This request has already been processed.',
          code: 'ALREADY_PROCESSED',
        )
        ..statusAfterError = 'pending';
      await tester.pumpWidget(_app(repo, {AppRole.administrator}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_approve('hall1')));
      await tester.pumpAndSettle();

      expect(
        find.text('This request has already been processed.'),
        findsOneWidget,
      );
      expect(repo.statusOf('hall1'), 'pending');
      expect(find.byKey(_approve('hall1')), findsNothing);
      expect(find.byKey(_decline('hall1')), findsNothing);
    });

    testWidgets('owner approved first: admin Decline is refused, row '
        'refreshed', (tester) async {
      final repo = _FakeRepo(_standardRows())
        ..nextError = const BusinessException(
          'This request is no longer awaiting approval.',
          code: 'INVALID_STATUS',
        )
        ..statusAfterError = 'pending';
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();

      await _declineWithReason(tester, 'hotel1', 'Duplicate request');

      expect(
        find.text('This request is no longer awaiting approval.'),
        findsOneWidget,
      );
      expect(repo.statusOf('hotel1'), 'pending');
      expect(find.byKey(_decline('hotel1')), findsNothing);
    });

    testWidgets('admin decision then a second admin tap is impossible', (
      tester,
    ) async {
      final repo = _FakeRepo(_standardRows());
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_approve('hall1')));
      await tester.pumpAndSettle();
      expect(find.byKey(_approve('hall1')), findsNothing);
      expect(repo.approved, ['hall1']);
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
  });

  group('decline dialog', () {
    testWidgets('"Keep request" changes nothing', (tester) async {
      final repo = _FakeRepo(_standardRows());
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_decline('hall1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep request'));
      await tester.pumpAndSettle();

      expect(repo.rejected, isEmpty);
      expect(find.byKey(_approve('hall1')), findsOneWidget);
    });

    testWidgets('a reason is required', (tester) async {
      final repo = _FakeRepo(_standardRows());
      await tester.pumpWidget(_app(repo, {AppRole.superAdministrator}));
      await tester.pumpAndSettle();

      await _declineWithReason(tester, 'hall1', '   ');

      expect(find.text('Please enter a reason'), findsOneWidget);
      expect(repo.rejected, isEmpty);
    });
  });

  group('owner details on admin booking cards', () {
    testWidgets('shows owner name, phone and email', (tester) async {
      await tester.pumpWidget(
        _app(
          _FakeRepo([_row('r1', 'awaiting_owner_approval')]),
          {AppRole.administrator},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Owner: Lakshmi Rao · 9000000001 · lakshmi@raoevents.in'),
        findsOneWidget,
      );
    });

    testWidgets('phone only', (tester) async {
      final owner = _owner(
        profile: {'full_name': 'Lakshmi Rao', 'phone': '9000000001'},
      );
      await tester.pumpWidget(
        _app(
          _FakeRepo([_row('r1', 'awaiting_owner_approval', owner: owner)]),
          {AppRole.administrator},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Owner: Lakshmi Rao · 9000000001'), findsOneWidget);
    });

    testWidgets('email only', (tester) async {
      final owner = _owner(
        profile: {
          'full_name': 'Lakshmi Rao',
          'phone': '',
          'email': 'lakshmi@raoevents.in',
        },
      );
      await tester.pumpWidget(
        _app(
          _FakeRepo([_row('r1', 'awaiting_owner_approval', owner: owner)]),
          {AppRole.administrator},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Owner: Lakshmi Rao · lakshmi@raoevents.in'),
        findsOneWidget,
      );
    });

    testWidgets('no phone or email: name only, no dangling separators', (
      tester,
    ) async {
      final owner = _owner(profile: {'full_name': 'Lakshmi Rao'});
      await tester.pumpWidget(
        _app(
          _FakeRepo([_row('r1', 'awaiting_owner_approval', owner: owner)]),
          {AppRole.administrator},
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.byKey(_ownerLine('r1'))).data;
      expect(text, 'Owner: Lakshmi Rao');
    });

    testWidgets('no owner profile: organization name is shown', (
      tester,
    ) async {
      final owner = _owner(profile: null);
      await tester.pumpWidget(
        _app(
          _FakeRepo([_row('r1', 'awaiting_owner_approval', owner: owner)]),
          {AppRole.administrator},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Owner: Rao Events Pvt Ltd'), findsOneWidget);
    });

    testWidgets('no owner data at all: no owner line, card still works', (
      tester,
    ) async {
      final owner = _owner(organization: null, profile: null);
      final repo = _FakeRepo([
        _row('r1', 'awaiting_owner_approval', owner: owner),
      ]);
      await tester.pumpWidget(_app(repo, {AppRole.administrator}));
      await tester.pumpAndSettle();
      expect(find.byKey(_ownerLine('r1')), findsNothing);
      expect(find.textContaining('Owner:'), findsNothing);
      await tester.tap(find.byKey(_approve('r1')));
      await tester.pumpAndSettle();
      expect(repo.approved, ['r1']);
    });

    testWidgets('each card shows the owner of its own venue', (tester) async {
      final rows = [
        _row('hall', 'awaiting_owner_approval'),
        _row(
          'hotel',
          'awaiting_owner_approval',
          title: 'Lake View Hotel',
          owner: _owner(
            organization: {'name': 'Lake Stays', 'owner_user_id': 'o2'},
            profile: {'full_name': 'Arjun Reddy', 'phone': '9000000002'},
          ),
        ),
        _row(
          'pg',
          'awaiting_owner_approval',
          title: 'Green Nest PG',
          owner: _owner(
            organization: {'name': 'Green Nest Living', 'owner_user_id': 'o3'},
            profile: {'full_name': 'Meena Iyer', 'email': 'meena@gn.in'},
          ),
        ),
      ];
      tester.view.physicalSize = const Size(1280, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_FakeRepo(rows), {AppRole.administrator}));
      await tester.pumpAndSettle();

      String ownerOf(String id) =>
          tester.widget<Text>(find.byKey(_ownerLine(id))).data!;
      expect(
        ownerOf('hall'),
        'Owner: Lakshmi Rao · 9000000001 · lakshmi@raoevents.in',
      );
      expect(ownerOf('hotel'), 'Owner: Arjun Reddy · 9000000002');
      expect(ownerOf('pg'), 'Owner: Meena Iyer · meena@gn.in');
      // The owner line sits inside its own booking card.
      for (final (id, venue) in [
        ('hall', 'Sunrise Function Hall'),
        ('hotel', 'Lake View Hotel'),
        ('pg', 'Green Nest PG'),
      ]) {
        final card = find.ancestor(
          of: find.byKey(_ownerLine(id)),
          matching: find.byType(Card),
        );
        expect(
          find.descendant(of: card, matching: find.text(venue)),
          findsOneWidget,
        );
      }
    });
  });

  group('repository owner details mapping', () {
    test('profile full name, phone and email', () {
      final o = _owner();
      expect(o.name, 'Lakshmi Rao');
      expect(o.contact, '9000000001 · lakshmi@raoevents.in');
    });

    test('falls back to the organization name without a profile name', () {
      final o = _owner(profile: {'phone': '9000000001'});
      expect(o.name, 'Rao Events Pvt Ltd');
      expect(o.contact, '9000000001');
    });

    test('blank values are treated as missing', () {
      final o = _owner(
        organization: {'name': '  '},
        profile: {'full_name': ' ', 'phone': ' ', 'email': ''},
      );
      expect(o.name, isEmpty);
      expect(o.contact, isEmpty);
    });

    test('missing organization and profile', () {
      final o = _owner(organization: null, profile: null);
      expect(o.name, isEmpty);
      expect(o.contact, isEmpty);
    });
  });

  test('decision error codes map to clear messages', () {
    String m(String c) =>
        SupabaseListingModerationRepository.adminDecisionMessage(c);
    expect(m('ALREADY_PROCESSED'), 'This request has already been processed.');
    expect(m('INVALID_STATUS'), contains('no longer awaiting'));
    expect(m('APPROVAL_EXPIRED'), contains('expired'));
    expect(m('NOT_OWNER_OR_NOT_FOUND'), contains('not allowed'));
    expect(m('SOMETHING'), contains('SOMETHING'));
  });

  group('responsive', () {
    const widths = [
      320,
      375,
      390,
      430,
      600,
      768,
      840,
      1024,
      1200,
      1280,
      1440,
      1920,
    ];

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
      final owner = tester.getRect(find.byKey(_ownerLine('hall1')));
      expect(owner.right, lessThanOrEqualTo(size.width));
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
