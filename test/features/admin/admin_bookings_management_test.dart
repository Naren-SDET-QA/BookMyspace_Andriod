import 'package:bookmyspace/features/admin/domain/admin_booking_filters.dart';
import 'package:bookmyspace/features/admin/domain/listing_moderation.dart';
import 'package:bookmyspace/features/admin/infrastructure/supabase_listing_moderation_repository.dart';
import 'package:bookmyspace/features/admin/presentation/admin_moderation_providers.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_oversight_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _rows = [
  OversightRow(
    id: 'b1',
    title: 'Sunrise Hall',
    subtitle: 'BMS-AAA111',
    status: 'awaiting_owner_approval',
    amount: 1000,
    reference: 'BMS-AAA111',
    customerName: 'Ravi Kumar',
  ),
  OversightRow(
    id: 'b2',
    title: 'Lotus Banquet',
    subtitle: 'BMS-BBB222',
    status: 'pending',
    amount: 2000,
    reference: 'BMS-BBB222',
    customerName: 'Anita',
  ),
  OversightRow(
    id: 'b3',
    title: 'Sunrise Hall',
    subtitle: 'BMS-CCC333',
    status: 'confirmed',
    amount: 3000,
    reference: 'BMS-CCC333',
    customerName: 'Meera',
    customerContact: 'meera@example.com',
  ),
  OversightRow(
    id: 'b4',
    title: 'Palm Grove',
    subtitle: 'BMS-DDD444',
    status: 'owner_rejected',
    reference: 'BMS-DDD444',
  ),
  OversightRow(
    id: 'b5',
    title: 'Palm Grove',
    subtitle: 'BMS-EEE555',
    status: 'completed',
  ),
];

class _FakeRepo implements SupabaseListingModerationRepository {
  String? cancelledId;
  String? cancelReason;
  double? cancelRefund;

  @override
  Future<void> adminCancelBooking({
    required String bookingId,
    required String reason,
    double? refundAmount,
  }) async {
    cancelledId = bookingId;
    cancelReason = reason;
    cancelRefund = refundAmount;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('admin booking filters', () {
    test('buckets statuses into tabs', () {
      expect(
        AdminBookingFilter.bucketOf('pending_owner_approval'),
        AdminBookingFilter.pendingApproval,
      );
      expect(
        AdminBookingFilter.bucketOf('held'),
        AdminBookingFilter.pendingPayment,
      );
      expect(
        AdminBookingFilter.bucketOf('approval_expired'),
        AdminBookingFilter.cancelled,
      );
      expect(AdminBookingFilter.bucketOf('completed'), isNull);
    });

    test('counts per status', () {
      final counts = adminBookingCounts(_rows);
      expect(counts[AdminBookingFilter.all], 5);
      expect(counts[AdminBookingFilter.pendingApproval], 1);
      expect(counts[AdminBookingFilter.pendingPayment], 1);
      expect(counts[AdminBookingFilter.confirmed], 1);
      expect(counts[AdminBookingFilter.cancelled], 1);
    });

    test('filters by status and searches reference, venue and customer', () {
      expect(
        filterAdminBookings(
          _rows,
          filter: AdminBookingFilter.confirmed,
        ).map((r) => r.id),
        ['b3'],
      );
      expect(filterAdminBookings(_rows, query: 'bms-bbb').map((r) => r.id), [
        'b2',
      ]);
      expect(filterAdminBookings(_rows, query: 'sunrise').map((r) => r.id), [
        'b1',
        'b3',
      ]);
      expect(filterAdminBookings(_rows, query: 'MEERA@').map((r) => r.id), [
        'b3',
      ]);
      expect(
        filterAdminBookings(
          _rows,
          filter: AdminBookingFilter.pendingApproval,
          query: 'lotus',
        ),
        isEmpty,
      );
    });
  });

  Widget app(_FakeRepo repo) => ProviderScope(
    overrides: [
      adminBookingsOversightProvider.overrideWith((ref) async => _rows),
      listingModerationRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      home: AdminOversightScreen(kind: AdminOversightKind.bookings),
    ),
  );

  testWidgets('filters with tabs and search', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(_FakeRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Lotus Banquet'), findsOneWidget);
    expect(find.text('All (5)'), findsOneWidget);

    final unpaidTab = find.byKey(
      AdminBookingsManagementView.filterKey(AdminBookingFilter.pendingPayment),
    );
    await tester.ensureVisible(unpaidTab);
    await tester.pumpAndSettle();
    await tester.tap(unpaidTab);
    await tester.pumpAndSettle();
    expect(find.text('Lotus Banquet'), findsOneWidget);
    expect(find.text('Palm Grove'), findsNothing);

    final allTab = find.byKey(
      AdminBookingsManagementView.filterKey(AdminBookingFilter.all),
    );
    await tester.ensureVisible(allTab);
    await tester.pumpAndSettle();
    await tester.tap(allTab);
    await tester.enterText(
      find.byKey(AdminBookingsManagementView.searchFieldKey),
      'ravi',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ravi Kumar'), findsOneWidget);
    expect(find.text('Lotus Banquet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin can cancel a confirmed booking with a reason', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    // Only the confirmed row offers the admin action.
    expect(find.text('Cancel as admin'), findsOneWidget);
    await tester.tap(find.byKey(AdminBookingsManagementView.cancelKey('b3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-cancel-refund')), '500');
    await tester.tap(find.byKey(const Key('admin-cancel-confirm')));
    await tester.pumpAndSettle();

    expect(repo.cancelledId, 'b3');
    expect(repo.cancelReason, 'Declined by Platform Admin');
    expect(repo.cancelRefund, 500);
    expect(find.text('Booking cancelled by platform admin'), findsOneWidget);
  });
}
