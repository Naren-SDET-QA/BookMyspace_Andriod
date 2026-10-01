import 'integration.dart';

/// Safe boundary for integrations. Implementations own credentials and
/// provider-specific details; callers only receive status and mapped errors.
abstract interface class IntegrationAdapter {
  IntegrationInfo get info;

  Future<void> configure(Map<String, Object?> configuration);

  Future<void> connect();

  Future<void> disconnect();

  Future<IntegrationHealth> healthCheck();

  Future<Object?> execute(
    String operation, {
    Map<String, Object?> parameters = const {},
  });

  IntegrationFailure handleError(Object error);
}

class IntegrationFailure {
  const IntegrationFailure({
    required this.message,
    this.retryable = false,
  });

  final String message;
  final bool retryable;
}
