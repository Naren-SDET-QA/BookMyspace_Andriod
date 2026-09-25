import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../booking/domain/booking.dart';
import '../../booking/presentation/booking_providers.dart';
import '../domain/qr_check_in.dart';

/// Provider for confirmed and completed bookings eligible for QR check-in passes.
final qrPassBookingsProvider = Provider<List<Booking>>((ref) {
  final bookingsAsync = ref.watch(myBookingsProvider);
  return bookingsAsync.maybeWhen(
    data: (bookings) => bookings
        .where((b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.completed)
        .toList(),
    orElse: () => const [],
  );
});

class QrCheckInState {
  const QrCheckInState({
    this.isLoading = false,
    this.result,
  });

  final bool isLoading;
  final CheckInResult? result;

  QrCheckInState copyWith({
    bool? isLoading,
    CheckInResult? result,
    bool clearResult = false,
  }) {
    return QrCheckInState(
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

class QrCheckInNotifier extends StateNotifier<QrCheckInState> {
  QrCheckInNotifier(this.ref) : super(const QrCheckInState());

  final Ref ref;

  void dismissResult() {
    state = state.copyWith(clearResult: true);
  }

  Future<CheckInResult> checkInWithCode(String codeOrPayload) async {
    final clean = codeOrPayload.trim();
    if (clean.isEmpty) {
      final res = CheckInResult(
        success: false,
        message: 'Please enter a valid Booking Ref or QR Code token.',
      );
      state = state.copyWith(result: res);
      return res;
    }

    state = state.copyWith(isLoading: true, clearResult: true);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final updated = await repo.checkInBooking(clean);

      // Refresh bookings so all screens reflect completed status
      ref.invalidate(myBookingsProvider);

      final venueName =
          updated.venueName.isNotEmpty ? updated.venueName : 'the venue';
      final res = CheckInResult(
        success: true,
        message: 'Check-in verified! Welcome to $venueName.',
        booking: updated,
        checkedInAt: DateTime.now(),
      );

      state = state.copyWith(isLoading: false, result: res);
      return res;
    } on AppException catch (e) {
      // The server already explained what went wrong. Replacing that with a
      // generic "invalid code" message is how a missing backend contract
      // previously reached guests as their own input error.
      final res = CheckInResult(success: false, message: e.message);
      state = state.copyWith(isLoading: false, result: res);
      return res;
    } catch (e) {
      final res = CheckInResult(
        success: false,
        message: 'Check-in could not be completed. Please try again.',
      );
      state = state.copyWith(isLoading: false, result: res);
      return res;
    }
  }
}

final qrCheckInNotifierProvider =
    StateNotifierProvider.autoDispose<QrCheckInNotifier, QrCheckInState>((ref) {
  return QrCheckInNotifier(ref);
});
