import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/core/theme/app_theme_config.dart';
import 'package:bookmyspace/features/theme/domain/app_theme_config_snapshot.dart';
import 'package:bookmyspace/features/theme/presentation/app_theme_providers.dart';
import 'package:bookmyspace/features/theme/presentation/screens/admin_theme_customizer_screen.dart';

void main() {
  test('invalid server tokens fall back to safe values and bounded metrics',
      () {
    final config = AppThemeConfig.fromJson({
      'schema_version': 1,
      'light': {
        'primary': 'not-a-color',
        'background': '#FFFFFF',
        'text': '#FFFFFF',
      },
      'dark': {'background': '#071422', 'text': '#F8FAFC'},
      'card_radius': 99,
      'button_style': 'unknown',
    });

    expect(config.light.primary, AppThemeVariant.defaultLight.primary);
    expect(config.cardRadius, 32);
    expect(config.buttonStyle, 'filled');
    expect(
      AppThemeVariant.contrast(config.light.text, config.light.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('theme data consumes custom colors, shape tokens, and banner extension',
      () {
    final config = AppThemeConfig.defaults.copyWith(
      light: AppThemeConfig.defaults.light.copyWith(
        primary: const Color(0xFF7C3AED),
        background: const Color(0xFFF8F5FF),
      ),
      cardRadius: 22,
      bannerStyle: 'solid',
    );

    final theme = AppTheme.fromConfig(config, Brightness.light);
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    final extension = theme.extension<AppThemeExtension>()!;

    expect(theme.colorScheme.primary, const Color(0xFF7C3AED));
    expect(shape.borderRadius, BorderRadius.circular(22));
    expect(extension.bannerStyle, 'solid');
  });

  testWidgets('admin theme workspace renders live preview on a phone width',
      (tester) async {
    const snapshot = AppThemeConfigSnapshot(
      draft: AppThemeConfig.defaults,
      published: AppThemeConfig.defaults,
      draftVersion: 1,
      publishedVersion: 1,
    );

    await tester.binding.setSurfaceSize(const Size(320, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAppThemeConfigProvider.overrideWith((ref) async => snapshot),
        ],
        child: const MaterialApp(
          home: AdminThemeCustomizerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theme Customizer'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Live customer preview'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Live customer preview'), findsOneWidget);
    expect(find.byType(SegmentedButton<Brightness>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
