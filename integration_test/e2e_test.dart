import 'package:integration_test/integration_test.dart';

import 'flows/business_flows.dart';
import 'flows/live_smoke_flows.dart';
import 'flows/smoke_flows.dart';
import 'support/e2e_env.dart';

/// Single entry point for Android, iOS and web (`flutter test` / `flutter
/// drive`). Filter with `--dart-define=E2E_TAGS=smoke` or `--tags smoke`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  switch (E2eEnv.mode) {
    case E2eMode.mock:
      registerMockSmokeFlows();
      registerMockBusinessFlows();
    case E2eMode.live:
      // DEV only: refuses any other environment or Supabase project, and
      // missing credentials, before anything runs. See docs/E2E_TESTING.md.
      final problem = E2eEnv.liveModeProblem();
      if (problem != null) {
        throw StateError('E2E_MODE=live refused: $problem');
      }
      registerLiveSmokeFlows();
  }
}
