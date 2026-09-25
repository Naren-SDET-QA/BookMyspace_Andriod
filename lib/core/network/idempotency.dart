import 'dart:math';

/// Client-generated idempotency key for writes that the server can dedupe.
///
/// Keys identify an attempt. They never imply that the attempt succeeded.
class IdempotencyKey {
  IdempotencyKey._();

  static final Random _random = Random();

  static String create(String operation) {
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final nonce = _random.nextInt(1 << 32).toRadixString(16);
    return '$operation-$stamp-$nonce';
  }
}
