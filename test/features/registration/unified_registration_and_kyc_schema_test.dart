import 'package:bookmyspace/features/owner/presentation/screens/registration_field_configuration_screen.dart';
import 'package:bookmyspace/features/registration/domain/user_registration_config_models.dart';
import 'package:bookmyspace/features/registration/presentation/providers/registration_fields_provider.dart';
import 'package:bookmyspace/features/registration/presentation/unified_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: child,
    ),
  );
}

void main() {
  group('Unified Registration & KYC Schema Tests', () {
    testWidgets('UnifiedRegistrationScreen renders all sections, fields and KYC badges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      await tester.pumpWidget(_buildTestApp(const UnifiedRegistrationScreen()));
      await tester.pumpAndSettle();

      // Top bar
      expect(find.text('Unified Registration'), findsOneWidget);
      expect(find.text('Single configured profile for all modules'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Module selector card
      expect(find.text('Select Registration Type'), findsOneWidget);
      expect(find.text('Customer / Member'), findsOneWidget);
      expect(find.text('Venue & Space Owner'), findsOneWidget);

      // Personal Information
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Profile Photo / Selfie'), findsOneWidget);

      // UIDAI KYC Badge & Address
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Government ID & KYC'), findsOneWidget);
      expect(find.textContaining('UIDAI Compliant'), findsOneWidget);

      expect(find.text('Address & Location'), findsOneWidget);
      expect(find.text('Country, State, District & City Hierarchy *'), findsOneWidget);
      expect(find.textContaining('YSR Kadapa'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Postal PIN Code'), findsOneWidget);

      // AI Help FAB
      expect(find.text('AI Help'), findsOneWidget);
    });

    testWidgets('RegistrationFieldConfigurationScreen renders dynamic schema rules, toggles and cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      await tester.pumpWidget(_buildTestApp(const RegistrationFieldConfigurationScreen()));
      await tester.pumpAndSettle();

      // Top bar
      expect(find.text('Registration Schema & KYC'), findsOneWidget);
      expect(find.text('JSON-Configurable Field Rules'), findsOneWidget);
      expect(find.byIcon(Icons.data_object), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      expect(find.byIcon(Icons.restart_alt), findsOneWidget);

      // Dynamic JSON Configuration System card
      expect(find.text('Dynamic JSON Configuration System'), findsOneWidget);
      expect(find.text('QUICK MANDATORY TOGGLES'), findsOneWidget);
      expect(find.text('Identity Proof'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Company Name'), findsOneWidget);

      // Search bar & status row
      expect(find.textContaining('Search fields'), findsOneWidget);
      expect(find.textContaining('+ Live Form Preview'), findsOneWidget);

      // Field cards with badges
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mobile / WhatsApp Number'), findsAtLeastNWidgets(1));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Email Address'), findsAtLeastNWidgets(1));
      expect(find.text('Add Field'), findsOneWidget);
      expect(find.text('AI Help'), findsOneWidget);
    });

    test('RegistrationFieldsNotifier toggles and schema operations work accurately', () {
      final notifier = RegistrationFieldsNotifier();
      expect(notifier.state.length, 17);

      // Test toggle required
      final dobBefore = notifier.state.firstWhere((f) => f.key == 'dob').required;
      notifier.toggleFieldRequired('dob');
      final dobAfter = notifier.state.firstWhere((f) => f.key == 'dob').required;
      expect(dobAfter, !dobBefore);

      // Test JSON export & import
      final jsonStr = notifier.exportToJson();
      expect(jsonStr.contains('full_name'), isTrue);
      expect(notifier.importFromJson(jsonStr), isTrue);

      // Test reset
      notifier.resetToDefaults();
      expect(notifier.state.length, 17);
    });
  });
}
