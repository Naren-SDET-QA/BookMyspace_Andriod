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
  });

  final String screenKey;
  final String elementKey;
  final String fallback;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref
        .watch(resolvedUiElementOverridesProvider(screenKey))
        .valueOrNull?[elementKey];
    if (override?.hidden == true) return const SizedBox.shrink();
    return Text(
      override?.text?.trim().isNotEmpty == true ? override!.text! : fallback,
      style: style,
    );
  }
}
