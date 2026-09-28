import 'package:bookmyspace/features/admin/domain/platform_status.dart';
import 'package:bookmyspace/features/admin/presentation/widgets/platform_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses metadata and round-trips', () {
    final s = PlatformStatus.fromMetadata({
      'maintenance_enabled': 'true',
      'maintenance_message': '',
      'broadcast_enabled': true,
      'broadcast_message': 'Diwali offers live',
      'broadcast_severity': 'bogus',
    });
    expect(s.maintenanceEnabled, isTrue);
    expect(s.maintenanceText, contains('under maintenance'));
    expect(s.showsBroadcast, isTrue);
    expect(s.broadcastSeverity, 'info');
    expect(PlatformStatus.fromMetadata(s.toMetadata()).broadcastMessage,
        'Diwali offers live');
  });

  test('empty broadcast message is not shown', () {
    const s = PlatformStatus(broadcastEnabled: true, broadcastMessage: '  ');
    expect(s.showsBroadcast, isFalse);
  });

  testWidgets('banner shows maintenance and broadcast text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlatformStatusBanner(
            status: PlatformStatus(
              maintenanceEnabled: true,
              maintenanceMessage: 'Back at 6 PM',
              broadcastEnabled: true,
              broadcastMessage: 'New payment options',
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Back at 6 PM'), findsOneWidget);
    expect(find.textContaining('New payment options'), findsOneWidget);
  });
}
