import 'package:flutter/material.dart';

/// Shared cross-platform (web / iOS / Android) 3D tilt-and-press wrapper for
/// category cards.
///
/// - Web / desktop: tracks the mouse position over the card with
///   [MouseRegion.onHover] and continuously tilts the card toward the
///   pointer (a "live" 3D response), easing back to flat on exit.
/// - Touch (iOS / Android): there is no hover, so [GestureDetector] drives a
///   quick pressed-down tilt + scale on `onTapDown`/`onTapUp`/`onTapCancel`
///   so the card still feels alive when tapped.
///
/// This widget only handles the interaction/transform; callers keep full
/// control of the card's decoration and content via [child].
class InteractiveTiltCard extends StatefulWidget {
  const InteractiveTiltCard({
    super.key,
    required this.child,
    required this.onTap,
    this.maxTiltRadians = 0.12,
    this.hoverScale = 1.03,
    this.pressScale = 0.97,
    this.borderRadius,
    this.semanticLabel,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Maximum tilt applied on hover/drag, in radians.
  final double maxTiltRadians;

  /// Scale applied while hovered (web/desktop only).
  final double hoverScale;

  /// Scale applied while pressed (all platforms).
  final double pressScale;

  final BorderRadius? borderRadius;
  final String? semanticLabel;

  /// When false, all interaction effects are disabled (card stays flat).
  final bool enabled;

  @override
  State<InteractiveTiltCard> createState() => _InteractiveTiltCardState();
}

class _InteractiveTiltCardState extends State<InteractiveTiltCard> {
  Offset _pointer = Offset.zero; // -1..1 in both axes, relative to center
  bool _hovering = false;
  bool _pressed = false;
  Size _size = Size.zero;
  DateTime? _lastTapTime;

  /// Public pointer value for child sheen overlays (TiltCardSheen etc.).
  final ValueNotifier<Offset> pointerNotifier =
      ValueNotifier<Offset>(Offset.zero);

  /// Whether the pointer is currently inside the card bounds.
  bool get isHovering => _hovering;

  void _updatePointer(Offset local) {
    if (_size.isEmpty) return;
    final dx = (local.dx / _size.width) * 2 - 1;
    final dy = (local.dy / _size.height) * 2 - 1;
    final clamped = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
    _pointer = clamped;
    pointerNotifier.value = clamped;
  }

  @override
  void dispose() {
    pointerNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled && !reduceMotion;

    final rotateY =
        enabled && _hovering ? _pointer.dx * widget.maxTiltRadians : 0.0;
    final rotateX =
        enabled && _hovering ? -_pointer.dy * widget.maxTiltRadians : 0.0;
    final scale = _pressed
        ? widget.pressScale
        : (_hovering && enabled ? widget.hoverScale : 1.0);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        onEnter: (_) {
          if (!widget.enabled) return;
          setState(() => _hovering = true);
        },
        onExit: (_) {
          if (!widget.enabled) return;
          setState(() {
            _hovering = false;
            _pointer = Offset.zero;
          });
          pointerNotifier.value = Offset.zero;
        },
        onHover: widget.enabled
            ? (event) {
                _updatePointer(event.localPosition);
                // Only rebuild when tilt actually changes (throttle
                // pointer-driven rebuilds to avoid jitter on fast mouse
                // movement).
                if (mounted) setState(() {});
              }
            : null,
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (details) {
                  _updatePointer(details.localPosition);
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: widget.enabled
              ? (_) {
                  setState(() => _pressed = false);
                  // Debounce: ignore taps within 300ms of the last one.
                  final now = DateTime.now();
                  final last = _lastTapTime;
                  if (last != null &&
                      now.difference(last) <
                          const Duration(milliseconds: 300)) {
                    return;
                  }
                  _lastTapTime = now;
                  widget.onTap();
                }
              : null,
          onTapCancel: () => setState(() => _pressed = false),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _size = constraints.biggest;
              return AnimatedContainer(
                duration: Duration(
                  milliseconds: _hovering || _pressed ? 90 : 260,
                ),
                curve: Curves.easeOut,
                transformAlignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018)
                  ..rotateX(rotateX)
                  ..rotateY(rotateY)
                  ..scaleByDouble(scale, scale, 1.0, 1.0),
                child: widget.borderRadius != null
                    ? ClipRRect(
                        borderRadius: widget.borderRadius!,
                        child: widget.child,
                      )
                    : widget.child,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Small helper: a soft moving highlight that follows the pointer, layered
/// on top of a card to reinforce the "glass catching light" feel on hover.
/// Purely decorative; safe to omit on low-end devices.
class TiltCardSheen extends StatelessWidget {
  const TiltCardSheen(
      {super.key, required this.pointer, required this.visible});

  final Offset pointer; // -1..1
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final alignment = Alignment(pointer.dx, pointer.dy);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: alignment,
              radius: 0.9,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
