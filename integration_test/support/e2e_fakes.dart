import 'dart:async';
import 'dart:collection';

import 'package:bookmyspace/features/auth/domain/auth_repository.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/domain/booking_repository.dart';
import 'package:bookmyspace/features/owner/domain/owner.dart';
import 'package:bookmyspace/features/owner_venues/domain/owner_availability.dart';
import 'package:bookmyspace/features/owner_venues/domain/owner_availability_repository.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/domain/payment.dart';

import '../../test/features/booking/mock_booking_repository_release.dart';
import '../../test/features/payments/mock_payment_repository_release.dart';
import '../../test/features/venues/mock_venue_repository_release.dart';

/// Copies [booking] with a new status (and optionally payment method),
/// keeping every other field. Mirrors what a server status change returns.
Booking copyBooking(
  Booking booking, {
  required BookingStatus status,
  String? paymentMethod,
}) {
  return Booking(
    id: booking.id,
    bookingRef: booking.bookingRef,
    venueId: booking.venueId,
    slotId: booking.slotId,
    bookDate: booking.bookDate,
    startTime: booking.startTime,
    endTime: booking.endTime,
    status: status,
    amount: booking.amount,
    taxAmount: booking.taxAmount,
    totalAmount: booking.totalAmount,
    discountAmount: booking.discountAmount,
    venueName: booking.venueName,
    venueCity: booking.venueCity,
    slotLabel: booking.slotLabel,
    createdAt: booking.createdAt,
    customerName: booking.customerName,
    customerPhone: booking.customerPhone,
    isOffline: booking.isOffline,
    paymentMethod: paymentMethod ?? booking.paymentMethod,
    paymentRef: booking.paymentRef,
    paidAt: booking.paidAt,
    metadata: booking.metadata,
  );
}

/// Replaces the booking with [id] in [store]; returns the new value.
Booking? _updateInStore(
  List<Booking> store,
  String id,
  Booking Function(Booking current) update,
) {
  final index = store.indexWhere((b) => b.id == id);
  if (index < 0) return null;
  return store[index] = update(store[index]);
}

/// Auth backed by a fixed account directory. The role on each account plays
/// the part of the backend `profiles.role` column: the client never decides
/// it. Unknown emails sign in as a plain customer, like the shared mock.
class E2eAuthRepository implements AuthRepository {
  // Interface members added by the merged branches that this double does
  // not exercise fall through here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  E2eAuthRepository({AuthUser? initialUser, required this.directory})
    : _user = initialUser;

  /// Lower-cased email -> account.
  final Map<String, AuthUser> directory;

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();
  final _recovery = StreamController<bool>.broadcast();

  bool failSignIn = false;
  bool failVerify = false;
  int signInCount = 0;
  int verifyCount = 0;
  int signOutCount = 0;

  /// Closes the auth streams. The harness calls this when a test tears down.
  Future<void> dispose() async {
    await _controller.close();
    await _recovery.close();
  }

  AuthUser _account(String email) =>
      directory[email.trim().toLowerCase()] ??
      AuthUser(id: 'mock-user', email: email);

  AuthUser _emit(AuthUser? user) {
    _user = user;
    _controller.add(user);
    return user ?? const AuthUser(id: '');
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Stream<bool> passwordRecoveryState() => _recovery.stream;

  @override
  Future<AuthUser> signInWithPassword(String email, String password) async {
    signInCount++;
    if (failSignIn) throw Exception('Invalid login credentials');
    return _emit(_account(email));
  }

  @override
  Future<void> signInWithEmailOtp(String email) async {
    signInCount++;
    if (failSignIn) throw Exception('OTP send failed');
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) async {
    signInCount++;
    if (failSignIn) throw Exception('OTP send failed');
  }

  @override
  Future<AuthUser> verifyEmailOtp(String email, String token) async {
    verifyCount++;
    if (failVerify) throw Exception('Invalid OTP');
    return _emit(_account(email));
  }

  @override
  Future<AuthUser> verifyPhoneOtp(String phone, String token) =>
      verifyEmailOtp('', token);

  @override
  Future<AuthUser> signInWithGoogle() =>
      Future.error(UnsupportedError('Social sign-in is not mocked in E2E.'));

  @override
  Future<AuthUser> signInWithApple() =>
      Future.error(UnsupportedError('Social sign-in is not mocked in E2E.'));

  @override
  Future<void> signOut() async {
    signOutCount++;
    _emit(null);
  }

  @override
  Future<void> signOutAllDevices() => signOut();

  @override
  Future<void> deleteAccount() => signOut();

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> refreshSession() async {}

  @override
  Future<AuthUser> updateProfile({String? fullName, String? avatarUrl}) async {
    final current = _user ?? const AuthUser(id: 'mock-user');
    return _emit(current.copyWith(fullName: fullName, avatarUrl: avatarUrl));
  }
}

/// Customer booking repository over the shared booking store.
///
/// Extends the shared mock (slots, holds, coupons) and adds what E2E needs:
/// call counters, one-shot failures, a slow hold, and server-like state
/// changes (a created booking is stored as `pending`; cancel moves it to
/// `cancelled`, as `cancel_venue_booking` does).
class E2eBookingRepository extends MockBookingRepository {
  E2eBookingRepository(this.store) : super(bookings: store);

  final List<Booking> store;

  int availabilityCalls = 0;
  int acquireCalls = 0;
  int createCalls = 0;
  int cancelCalls = 0;

  /// Fails this many availability reads, then recovers (retry journeys).
  int failAvailabilityTimes = 0;

  /// Keeps the hold request in flight this long (duplicate-submit journeys).
  Duration acquireDelay = Duration.zero;

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) async {
    availabilityCalls++;
    if (failAvailabilityTimes > 0) {
      failAvailabilityTimes--;
      throw Exception('network down');
    }
    return super.availableTimeSlots(venueId: venueId, date: date);
  }

  @override
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  }) async {
    acquireCalls++;
    if (acquireDelay > Duration.zero) await Future<void>.delayed(acquireDelay);
    return super.acquireHold(
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      amount: amount,
      holdMinutes: holdMinutes,
    );
  }

  @override
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
    Map<String, dynamic> metadata = const {},
  }) async {
    createCalls++;
    if (failCreate) throw Exception('create failed');
    final venue = MockVenueRepository.defaultVenues
        .where((v) => v.id == venueId)
        .firstOrNull;
    final slot = MockBookingRepository.defaultSlots
        .where((s) => s.slotId == slotId)
        .firstOrNull;
    final booking = Booking(
      id: 'e2e-bk-$createCalls',
      bookingRef: 'BMS-E2E$createCalls',
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      startTime: slot?.startTime ?? '',
      endTime: slot?.endTime ?? '',
      status: BookingStatus.pending,
      amount: amount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      venueName: venue?.name ?? '',
      venueCity: venue?.city ?? '',
      slotLabel: slot?.label ?? '',
      customerName: metadata['customer_name'] as String? ?? '',
      customerPhone: metadata['customer_phone'] as String? ?? '',
      metadata: metadata,
    );
    store.insert(0, booking);
    createdBooking = booking;
    return booking;
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    cancelCalls++;
    if (failCancel) return super.cancelBooking(bookingId);
    final updated = _updateInStore(
      store,
      bookingId,
      (b) => copyBooking(b, status: BookingStatus.cancelled),
    );
    if (updated == null) throw Exception('Booking not found: $bookingId');
  }
}

/// A per-session view of [E2eBookingRepository], mirroring production.
///
/// Production builds a new `CachingBookingRepository` whenever the signed-in
/// user changes, and that new instance is what makes Riverpod refresh
/// `myBookingsProvider` after an account switch. Returning the same shared
/// instance would not notify dependents, so history would stay stale. This
/// wrapper is created per user and delegates to the one shared store.
class E2eUserBookingRepository implements BookingRepository {
  // Interface members added by the merged branches that this double does
  // not exercise fall through here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  E2eUserBookingRepository(this._shared);

  final E2eBookingRepository _shared;

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) => _shared.availableTimeSlots(venueId: venueId, date: date);

  @override
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  }) => _shared.acquireHold(
    venueId: venueId,
    slotId: slotId,
    bookDate: bookDate,
    amount: amount,
    holdMinutes: holdMinutes,
  );

  @override
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
    Map<String, dynamic> metadata = const {},
  }) => _shared.createBooking(
    hold: hold,
    venueId: venueId,
    slotId: slotId,
    bookDate: bookDate,
    amount: amount,
    taxAmount: taxAmount,
    totalAmount: totalAmount,
    metadata: metadata,
  );

  @override
  Future<Booking> bookingById(String bookingId) =>
      _shared.bookingById(bookingId);

  @override
  Future<List<Booking>> myBookings() => _shared.myBookings();

  @override
  Future<void> cancelBooking(String bookingId) =>
      _shared.cancelBooking(bookingId);

  @override
  Future<Booking> applyCoupon({
    required String bookingId,
    required String code,
  }) => _shared.applyCoupon(bookingId: bookingId, code: code);

  @override
  Future<Booking> removeCoupon(String bookingId) =>
      _shared.removeCoupon(bookingId);
}

/// Payment repository over the shared booking store, following the server
/// contract: `select_pay_at_venue` and a captured online payment both land
/// the booking in `pending_owner_approval`; status reads come from the store.
class E2ePaymentRepository extends MockPaymentRepository {
  E2ePaymentRepository(this.store);

  final List<Booking> store;

  int createOrderCalls = 0;
  int payAtVenueCalls = 0;
  int refundCalls = 0;

  /// Fails this many order creations, then recovers.
  int failCreateOrderTimes = 0;

  /// After this many status reads following a capture, report `confirmed`
  /// (models the owner approving while the customer is still verifying).
  /// Null keeps the booking in `pending_owner_approval`.
  int? approveAfterStatusReads;

  @override
  Future<PaymentOrder> createOrder({required String bookingId}) async {
    createOrderCalls++;
    if (failCreateOrderTimes > 0) {
      failCreateOrderTimes--;
      throw Exception('order creation failed');
    }
    return super.createOrder(bookingId: bookingId);
  }

  @override
  Future<BookingStatus> selectPayAtVenue({required String bookingId}) async {
    payAtVenueCalls++;
    final result = await super.selectPayAtVenue(bookingId: bookingId);
    _updateInStore(
      store,
      bookingId,
      (b) => copyBooking(b, status: result, paymentMethod: 'pay_at_venue'),
    );
    return result;
  }

  /// Webhook stand-in: the provider captured the last order's payment.
  void captureLastOrder() {
    final bookingId = lastOrderBookingId;
    if (bookingId == null) return;
    _updateInStore(
      store,
      bookingId,
      (b) => copyBooking(
        b,
        status: BookingStatus.pendingOwnerApproval,
        paymentMethod: 'razorpay',
      ),
    );
  }

  @override
  Future<BookingStatus> bookingStatus(String bookingId) async {
    await super.bookingStatus(bookingId); // counts reads, honours failStatus
    final approveAfter = approveAfterStatusReads;
    if (approveAfter != null && statusCalls >= approveAfter) {
      _updateInStore(
        store,
        bookingId,
        (b) => b.status == BookingStatus.pendingOwnerApproval
            ? copyBooking(b, status: BookingStatus.confirmed)
            : b,
      );
    }
    final match = store.where((b) => b.id == bookingId).firstOrNull;
    return match?.status ?? statusResult;
  }

  @override
  Future<Refund> requestRefund({
    required String bookingId,
    required double amount,
    String reason = '',
  }) {
    refundCalls++;
    return super.requestRefund(
      bookingId: bookingId,
      amount: amount,
      reason: reason,
    );
  }
}

/// Checkout that plays back a scripted sequence of provider outcomes and
/// reports captures to [onPaid]. No Razorpay SDK or network is involved.
class E2eCheckoutService extends FakeCheckoutService {
  E2eCheckoutService({this.onPaid});

  final void Function()? onPaid;
  final Queue<CheckoutResult> script = Queue<CheckoutResult>();
  int openCalls = 0;

  @override
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
    String? venueName,
    String? bookingRef,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    Map<String, dynamic>? notes,
  }) async {
    openCalls++;
    if (script.isNotEmpty) result = script.removeFirst();
    final outcome = await super.openCheckout(
      orderId: orderId,
      amount: amount,
      currency: currency,
      keyId: keyId,
    );
    if (outcome == CheckoutResult.paid) onPaid?.call();
    return outcome;
  }
}

/// Owner profile lookup: an owner profile exists only for accounts whose
/// backend role is owner/admin. Registration flows are out of E2E scope.
class E2eOwnerRepository implements OwnerRepository {
  // Interface members added by the merged branches that this double does
  // not exercise fall through here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  E2eOwnerRepository(this.auth);

  final AuthRepository auth;

  @override
  Future<Owner?> currentOwner() async {
    final user = auth.currentUser;
    if (user == null || !user.isOwner) return null;
    return Owner(
      id: 'owner-${user.id}',
      userId: user.id,
      email: user.email,
      name: user.fullName,
    );
  }

  Never _unsupported() =>
      throw UnsupportedError('Owner registration is not mocked in E2E.');

  @override
  Future<void> requestOwnerOtp(String email, String name) async =>
      _unsupported();

  @override
  Future<Owner> verifyOwnerOtp({
    required String email,
    required String name,
    required String token,
  }) async => _unsupported();

  @override
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
    String? legalName,
    String? gstin,
    String? pan,
    String? city,
    String? state,
  }) async => _unsupported();

  @override
  Future<Owner> signInWithEmailPassword(String email, String password) async =>
      _unsupported();

  @override
  Future<void> signOut() => auth.signOut();

  @override
  Future<void> deleteOwner() async => _unsupported();
}

/// In-memory operating hours and time slots per venue.
class E2eOwnerAvailabilityRepository implements OwnerAvailabilityRepository {
  // Interface members added by the merged branches that this double does
  // not exercise fall through here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  final Map<String, List<OwnerOperatingHours>> hoursByVenue = {};
  final Map<String, List<OwnerTimeSlot>> slotsByVenue = {};
  int saveSlotCalls = 0;
  int saveHoursCalls = 0;
  var _nextId = 0;

  @override
  Future<List<OwnerOperatingHours>> hours(String venueId) async =>
      List.of(hoursByVenue[venueId] ?? const []);

  @override
  Future<void> saveHours(
    String venueId,
    List<OwnerOperatingHours> values,
  ) async {
    saveHoursCalls++;
    hoursByVenue[venueId] = List.of(values);
  }

  @override
  Future<List<OwnerTimeSlot>> slots(String venueId) async =>
      List.of(slotsByVenue[venueId] ?? const []);

  @override
  Future<OwnerTimeSlot> saveSlot(String venueId, OwnerTimeSlot slot) async {
    saveSlotCalls++;
    final list = slotsByVenue.putIfAbsent(venueId, () => []);
    final saved = OwnerTimeSlot(
      id: slot.id ?? 'e2e-slot-${++_nextId}',
      label: slot.label,
      startTime: slot.startTime,
      endTime: slot.endTime,
      priceAmount: slot.priceAmount,
      isActive: slot.isActive,
    );
    final index = list.indexWhere((s) => s.id == saved.id);
    if (index < 0) {
      list.add(saved);
    } else {
      list[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> setSlotActive(String venueId, String slotId, bool active) async {
    final list = slotsByVenue[venueId] ?? [];
    final index = list.indexWhere((s) => s.id == slotId);
    if (index < 0) throw StateError('Slot not found: $slotId');
    final s = list[index];
    list[index] = OwnerTimeSlot(
      id: s.id,
      label: s.label,
      startTime: s.startTime,
      endTime: s.endTime,
      priceAmount: s.priceAmount,
      isActive: active,
    );
  }

  @override
  Future<void> deleteSlot(String venueId, String slotId) async {
    slotsByVenue[venueId]?.removeWhere((s) => s.id == slotId);
  }
}
