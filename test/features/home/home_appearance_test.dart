import 'package:bookmyspace/features/home/domain/home_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeAppearance', () {
    test('falls back to the shipped defaults for empty or malformed config', () {
      expect(HomeAppearance.fromJson(null).blocks.length,
          HomeAppearance.defaults.blocks.length);
      expect(HomeAppearance.fromJson('nonsense').blocks.length,
          HomeAppearance.defaults.blocks.length);
      expect(HomeAppearance.fromJson(const {}).blocks.length,
          HomeAppearance.defaults.blocks.length);
      expect(HomeAppearance.fromJson(const {'blocks': 'nope'}).blocks.length,
          HomeAppearance.defaults.blocks.length);
    });

    test('defaults keep the shipped Home order', () {
      final visible = HomeAppearance.defaults.visible;
      expect(visible.first.kind, HomeBlockKind.offerBanner);
      expect(
        visible.map((block) => block.kind),
        contains(HomeBlockKind.categoryMatrix),
      );
      expect(
        visible.map((block) => block.kind),
        contains(HomeBlockKind.spotlight),
      );
    });

    test('parses admin order, enable flags, colours and artwork', () {
      final appearance = HomeAppearance.fromJson(const {
        'blocks': [
          {
            'kind': 'spotlight',
            'order': 5,
            'enabled': false,
            'title': 'Featured picks',
            'images': ['https://cdn.example/a.jpg', '', 'https://b.jpg'],
            'style': {
              'background_colors': ['#FF7C3AED', '#FF2563EB'],
              'border_color': '#66FFFFFF',
              'border_width': 1.5,
              'glow': true,
            },
          },
        ],
      });

      final spotlight = appearance.blockFor(HomeBlockKind.spotlight)!;
      expect(spotlight.order, 5);
      expect(spotlight.enabled, isFalse);
      expect(spotlight.title, 'Featured picks');
      // Blank artwork entries are dropped.
      expect(spotlight.images, ['https://cdn.example/a.jpg', 'https://b.jpg']);
      expect(spotlight.style.backgroundColors,
          [const Color(0xFF7C3AED), const Color(0xFF2563EB)]);
      expect(spotlight.style.borderColor, const Color(0x66FFFFFF));
      expect(spotlight.style.borderWidth, 1.5);
      expect(spotlight.style.glow, isTrue);
    });

    test('unknown block kinds are ignored and missing ones keep defaults', () {
      final appearance = HomeAppearance.fromJson(const {
        'blocks': [
          {'kind': 'not_a_block', 'order': 1},
          {'kind': 'spotlight', 'order': 1, 'title': 'Only this one'},
        ],
      });
      // The unknown entry never becomes a block...
      expect(
        appearance.blocks.where((b) => b.kind == HomeBlockKind.spotlight).length,
        1,
      );
      // ...and the untouched blocks keep their shipped defaults.
      expect(appearance.blockFor(HomeBlockKind.categoryMatrix), isNotNull);
      expect(appearance.blockFor(HomeBlockKind.offerBanner), isNotNull);
    });

    test('visible() drops disabled blocks and sorts by admin order', () {
      final appearance = HomeAppearance.defaults.copyWithBlock(
        HomeAppearance.defaults
            .blockFor(HomeBlockKind.spotlight)!
            .copyWith(enabled: false, order: -5),
      );
      final visible = appearance.visible;
      expect(visible.any((b) => b.kind == HomeBlockKind.spotlight), isFalse);
      for (var i = 1; i < visible.length; i++) {
        expect(visible[i].order >= visible[i - 1].order, isTrue);
      }
    });

    test('style round-trips through JSON', () {
      const style = HomeBlockStyle(
        backgroundColors: [Color(0xFF008F7A), Color(0xFF38BDF8)],
        borderColor: Color(0x66FFFFFF),
        borderWidth: 1.5,
        radius: 20,
        glow: true,
      );
      final restored = HomeBlockStyle.fromJson(style.toJson());
      expect(restored.backgroundColors, style.backgroundColors);
      expect(restored.borderColor, style.borderColor);
      expect(restored.borderWidth, style.borderWidth);
      expect(restored.radius, style.radius);
      expect(restored.glow, style.glow);
    });

    test('a single background colour is treated as a solid fill', () {
      const style = HomeBlockStyle(backgroundColors: [Color(0xFF123456)]);
      expect(style.solidColor, const Color(0xFF123456));
      expect(style.hasGradient, isFalse);
    });
  });
}
