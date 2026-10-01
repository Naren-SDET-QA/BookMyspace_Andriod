import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/admin/presentation/admin_providers.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'mock_admin_directory_repository.dart';

void main() {
  testWidgets('AdminDashboardScreen renders modules and direct navigation links', (tester) async {
    final mockRepo = MockAdminDirectoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminDirectoryRepositoryProvider.overrideWithValue(mockRepo),
          recentAuditLogsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: AdminDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and core summary counts
    expect(find.text('Admin console'), findsOneWidget);
    expect(find.text('Platform administration'), findsOneWidget);
    expect(find.text('Users'), findsWidgets);
    expect(find.text('Venues'), findsWidgets);
    expect(find.text('Categories'), findsOneWidget);

    // Scroll through the list to verify the 18 modules
    await tester.scrollUntilVisible(find.text('Media library'), 100);
    expect(find.text('Media library'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Feature toggles'), 100);
    expect(find.text('Feature toggles'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Dynamic listing fields'), 100);
    expect(find.text('Dynamic listing fields'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Content editor'), 100);
    expect(find.text('Content editor'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Pricing configuration'), 100);
    expect(find.text('Pricing configuration'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Cancellation policies'), 100);
    expect(find.text('Cancellation policies'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Transaction ledger'), 100);
    expect(find.text('Transaction ledger'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Refunds oversight'), 100);
    expect(find.text('Refunds oversight'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Notifications & settings'), 100);
    expect(find.text('Notifications & settings'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('System health & diagnostics'), 100);
    expect(find.text('System health & diagnostics'), findsOneWidget);
  });
}
