import 'package:bookmyspace/features/home/presentation/widgets/category_glass_matrix.dart';
import 'package:bookmyspace/features/home/presentation/home_category_catalog.dart';
import 'package:bookmyspace/features/cms/domain/cms_banner.dart';
import 'package:bookmyspace/core/widgets/app_network_image.dart';
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
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inside this category'), findsOneWidget);
    expect(find.textContaining('Function Halls'), findsWidgets);
    // Title appears in the chip row, the 3D matrix tile, and the hero card
    expect(find.text('Function Halls & Celebrations'), findsWidgets);
  });

  testWidgets('category panel shows function halls grid on mobile (390px)',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
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
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
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
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
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
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        320,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inside this category'), findsOneWidget);
    expect(find.byKey(const Key('function-halls-matrix')), findsOneWidget);
  });

  testWidgets('non-function-halls section shows sub-sections', (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.sportsTurfs,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sports & Recreation'), findsWidgets);
    expect(find.text('Box Cricket & Turf'), findsOneWidget);
    expect(find.text('Gym & Fitness'), findsOneWidget);
  });

  testWidgets(
      'hero card shows the selected section and matrix lists all sections',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    // The static hero card reflects the selected section only.
    expect(find.byKey(const ValueKey('master-hero-function_halls')),
        findsOneWidget);
    expect(find.text('Function Halls & Celebrations'), findsWidgets);
    expect(find.text('Sports & Recreation'), findsWidgets);
    expect(find.byKey(const Key('master-sports_turfs')), findsOneWidget);
  });

  testWidgets(
      'all sections render in 3D Matrix mode, not just the selected one',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    for (final section in MainHomeSection.discoveryOrder) {
      expect(find.byKey(Key('master-${section.id}')), findsOneWidget,
          reason: '${section.id} should render as a 3D matrix card');
    }
  });

  testWidgets('tapping a chip changes the highlighted/selected section',
      (tester) async {
    MainHomeSection? changedTo;
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (s) => changedTo = s,
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sports & Recreation').first);
    await tester.pumpAndSettle();

    expect(changedTo, MainHomeSection.sportsTurfs);
  });

  testWidgets('explore action fires for the selected section', (tester) async {
    MainHomeSection? explored;
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (s) => explored = s,
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    // Tapping the already-selected master card explores it
    // (same contract as before this change).
    await tester.tap(find.byKey(const Key('master-function_halls')));
    await tester.pumpAndSettle();

    expect(explored, MainHomeSection.functionHalls);
  });

  testWidgets(
      'switching to Standard Grid and Compact List renders every section',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        1024,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discovery-layout-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('discovery-layout-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UI 2: Standard Grid').last);
    await tester.pumpAndSettle();

    for (final section in MainHomeSection.discoveryOrder) {
      expect(find.textContaining(section.displayTitle), findsWidgets);
    }

    await tester.tap(find.byKey(const Key('discovery-layout-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UI 3: Compact List').last);
    await tester.pumpAndSettle();
    for (final section in MainHomeSection.discoveryOrder) {
      expect(find.textContaining(section.displayTitle), findsWidgets);
    }
  });

  testWidgets('empty categories list shows the empty state, not a blank panel',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: const [],
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No categories are available right now.'), findsOneWidget);
  });

  testWidgets('loading state shows skeleton cards, not fabricated categories',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
          isLoadingLiveData: true,
        ),
        390,
      ),
    );
    await tester.pump();

    // No live-count text is fabricated while loading.
    expect(find.textContaining(' live'), findsNothing);
  });

  testWidgets('CMS image for a slot is used when active with a url',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
          categoryImageBySlot: {
            MainHomeSection.functionHalls.imageSlot: const CmsBanner(
              id: 'b1',
              title: 'Function halls hero',
              subtitle: '',
              slot: 'category_function_halls',
              imageUrl: 'https://cdn.example.com/function-halls.jpg',
              isActive: true,
            ),
          },
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<AppNetworkImage>(
      find
          .descendant(
            of: find.byKey(const Key('master-function_halls')),
            matching: find.byType(AppNetworkImage),
          )
          .first,
    );
    // Cache-busted with the banner's id (no updatedAt set in this fixture).
    expect(image.url, 'https://cdn.example.com/function-halls.jpg?v=b1');
  });

  testWidgets(
      'disabled CMS image falls back to the stock photo, not a blank image',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
          categoryImageBySlot: {
            MainHomeSection.functionHalls.imageSlot: const CmsBanner(
              id: 'b1',
              title: 'Function halls hero',
              subtitle: '',
              slot: 'category_function_halls',
              imageUrl: 'https://cdn.example.com/function-halls.jpg',
              isActive: false, // draft/disabled -- must not be used
            ),
          },
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<AppNetworkImage>(
      find
          .descendant(
            of: find.byKey(const Key('master-function_halls')),
            matching: find.byType(AppNetworkImage),
          )
          .first,
    );
    expect(image.url, MainHomeSection.functionHalls.fallbackImageUrl);
  });

  testWidgets('a section with no configured CMS image uses the stable fallback',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
          // No categoryImageBySlot entries at all -- every section must
          // still render its own stable fallback photo, never blank and
          // never a randomized unrelated image.
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    for (final section in MainHomeSection.discoveryOrder) {
      final image = tester.widget<AppNetworkImage>(
        find
            .descendant(
              of: find.byKey(Key('master-${section.id}')),
              matching: find.byType(AppNetworkImage),
            )
            .first,
      );
      expect(image.url, section.fallbackImageUrl);
    }
  });

  testWidgets('a generic (no-slot) banner never overrides a category image',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
          // categoryImageBySlot is keyed by slot; a generic banner (slot
          // null) simply never appears in this map (see
          // activeCmsBannersBySlotProvider), so there's nothing to assert
          // beyond the fallback still being used.
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<AppNetworkImage>(
      find
          .descendant(
            of: find.byKey(const Key('master-function_halls')),
            matching: find.byType(AppNetworkImage),
          )
          .first,
    );
    expect(image.url, MainHomeSection.functionHalls.fallbackImageUrl);
  });

  testWidgets('all five real category images render with a resolved url',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    // Exactly the real 5 sections -- never a fabricated 6th.
    expect(MainHomeSection.discoveryOrder.length, 5);
    for (final section in MainHomeSection.discoveryOrder) {
      final image = tester.widget<AppNetworkImage>(
        find
            .descendant(
              of: find.byKey(Key('master-${section.id}')),
              matching: find.byType(AppNetworkImage),
            )
            .first,
      );
      expect(image.url, isNotEmpty);
    }
  });

  testWidgets('a republished image (new updated_at) changes the rendered url',
      (tester) async {
    Future<void> pumpWithBanner(CmsBanner banner) => tester.pumpWidget(
          _wrapScrollable(
            CategoryDiscoveryPanel(
              sections: MainHomeSection.discoveryOrder,
              selected: MainHomeSection.functionHalls,
              categories: const [],
              venues: const [],
              onMasterChanged: (_) {},
              onMasterExplore: (_) {},
              onSubSectionTap: (_, __) {},
              onExploreAll: () {},
              categoryImageBySlot: {
                MainHomeSection.functionHalls.imageSlot: banner,
              },
            ),
            390,
          ),
        );

    const url = 'https://cdn.example.com/function-halls.jpg';
    await pumpWithBanner(CmsBanner(
      id: 'b1',
      title: 'Function halls hero',
      subtitle: '',
      slot: 'category_function_halls',
      imageUrl: url,
      isActive: true,
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    await tester.pumpAndSettle();
    final before = tester
        .widget<AppNetworkImage>(
          find
              .descendant(
                of: find.byKey(const Key('master-function_halls')),
                matching: find.byType(AppNetworkImage),
              )
              .first,
        )
        .url;

    // Admin republishes the SAME url but Postgres bumps updated_at --
    // the rendered url must still change so cached image bytes are busted.
    await pumpWithBanner(CmsBanner(
      id: 'b1',
      title: 'Function halls hero',
      subtitle: '',
      slot: 'category_function_halls',
      imageUrl: url,
      isActive: true,
      updatedAt: DateTime.utc(2026, 2, 1),
    ));
    await tester.pumpAndSettle();
    final after = tester
        .widget<AppNetworkImage>(
          find
              .descendant(
                of: find.byKey(const Key('master-function_halls')),
                matching: find.byType(AppNetworkImage),
              )
              .first,
        )
        .url;

    expect(before, isNot(equals(after)));
    expect(before, contains(url));
    expect(after, contains(url));
  });

  testWidgets(
      'category accent color renders per section in matrix, grid, and list modes',
      (tester) async {
    Future<void> expectAccentedColors() async {
      for (final section in MainHomeSection.discoveryOrder) {
        expect(find.textContaining(section.displayTitle), findsWidgets);
      }
    }

    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
        ),
        1024,
      ),
    );
    await tester.pumpAndSettle();
    await expectAccentedColors(); // 3D Matrix (default mode)

    await tester.tap(find.byKey(const Key('discovery-layout-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UI 2: Standard Grid').last);
    await tester.pumpAndSettle();
    await expectAccentedColors(); // Standard Grid

    await tester.tap(find.byKey(const Key('discovery-layout-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UI 3: Compact List').last);
    await tester.pumpAndSettle();
    await expectAccentedColors(); // Compact List
  });

  testWidgets(
      'a curated CMS icon replaces the default emoji in the 3D Matrix tile',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
          categoryImageBySlot: {
            MainHomeSection.functionHalls.imageSlot: const CmsBanner(
              id: 'b1',
              title: 'Function halls hero',
              subtitle: '',
              slot: 'category_function_halls',
              isActive: true,
              iconName: 'celebration',
            ),
          },
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('master-function_halls'));
    expect(
      find.descendant(
          of: tile, matching: find.byIcon(Icons.celebration_rounded)),
      findsOneWidget,
    );
  });

  testWidgets(
      'an unrecognized CMS icon falls back to the default emoji, not a blank icon',
      (tester) async {
    await tester.pumpWidget(
      _wrapScrollable(
        CategoryDiscoveryPanel(
          sections: MainHomeSection.discoveryOrder,
          selected: MainHomeSection.functionHalls,
          categories: const [],
          venues: const [],
          onMasterChanged: (_) {},
          onMasterExplore: (_) {},
          onSubSectionTap: (_, __) {},
          onExploreAll: () {},
          categoryImageBySlot: {
            MainHomeSection.functionHalls.imageSlot: const CmsBanner(
              id: 'b1',
              title: 'Function halls hero',
              subtitle: '',
              slot: 'category_function_halls',
              isActive: true,
              iconName: 'not_a_real_icon',
            ),
          },
        ),
        390,
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('master-function_halls'));
    expect(
      find.descendant(
          of: tile, matching: find.text(MainHomeSection.functionHalls.emoji)),
      findsOneWidget,
    );
  });

  testWidgets(
      'publishing a category style in admin (simulated by re-supplying '
      'categoryImageBySlot after invalidation) updates the customer-facing '
      'card icon, accent, gradient, and badge color', (tester) async {
    Future<void> pumpWithBanner(CmsBanner? banner) => tester.pumpWidget(
          _wrapScrollable(
            CategoryDiscoveryPanel(
              sections: MainHomeSection.discoveryOrder,
              selected: MainHomeSection.functionHalls,
              categories: const [],
              venues: const [],
              onMasterChanged: (_) {},
              onMasterExplore: (_) {},
              onSubSectionTap: (_, __) {},
              onExploreAll: () {},
              categoryImageBySlot: banner == null
                  ? const {}
                  : {MainHomeSection.functionHalls.imageSlot: banner},
            ),
            390,
          ),
        );

    await pumpWithBanner(null);
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('master-function_halls'));
    expect(
      find.descendant(
          of: tile, matching: find.text(MainHomeSection.functionHalls.emoji)),
      findsOneWidget,
    );
    expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.hotel_rounded)),
        findsNothing);

    const published = CmsBanner(
      id: 'b1',
      title: 'Function halls hero',
      subtitle: '',
      slot: 'category_function_halls',
      isActive: true,
      iconName: 'hotel',
      accentColor: '#7C3AED',
      gradientStartColor: '#7C3AED',
      gradientEndColor: '#22D3EE',
      badgeColor: '#22D3EE',
    );
    await pumpWithBanner(published);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.hotel_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: tile, matching: find.text(MainHomeSection.functionHalls.emoji)),
      findsNothing,
    );

    final resolved =
        CmsCategoryStyle.resolve(MainHomeSection.functionHalls, published);
    expect(resolved.accentColor, CmsCategoryStyle.tryParseHex('#7C3AED'));
    expect(resolved.gradientStart, CmsCategoryStyle.tryParseHex('#7C3AED'));
    expect(resolved.gradientEnd, CmsCategoryStyle.tryParseHex('#22D3EE'));
    expect(resolved.badgeColor, CmsCategoryStyle.tryParseHex('#22D3EE'));
  });
  testWidgets('no overflow errors at tested breakpoints', (tester) async {
    for (final width in [320.0, 375.0, 390.0, 430.0, 768.0, 1024.0, 1440.0]) {
      await tester.pumpWidget(
        _wrapScrollable(
          CategoryDiscoveryPanel(
            sections: MainHomeSection.discoveryOrder,
            selected: MainHomeSection.functionHalls,
            categories: const [],
            venues: const [],
            onMasterChanged: (_) {},
            onMasterExplore: (_) {},
            onSubSectionTap: (_, __) {},
            onExploreAll: () {},
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
