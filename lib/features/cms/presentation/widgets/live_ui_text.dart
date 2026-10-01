import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui_element_override_providers.dart';

/// Renders shipped copy unless an enabled admin override exists. Hidden
/// elements collapse without changing the surrounding layout contract.
class LiveUiText extends ConsumerWidget {
  const LiveUiText({
    super.key,
    required this.screenKey,
    required this.elementKey,
    required this.fallback,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String screenKey;
  final String elementKey;
  final String fallback;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  /// Helper to synchronously resolve a live text string when a widget accepts
  /// String rather than Widget (e.g. tooltip, dialog title, textfield hint).
  static String resolve(
    WidgetRef ref, {
    required String screenKey,
    required String elementKey,
    required String fallback,
  }) {
    final override = ref
        .watch(resolvedUiElementOverridesProvider(screenKey))
        .valueOrNull?[elementKey];
    if (override != null &&
        override.text != null &&
        override.text!.trim().isNotEmpty) {
      return override.text!;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref
        .watch(resolvedUiElementOverridesProvider(screenKey))
        .valueOrNull?[elementKey];
    if (override?.hidden == true) return const SizedBox.shrink();
    return Text(
      override?.text?.trim().isNotEmpty == true ? override!.text! : fallback,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
