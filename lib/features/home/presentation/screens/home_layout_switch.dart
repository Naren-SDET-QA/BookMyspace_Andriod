import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/presentation/admin_settings_providers.dart';
import 'choice_home_screen.dart';
import 'home_screen.dart';
import 'premium_home_screen.dart';

/// Home tab content, chosen by admin Home settings -> Home layout.
///
/// `moment` and `life` are the two showcase Homes. `premium` shows
/// [PremiumHomeScreen]. Every other value (including the default `glass`,
/// and `modern`, which has its own preview route) keeps the existing
/// [HomeScreen]. While settings load, the existing Home is shown so the tab
/// never flashes blank.
class HomeLayoutSwitch extends ConsumerWidget {
  const HomeLayoutSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref
        .watch(adminSettingsProvider)
        .valueOrNull
        ?.home['home_layout']
        ?.toString();
    return switch (layout) {
      'moment' => const ChoiceHomeScreen(style: ChoiceHomeStyle.moment),
      'life' => const ChoiceHomeScreen(style: ChoiceHomeStyle.life),
      'premium' => const PremiumHomeScreen(),
      _ => const HomeScreen(),
    };
  }
}
