import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/owner/presentation/screens/registration_field_configuration_screen.dart';
import 'package:bookmyspace/features/registration/domain/module_registration.dart';
import 'package:bookmyspace/features/registration/domain/user_registration_config_models.dart';
import 'package:bookmyspace/features/registration/presentation/providers/registration_fields_provider.dart';
import 'package:bookmyspace/features/registration/presentation/dynamic_registration_form.dart';
import 'package:bookmyspace/features/registration/presentation/unified_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: ThemeData.dark(), home: child),
  );
}

void main() {
  group('Unified Registration & KYC Schema Tests', () {
    testWidgets(
      'registration entry offers real flows without unsaved KYC or fabricated compliance badges',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _buildTestApp(const UnifiedRegistrationScreen()),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(AppLocalizations(const Locale('en')).unifiedRegistration),
          findsOneWidget,
        );
        for (final module in unifiedRegistrationModules) {
          expect(find.text(module.title), findsOneWidget);
        }
        expect(find.byType(TextField), findsNothing);
        expect(find.textContaining('UIDAI Compliant'), findsNothing);
      },
    );

    testWidgets(
      'the actual dynamic registration form validates required identity fields from schema',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        Map<String, dynamic> values = {};
        await tester.pumpWidget(
          _buildTestApp(
            Scaffold(
              body: Form(
                key: formKey,
                child: DynamicRegistrationForm(
                  fields: const [
                    ModuleFormField(
                      key: 'full_name',
                      label: 'Full name',
                      type: ModuleFieldType.text,
                      required: true,
                    ),
                    ModuleFormField(
                      key: 'identity_reference',
                      label: 'Identity reference',
                      type: ModuleFieldType.idProof,
                      required: true,
                    ),
                    ModuleFormField(
                      key: 'hidden',
                      label: 'Disabled field',
                      type: ModuleFieldType.text,
                      enabled: false,
                    ),
                  ],
                  onChanged: (next) => values = Map<String, dynamic>.from(next),
                ),
              ),
            ),
          ),
        );
        expect(formKey.currentState!.validate(), isFalse);
        await tester.pump();
        expect(find.text('Required'), findsNWidgets(2));
        expect(find.text('Disabled field'), findsNothing);
        await tester.enterText(
          find.byType(TextFormField).first,
          'Test customer',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'fixture-document-reference',
        );
        expect(formKey.currentState!.validate(), isTrue);
        expect(values, {
          'full_name': 'Test customer',
          'identity_reference': 'fixture-document-reference',
        });
      },
    );

    testWidgets(
      'RegistrationFieldConfigurationScreen renders dynamic schema rules, toggles and cards',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        await tester.pumpWidget(
          _buildTestApp(const RegistrationFieldConfigurationScreen()),
        );
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

        expect(
          find.textContaining('Mobile / WhatsApp Number'),
          findsAtLeastNWidgets(1),
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(find.textContaining('Email Address'), findsAtLeastNWidgets(1));
        expect(find.text('Add Field'), findsOneWidget);
        expect(find.text('AI Help'), findsOneWidget);
      },
    );

    test(
      'RegistrationFieldsNotifier toggles and schema operations work accurately',
      () {
        final notifier = RegistrationFieldsNotifier();
        expect(notifier.state.length, 17);

        // Test toggle required
        final dobBefore = notifier.state
            .firstWhere((f) => f.key == 'dob')
            .required;
        notifier.toggleFieldRequired('dob');
        final dobAfter = notifier.state
            .firstWhere((f) => f.key == 'dob')
            .required;
        expect(dobAfter, !dobBefore);

        // Test JSON export & import
        final jsonStr = notifier.exportToJson();
        expect(jsonStr.contains('full_name'), isTrue);
        expect(notifier.importFromJson(jsonStr), isTrue);

        // Test reset
        notifier.resetToDefaults();
        expect(notifier.state.length, 17);
      },
    );
  });
}
