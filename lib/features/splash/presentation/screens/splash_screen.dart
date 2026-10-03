import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../../admin/presentation/app_branding_providers.dart';
import '../../../admin/presentation/widgets/brand_loading_indicator.dart';

/// Lightweight Phase-1 splash that hands off to PROD onboarding/home guards.
///
/// Logo, app name and the loading spinner come from the global admin
/// branding ([appBrandingProvider]). While branding is still loading the
/// spinner slot stays empty (so a disabled spinner never flashes); if
/// branding cannot be loaded, the bundled defaults are used.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 700), _continue);
  }

  void _continue() {
    if (!mounted) return;
    final completed = ref.read(onboardingProvider);
    context.go(completed ? AppRoutes.shell : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandingAsync = ref.watch(appBrandingProvider);
    final loaded = brandingAsync.hasValue || brandingAsync.hasError;
    final branding = brandingAsync.valueOrNull ?? AppBranding.defaults;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookMySpaceMark(
              size: 88,
              semanticLabel: branding.appName,
              logoUrlOverride: branding.logoForBrightness(dark),
            ),
            const SizedBox(height: 16),
            Text(
              branding.appName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (loaded)
              BrandLoadingIndicator(branding: branding)
            else
              const SizedBox(width: 28, height: 28),
          ],
        ),
      ),
    );
  }
}
