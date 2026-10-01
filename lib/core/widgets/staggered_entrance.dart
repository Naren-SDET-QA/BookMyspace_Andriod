import 'package:flutter/material.dart';

/// Lightweight, dependency-free staggered fade + slide-up entrance
/// animation.
///
/// Wrap any grid/list item with this to have it cascade into view with a
/// per-[index] delay — the same "reveal one after another" effect used on
/// the web home screen's category section, implemented with plain
/// [AnimationController]s so it needs no extra package and stays cheap
/// enough to run on every item in a grid.
///
/// Usage:
/// ```dart
/// StaggeredFadeSlideIn(
///   index: index,
///   child: MyCategoryCard(...),
/// )
/// ```
class StaggeredFadeSlideIn extends StatefulWidget {
  const StaggeredFadeSlideIn({
    super.key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 80),
    this.duration = const Duration(milliseconds: 420),
    this.beginOffset = 28.0,
    this.curve = Curves.easeOutCubic,
  });

  /// Position of this item within its list/grid — determines how long to
  /// wait before this item starts animating in.
  final int index;

  final Widget child;

  /// Extra delay added per [index] before the entrance animation starts.
  final Duration delayStep;

  /// How long the fade/slide animation itself takes once it starts.
  final Duration duration;

  /// Vertical distance (in logical pixels) the child slides up from.
  final double beginOffset;

  final Curve curve;

  @override
  State<StaggeredFadeSlideIn> createState() => _StaggeredFadeSlideInState();
}

class _StaggeredFadeSlideInState extends State<StaggeredFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    // Encode the per-item delay in the controller timeline instead of
    // scheduling a callback. This keeps the entrance animation deterministic
    // and lifecycle-safe when a sliver is rebuilt or disposed quickly.
    final delay = widget.delayStep * widget.index;
    final totalDuration = delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: totalDuration);
    final totalMicros = totalDuration.inMicroseconds;
    final delayFraction = totalMicros <= 0
        ? 0.0
        : (delay.inMicroseconds / totalMicros).clamp(0.0, 1.0).toDouble();
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayFraction, 1.0, curve: widget.curve),
    );
    _fade = curved;
    _slide = Tween<double>(begin: widget.beginOffset, end: 0.0).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        );
      },
    );
  }
}
