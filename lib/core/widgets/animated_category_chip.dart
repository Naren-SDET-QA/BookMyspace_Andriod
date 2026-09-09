import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A responsive, glassmorphic category chip component featuring:
/// - Subtle 3D depth and frosted glass highlights
/// - Smooth mouse-hover lift and dynamic glow on desktop/web
/// - Tactile haptic feedback and springy micro-interaction on tap
/// - 60fps-optimized lightweight animation without heavy shaders
class AnimatedCategoryChip extends StatefulWidget {
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
  State<AnimatedCategoryChip> createState() => _AnimatedCategoryChipState();
}

class _AnimatedCategoryChipState extends State<AnimatedCategoryChip> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveSelectedColor =
        widget.selectedColor ?? theme.colorScheme.primary;
    final effectiveSelectedTextColor =
        widget.selectedTextColor ?? theme.colorScheme.onPrimary;
    final effectiveUnselectedColor = widget.unselectedColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));
    final effectiveUnselectedTextColor =
        widget.unselectedTextColor ?? theme.colorScheme.onSurface;

    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (kIsWeb ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translate(
                0.0,
                _isPressed
                    ? 1.5
                    : (_isHovered ? -2.5 : (widget.selected ? -1.0 : 0.0)),
                0.0,
              )
              ..scale(
                _isPressed
                    ? 0.96
                    : (_isHovered
                        ? 1.04
                        : (widget.selected ? 1.03 : 1.0)),
              ),
            transformAlignment: Alignment.center,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: widget.selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        effectiveSelectedColor,
                        Color.lerp(
                          effectiveSelectedColor,
                          const Color(0xFF6366F1),
                          0.25,
                        )!,
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        effectiveUnselectedColor,
                        effectiveUnselectedColor.withValues(alpha: 0.75),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.selected
                    ? effectiveSelectedColor
                    : (_isHovered
                        ? effectiveSelectedColor.withValues(alpha: 0.45)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
                width: widget.selected || _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: effectiveSelectedColor.withValues(alpha: 0.38),
                        blurRadius: _isHovered ? 14 : 10,
                        spreadRadius: _isHovered ? 1.5 : 0.5,
                        offset: Offset(0, _isHovered ? 4 : 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: _isHovered ? 0.3 : 0.1)
                            : const Color(0xFF0F172A).withValues(
                                alpha: _isHovered ? 0.08 : 0.02),
                        blurRadius: _isHovered ? 8 : 3,
                        offset: Offset(0, _isHovered ? 3 : 1),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                    child: widget.selected && widget.showCheckmarkOnSelect
                        ? Row(
                            key: const ValueKey('selected_state'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.emoji != null) ...[
                                Text(
                                  widget.emoji!,
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
                              if (widget.icon != null) ...[
                                widget.icon!,
                                const SizedBox(width: 6),
                              ] else if (widget.emoji != null) ...[
                                Text(
                                  widget.emoji!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ],
                          ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          widget.selected ? FontWeight.bold : FontWeight.w500,
                      color: widget.selected
                          ? effectiveSelectedTextColor
                          : effectiveUnselectedTextColor,
                      letterSpacing: widget.selected ? 0.2 : 0.0,
                    ),
                    child: Text(widget.label),
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
