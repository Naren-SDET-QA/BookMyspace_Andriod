/// Circuit breaker for repeated dependency failures.
///
/// Open circuits fail fast. They never invent a successful result.
enum CircuitState { closed, open, halfOpen }

class CircuitOpenException implements Exception {
  const CircuitOpenException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int failureThreshold;
  final Duration resetTimeout;
  final DateTime Function() _clock;

  CircuitState _state = CircuitState.closed;
  int _failures = 0;
  DateTime? _openedAt;

  CircuitState get state {
    _maybeHalfOpen();
    return _state;
  }

  Future<T> execute<T>(Future<T> Function() operation) async {
    _maybeHalfOpen();
    if (_state == CircuitState.open) {
      throw const CircuitOpenException(
        'This service is temporarily unavailable. Please try again shortly.',
      );
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure();
      rethrow;
    }
  }

  void _maybeHalfOpen() {
    if (_state != CircuitState.open || _openedAt == null) return;
    if (_clock().difference(_openedAt!) >= resetTimeout) {
      _state = CircuitState.halfOpen;
    }
  }

  void _onSuccess() {
    _failures = 0;
    _state = CircuitState.closed;
    _openedAt = null;
  }

  void _onFailure() {
    if (_state == CircuitState.halfOpen) {
      _trip();
      return;
    }
    _failures += 1;
    if (_failures >= failureThreshold) {
      _trip();
    }
  }

  void _trip() {
    _state = CircuitState.open;
    _openedAt = _clock();
  }
}
