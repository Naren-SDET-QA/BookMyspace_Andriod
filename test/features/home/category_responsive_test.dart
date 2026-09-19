import 'package:bookmyspace/features/home/presentation/widgets/category_glass_matrix.dart';
import 'package:bookmyspace/features/home/presentation/home_category_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapScrollable(Widget child, double width) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: ListView(
          children: [child],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('category panel renders hero title and subtitle', (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          pageController: PageController(viewportFraction: 0.72),
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore Verified Spaces'), findsOneWidget);
    expect(find.textContaining('Five master categories'), findsOneWidget);
    // Title appears in both the master carousel card and the section heading
    expect(find.text('Function Halls & Celebrations'), findsWidgets);
  });

  testWidgets('category panel shows function halls grid on mobile (390px)',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          pageController: PageController(viewportFraction: 0.72),
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    // Function halls should show the matrix grid (2 columns on mobile)
    expect(find.byKey(const Key('function-halls-matrix')), findsOneWidget);
    expect(find.text('Marriage Halls'), findsOneWidget);
    expect(find.text('Banquet Halls'), findsOneWidget);
    expect(find.text('Convention Halls'), findsOneWidget);
  });

  testWidgets('category panel shows grid on tablet (768px)', (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          pageController: PageController(viewportFraction: 0.55),
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
        ),
        768,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('function-halls-matrix')), findsOneWidget);
    expect(find.text('Marriage Halls'), findsOneWidget);
  });

  testWidgets('category panel shows grid on desktop (1440px)', (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          pageController: PageController(viewportFraction: 0.55),
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
        ),
        1440,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('function-halls-matrix')), findsOneWidget);
    expect(find.text('Marriage Halls'), findsOneWidget);
    expect(find.text('Banquet Halls'), findsOneWidget);
  });

  testWidgets('category panel handles narrow mobile (320px) without overflow',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          pageController: PageController(viewportFraction: 0.72),
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
        ),
        320,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore Verified Spaces'), findsOneWidget);
    expect(find.byKey(const Key('function-halls-matrix')), findsOneWidget);
  });

  testWidgets('non-function-halls section shows sub-sections', (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.sportsTurfs,
          pageController: PageController(viewportFraction: 0.72),
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sports & Recreation'), findsWidgets);
    expect(find.text('Box Cricket & Turf'), findsOneWidget);
    expect(find.text('Gym & Fitness'), findsOneWidget);
  });

  testWidgets('master carousel shows first section', (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          pageController: PageController(viewportFraction: 0.72),
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    // First section is visible
    expect(find.byKey(const Key('master-function_halls')), findsOneWidget);
    expect(find.byKey(const Key('master-sports_turfs')), findsOneWidget);
  });

  testWidgets('no overflow errors at tested breakpoints', (tester) async {
    for (final width in [320.0, 375.0, 390.0, 430.0, 768.0, 1024.0, 1440.0]) {
      await tester.pumpWidget(
        _wrapScrollable(
          CategoryDiscoveryPanel(
            sections: MainHomeSection.discoveryOrder,
            selected: MainHomeSection.functionHalls,
            pageController: PageController(viewportFraction: 0.72),
            categories: const [],
            venues: const [],
            onMasterChanged: (_) {},
            onMasterExplore: (_) {},
            onSubSectionTap: (_, __) {},
          ),
          width,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'No overflow at ${width.toInt()}px');
    }
  });
}
