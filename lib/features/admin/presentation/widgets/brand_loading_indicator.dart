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

  @override
  Widget build(BuildContext context) {
    // Keep the slot even when disabled so the splash layout does not jump.
    if (!branding.animationEnabled) {
      return SizedBox(width: size, height: size);
    }
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
