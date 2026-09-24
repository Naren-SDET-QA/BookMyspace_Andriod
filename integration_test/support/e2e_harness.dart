import 'package:bookmyspace/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/base_robot.dart';
import 'e2e_env.dart';
import 'mock_backend.dart';

/// Registers one E2E flow with its tags.
///
/// Tags go to `package:test` (`--tags smoke`) and are also appended to the
/// test name as `@smoke @critical ...` so the same grep works everywhere.
/// When `E2E_TAGS` is set, flows without a matching tag are not registered
/// (they are filtered out, not reported as skipped).
void e2eFlow(
  String description,
  Set<String> tags,
  Future<void> Function(WidgetTester tester) body,
) {
  final requested = E2eEnv.requestedTags;
  if (requested.isNotEmpty && requested.intersection(tags).isEmpty) return;
  final label = tags.map((tag) => '@$tag').join(' ');
  testWidgets('$description $label', body, tags: tags.toList());
}

/// Pumps the real router/screens against a fresh [MockBackend].
Future<MockBackend> pumpMockApp(
  WidgetTester tester,
  MockScenario scenario, {
  String initialLocation = AppRoutes.shell,
}) async {
  final backend = MockBackend.forScenario(scenario);
  addTearDown(backend.auth.dispose);
  await tester.pumpWidget(
    buildMockApp(backend, initialLocation: initialLocation),
  );
  await BaseRobot(tester).settle();
  return backend;
}
