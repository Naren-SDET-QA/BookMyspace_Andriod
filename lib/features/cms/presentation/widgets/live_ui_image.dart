import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui_element_override_providers.dart';
import '../../../../core/widgets/app_network_image.dart';

/// Renders [fallback] unless an admin image override exists for the
/// screen/element. Hidden elements collapse. Used for ANY image in the app:
/// pass screenKey + elementKey and the normal asset/network widget as fallback.
class LiveUiImage extends ConsumerWidget {
  const LiveUiImage({
    super.key,
    required this.screenKey,
    required this.elementKey,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
  });

  final String screenKey;
  final String elementKey;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  /// Pure URL reader for decorations, image providers, or when raw URL is needed.
  static String? resolveUrl(
    WidgetRef ref, {
    required String screenKey,
    required String elementKey,
    String? fallbackUrl,
  }) {
    final override = ref
        .watch(resolvedUiElementOverridesProvider(screenKey))
        .valueOrNull?[elementKey];
    final url = override?.imageUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    return fallbackUrl;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref
        .watch(resolvedUiElementOverridesProvider(screenKey))
        .valueOrNull?[elementKey];
    if (override?.hidden == true) return const SizedBox.shrink();
    final url = override?.imageUrl?.trim();
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: AppNetworkImage(url: url, fit: fit),
      ),
    );
  }
}

/// Reads an admin color override for an element, falling back to [fallback].
class LiveUiColor {
  static Color resolve(String? hex, Color fallback) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    var cleaned = hex.trim();
    if (cleaned.startsWith('#')) cleaned = cleaned.substring(1);
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(cleaned)) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return fallback;
  }
}
