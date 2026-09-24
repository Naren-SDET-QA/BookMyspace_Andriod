import 'package:flutter/widgets.dart';

import 'support/mock_backend.dart';

/// Web build target for Playwright mock mode:
/// `flutter build web -t integration_test/web_mock_main.dart`.
///
/// The scenario comes from the page URL, e.g. `/?scenario=signedIn#/home`.
void main() {
  final scenario = MockScenario.parse(Uri.base.queryParameters['scenario']);
  runApp(buildMockApp(MockBackend.forScenario(scenario)));
}
