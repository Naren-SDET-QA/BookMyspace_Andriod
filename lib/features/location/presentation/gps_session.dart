import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gps_location.dart';
import 'location_providers.dart';

class GpsSessionState {
  const GpsSessionState({
    this.phase = GpsPhase.idle,
    this.fix,
    this.message,
  });

  final GpsPhase phase;
  final GpsFix? fix;
  final String? message;

  bool get isBusy => phase.isBusy;

  bool get isFailure => phase.isFailure;

  bool get isSuccess => phase == GpsPhase.success && fix != null;

  GpsSessionState copyWith({
    GpsPhase? phase,
    GpsFix? fix,
    String? message,
    bool clearFix = false,
    bool clearMessage = false,
  }) {
    return GpsSessionState(
      phase: phase ?? this.phase,
      fix: clearFix ? null : (fix ?? this.fix),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// GPS session owned by explicit user actions.
///
/// Never started from `build()`, `initState()`, provider construction, or
/// router initialization. Duplicate taps are ignored while busy. Every
/// loading phase has a timer-backed exit.
class GpsSessionNotifier extends StateNotifier<GpsSessionState> {
  GpsSessionNotifier(
    this._service, {
    this.overallTimeout = const Duration(seconds: 25),
  }) : super(const GpsSessionState());

  final GpsLocationService _service;
  final Duration overallTimeout;

  int _generation = 0;
  Timer? _overallTimer;

  Future<void> requestCurrentLocation() async {
    if (state.isBusy) return;
    final gen = ++_generation;
    state = const GpsSessionState(phase: GpsPhase.checkingService);
    _armOverallTimer(gen);

    try {
      final result = await _service.requestCurrentLocation(
        onPhase: (phase) {
          if (gen != _generation) return;
          if (!phase.isBusy) return;
          state = state.copyWith(phase: phase, clearMessage: true);
        },
      );
      if (gen != _generation) return;
      _cancelTimer();
      state = GpsSessionState(
        phase: result.phase,
        fix: result.fix,
        message: result.message ?? _defaultMessage(result.phase),
      );
    } catch (error) {
      if (gen != _generation) return;
      _cancelTimer();
      state = GpsSessionState(
        phase: GpsPhase.error,
        message: error.toString(),
      );
    }
  }

  Future<void> openSettings() async {
    if (state.phase == GpsPhase.serviceDisabled) {
      await _service.openLocationSettings();
      return;
    }
    await _service.openAppSettings();
  }

  void retry() {
    if (state.isBusy) return;
    state = const GpsSessionState();
    requestCurrentLocation();
  }

  /// Drop an in-flight request so a spinner cannot outlive the UI.
  void cancelIfBusy() {
    if (!state.isBusy) return;
    _generation++;
    _cancelTimer();
    state = const GpsSessionState();
  }

  void reset() {
    _generation++;
    _cancelTimer();
    state = const GpsSessionState();
  }

  void _armOverallTimer(int gen) {
    _cancelTimer();
    _overallTimer = Timer(overallTimeout, () {
      if (gen != _generation) return;
      if (!state.isBusy) return;
      if (state.phase == GpsPhase.requestingPermission) {
        // User may still be interacting with the OS permission dialog.
        // Re-arm a shorter exit so this cannot hang forever either.
        _overallTimer = Timer(const Duration(seconds: 20), () {
          if (gen != _generation) return;
          if (!state.isBusy) return;
          _failTimeout(gen);
        });
        return;
      }
      _failTimeout(gen);
    });
  }

  void _failTimeout(int gen) {
    if (gen != _generation) return;
    _generation++;
    _cancelTimer();
    state = const GpsSessionState(
      phase: GpsPhase.timeout,
      message: 'Location request timed out',
    );
  }

  void _cancelTimer() {
    _overallTimer?.cancel();
    _overallTimer = null;
  }

  static String _defaultMessage(GpsPhase phase) {
    return switch (phase) {
      GpsPhase.permissionDenied => 'Location permission is off',
      GpsPhase.serviceDisabled => 'Location Services are off',
      GpsPhase.timeout => 'Location request timed out',
      GpsPhase.error => "Couldn't get your location",
      _ => '',
    };
  }

  @override
  void dispose() {
    _generation++;
    _cancelTimer();
    super.dispose();
  }
}

final gpsSessionProvider =
    StateNotifierProvider<GpsSessionNotifier, GpsSessionState>((ref) {
  return GpsSessionNotifier(ref.watch(gpsLocationServiceProvider));
});
