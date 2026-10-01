import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../../admin/presentation/app_branding_providers.dart';

Color? _parseHex(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var cleaned = raw.trim();
  if (cleaned.startsWith('#')) cleaned = cleaned.substring(1);
  if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(cleaned)) {
    return Color(int.parse(cleaned, radix: 16));
  }
  return null;
}

/// Drop-in replacement for [BookMySpaceMark] that renders the admin logo
/// URL when an admin has set one, else the bundled asset.
class LiveBrandMark extends ConsumerWidget {
  const LiveBrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(appBrandingProvider).valueOrNull;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = branding?.logoForBrightness(dark)?.trim();
    return BookMySpaceMark(
      size: size,
      logoUrlOverride: url?.isEmpty == true ? null : url,
    );
  }
}

/// Drop-in replacement for [BookMySpaceBrand] with live admin branding.
class LiveBrandLockup extends ConsumerWidget {
  const LiveBrandLockup({super.key, this.markSize = 36, this.fontSize = 20});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(appBrandingProvider).valueOrNull;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = branding?.logoForBrightness(dark)?.trim();
    return BookMySpaceBrand(
      markSize: markSize,
      fontSize: fontSize,
      logoUrlOverride: url?.isEmpty == true ? null : url,
      appName: branding?.appName ?? 'BookMySpace',
      firstColor:
          _parseHex(branding?.wordmarkFirstColor) ?? AppTheme.brand,
      restColor: _parseHex(branding?.wordmarkRestColor),
    );
  }
}
