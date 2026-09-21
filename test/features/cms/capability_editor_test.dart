import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/cms/domain/facility_capabilities.dart';
import 'package:bookmyspace/features/cms/presentation/widgets/capability_editor.dart';
import 'package:bookmyspace/features/cms/presentation/widgets/capability_render.dart';

Widget _wrapInApp(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  group('CapabilityEditor', () {
    testWidgets('keeps the complete editor reachable in a short viewport',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityEditor(
            capabilities: const FacilityCapabilities(),
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.byType(Scrollable), findsWidgets);
      await tester.scrollUntilVisible(find.byType(SwitchListTile), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.getRect(find.byType(SwitchListTile)).bottom,
          lessThanOrEqualTo(600));
    });

    testWidgets('renders all fields', (tester) async {
      await tester.pumpWidget(_wrapInApp(
        CapabilityEditor(
          capabilities: const FacilityCapabilities(),
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Capabilities'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('Seating Options'), findsOneWidget);
      expect(find.text('Amenities'), findsOneWidget);
      expect(find.text('Interaction Mode'), findsOneWidget);
      expect(find.text('Approval Required'), findsOneWidget);
    });

    testWidgets('capacity field accepts valid input', (tester) async {
      FacilityCapabilities? result;
      await tester.pumpWidget(_wrapInApp(
        CapabilityEditor(
          capabilities: const FacilityCapabilities(),
          onChanged: (caps) => result = caps,
        ),
      ));

      await tester.enterText(find.byType(TextFormField).first, '50');
      await tester.pumpAndSettle();
      expect(result?.capacity, 50);
    });

    testWidgets('seating chips toggle correctly', (tester) async {
      FacilityCapabilities? result;
      await tester.pumpWidget(_wrapInApp(
        CapabilityEditor(
          capabilities: const FacilityCapabilities(),
          onChanged: (caps) => result = caps,
        ),
      ));

      await tester.tap(find.byType(FilterChip).first);
      await tester.pumpAndSettle();
      expect(result?.seating, isNotNull);
      expect(result?.seating, isNotEmpty);
    });

    testWidgets('interaction mode dropdown works', (tester) async {
      FacilityCapabilities? result;
      await tester.pumpWidget(_wrapInApp(
        CapabilityEditor(
          capabilities: const FacilityCapabilities(),
          onChanged: (caps) => result = caps,
        ),
      ));

      await tester.tap(find.byType(DropdownButtonFormField<InteractionMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookable online').last);
      await tester.pumpAndSettle();
      expect(result?.interactionMode, InteractionMode.bookable);
    });

    testWidgets('approval switch toggles', (tester) async {
      FacilityCapabilities? result;
      await tester.pumpWidget(_wrapInApp(
        CapabilityEditor(
          capabilities: const FacilityCapabilities(),
          onChanged: (caps) => result = caps,
        ),
      ));

      final switchTile = find.byType(SwitchListTile);
      await tester.ensureVisible(switchTile);
      await tester.pumpAndSettle();
      await tester.tap(switchTile, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(result?.approvalRequired, true);
    });

    testWidgets('readOnly mode disables fields', (tester) async {
      await tester.pumpWidget(_wrapInApp(
        CapabilityEditor(
          capabilities: const FacilityCapabilities(),
          onChanged: (_) {},
          readOnly: true,
        ),
      ));

      final capacityField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(TextField),
        ),
      );
      expect(capacityField.readOnly, true);
    });

    testWidgets('respects constraints on capacity', (tester) async {
      await tester.pumpWidget(_wrapInApp(
        CapabilityEditor(
          capabilities: const FacilityCapabilities(),
          onChanged: (_) {},
          constraints: const CapabilityConstraints(
            capacity: IntConstraint(min: 10, max: 100),
          ),
        ),
      ));

      expect(find.textContaining('Min:'), findsOneWidget);
      expect(find.textContaining('Max:'), findsOneWidget);
    });
  });

  group('CapabilityRender', () {
    testWidgets('renders nothing for empty capabilities', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityRender(
            capabilities: const FacilityCapabilities(),
          ),
        ),
      ));

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders capacity', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityRender(
            capabilities: const FacilityCapabilities(capacity: 100),
          ),
        ),
      ));

      expect(find.text('100 people'), findsOneWidget);
    });

    testWidgets('renders seating', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityRender(
            capabilities: const FacilityCapabilities(
              seating: ['theater', 'round_table'],
            ),
          ),
        ),
      ));

      expect(find.textContaining('theater'), findsOneWidget);
      expect(find.textContaining('round table'), findsOneWidget);
    });

    testWidgets('renders interaction mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityRender(
            capabilities: const FacilityCapabilities(
              interactionMode: InteractionMode.bookable,
            ),
          ),
        ),
      ));

      expect(find.text('Bookable online'), findsOneWidget);
    });

    testWidgets('renders approval required', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityRender(
            capabilities: const FacilityCapabilities(
              approvalRequired: true,
            ),
          ),
        ),
      ));

      expect(find.text('Required before confirmation'), findsOneWidget);
    });

    testWidgets('compact mode renders chips', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityRender(
            capabilities: const FacilityCapabilities(
              capacity: 50,
              interactionMode: InteractionMode.bookable,
            ),
            compact: true,
          ),
        ),
      ));

      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('compact mode renders nothing for empty', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CapabilityRender(
            capabilities: const FacilityCapabilities(),
            compact: true,
          ),
        ),
      ));

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
