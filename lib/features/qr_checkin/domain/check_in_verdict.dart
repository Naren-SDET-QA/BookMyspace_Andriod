import 'qr_check_in.dart';

/// How a server check-in result is shown to the host.
///
/// The server message is the source. This only groups it for the scanner
/// label, color, haptic, and sound.
enum CheckInVerdict {
  valid('Valid'),
  alreadyCheckedIn('Already checked in'),
  invalid('Invalid'),
  expired('Expired'),
  unavailable('Unavailable');

  const CheckInVerdict(this.label);

  final String label;
}

CheckInVerdict classifyCheckIn(CheckInResult result) {
  if (result.success) return CheckInVerdict.valid;
  final message = result.message.toLowerCase();
  if (message.contains('already') ||
      message.contains('checked in') ||
      message.contains('checked-in')) {
    return CheckInVerdict.alreadyCheckedIn;
  }
  if (message.contains('expired') || message.contains('expiry')) {
    return CheckInVerdict.expired;
  }
  if (message.contains('could not') ||
      message.contains('try again') ||
      message.contains('unavailable') ||
      message.contains('network')) {
    return CheckInVerdict.unavailable;
  }
  return CheckInVerdict.invalid;
}
