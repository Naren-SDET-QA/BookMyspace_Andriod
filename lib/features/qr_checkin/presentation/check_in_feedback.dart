import 'package:flutter/services.dart';

import '../domain/check_in_verdict.dart';

/// Haptic and sound feedback for a scan. Web ignores haptics; failures stay
/// silent so a missing vibrator never blocks the result dialog.
Future<void> acknowledgeCheckIn(CheckInVerdict verdict) async {
  try {
    switch (verdict) {
      case CheckInVerdict.valid:
        await HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.click);
      case CheckInVerdict.alreadyCheckedIn:
        await HapticFeedback.lightImpact();
      case CheckInVerdict.invalid || CheckInVerdict.expired:
        await HapticFeedback.heavyImpact();
        await SystemSound.play(SystemSoundType.alert);
      case CheckInVerdict.unavailable:
        await HapticFeedback.selectionClick();
    }
  } catch (_) {}
}
