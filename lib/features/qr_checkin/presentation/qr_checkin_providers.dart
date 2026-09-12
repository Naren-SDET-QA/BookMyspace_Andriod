import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.isTorchOn = false,
    this.isFrontCamera = false,
  });

  final bool isLoading;
  final CheckInResult? result;
  final bool isTorchOn;
  final bool isFrontCamera;

  QrCheckInState copyWith({
    bool? isLoading,
    CheckInResult? result,
    bool? isTorchOn,
    bool? isFrontCamera,
    bool clearResult = false,
  }) {
    return QrCheckInState(
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      isTorchOn: isTorchOn ?? this.isTorchOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }
}

class QrCheckInNotifier extends StateNotifier<QrCheckInState> {
  QrCheckInNotifier(this.ref) : super(const QrCheckInState());

  final Ref ref;

  void toggleTorch() {
    state = state.copyWith(isTorchOn: !state.isTorchOn);
  }

  void toggleCamera() {
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

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
    } catch (e) {
      final res = CheckInResult(
        success: false,
        message:
            'Invalid QR code or booking reference. No active booking found.',
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
