import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../app_branding_providers.dart';

/// The admin-configurable loading spinner.
///
/// Used by the splash screen and by the Admin Studio live preview so both
/// always render the same thing for the same [AppBranding].
class BrandLoadingIndicator extends StatelessWidget {
  const BrandLoadingIndicator({
    super.key,
    required this.branding,
    this.size = 28,
  });

  /// Key of the spinner itself (absent when the animation is disabled).
  static const spinnerKey = ValueKey('brand-loading-spinner');

  final AppBranding branding;
  final double size;

  /// Animated media assets (GIF / animated WebP) render in a box this many
  /// times the spinner [size], so a branded loader is legible.
  static const assetScale = 2.0;

  /// Key of the custom animation asset (absent when the spinner is used).
  static const assetKey = ValueKey('brand-loading-asset');

  @override
  Widget build(BuildContext context) {
    // Keep the slot even when disabled so the splash layout does not jump.
    if (!branding.animationEnabled) {
      return SizedBox(width: size, height: size);
    }
    final asset = branding.animationAssetUrl?.trim();
    if (asset != null && asset.isNotEmpty) {
      final box = size * assetScale;
      return SizedBox(
        width: box,
        height: box,
        child: Image.network(
          asset,
          key: assetKey,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Loading',
          // A broken / unreachable asset falls back to the default spinner
          // instead of leaving an empty loader.
          errorBuilder: (context, error, stack) =>
              Center(child: _spinner(context)),
        ),
      );
    }
    return _spinner(context);
  }

  Widget _spinner(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        key: spinnerKey,
        strokeWidth: AppBranding.clampThickness(branding.animationThickness),
        valueColor: AlwaysStoppedAnimation<Color>(
          branding.animationColorValue ?? AppTheme.brand,
        ),
      ),
    );
  }
}
