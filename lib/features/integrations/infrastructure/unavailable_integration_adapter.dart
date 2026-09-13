import '../domain/integration.dart';
import '../domain/integration_adapter.dart';

/// Honest adapter used when a provider has not been configured or authenticated.
/// It never pretends to execute an external operation.
class UnavailableIntegrationAdapter implements IntegrationAdapter {
  UnavailableIntegrationAdapter({
    required this.id,
    required this.name,
    required this.category,
    required this.provider,
    required this.reason,
    this.health = IntegrationHealth.notConfigured,
  });

  final String id;
  final String name;
  final String category;
  final String provider;
  final String reason;
  final IntegrationHealth health;

  @override
  IntegrationInfo get info => IntegrationInfo(
        id: id,
        name: name,
        category: category,
        provider: provider,
        health: health,
        detail: reason,
      );

  @override
  Future<void> configure(Map<String, Object?> configuration) async {
    throw StateError('$name is not configured.');
  }

  @override
  Future<void> connect() async {
    throw StateError('$name is not configured.');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<IntegrationHealth> healthCheck() async => health;

  @override
  Future<Object?> execute(
    String operation, {
    Map<String, Object?> parameters = const {},
  }) async {
    throw StateError(
        '$name is not configured; operation "$operation" was not run.');
  }

  @override
  IntegrationFailure handleError(Object error) => IntegrationFailure(
        message: reason,
        retryable: false,
      );
}
