import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A responsive category chip component designed with [AnimatedContainer] and
/// [AnimatedSwitcher] to deliver a fluid scale transition, border accentuation,
/// and luminous color highlight when toggled.
class AnimatedCategoryChip extends StatelessWidget {
  const AnimatedCategoryChip({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    this.emoji,
    this.icon,
    this.height = 38,
    this.selectedColor,
    this.selectedTextColor,
    this.unselectedColor,
    this.unselectedTextColor,
    this.showCheckmarkOnSelect = true,
    this.testTag,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final String? emoji;
  final Widget? icon;
  final double height;
  final Color? selectedColor;
  final Color? selectedTextColor;
  final Color? unselectedColor;
  final Color? unselectedTextColor;
  final bool showCheckmarkOnSelect;
  final String? testTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSelectedColor = selectedColor ?? theme.colorScheme.primary;
    final effectiveSelectedTextColor =
        selectedTextColor ?? theme.colorScheme.onPrimary;
    final effectiveUnselectedColor =
        unselectedColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final effectiveUnselectedTextColor =
        unselectedTextColor ?? theme.colorScheme.onSurface;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: selected
            ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        height: height,
        decoration: BoxDecoration(
          color: selected ? effectiveSelectedColor : effectiveUnselectedColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? effectiveSelectedColor
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: effectiveSelectedColor.withValues(alpha: 0.36),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // AnimatedSwitcher handles the micro-interaction transition between states
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: selected && showCheckmarkOnSelect
                        ? Row(
                            key: const ValueKey('selected_state'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (emoji != null) ...[
                                Text(
                                  emoji!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Icon(
                                Icons.check_circle_rounded,
                                size: 15,
                                color: effectiveSelectedTextColor,
                              ),
                              const SizedBox(width: 6),
                            ],
                          )
                        : Row(
                            key: const ValueKey('unselected_state'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                icon!,
                                const SizedBox(width: 6),
                              ] else if (emoji != null) ...[
                                Text(
                                  emoji!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ],
                          ),
                  ),

                  // Animated typography transition for label
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? effectiveSelectedTextColor
                          : effectiveUnselectedTextColor,
                      letterSpacing: selected ? 0.2 : 0.0,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
