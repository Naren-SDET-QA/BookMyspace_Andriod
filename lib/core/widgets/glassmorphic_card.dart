import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A high-performance, 60fps glassmorphic card component featuring:
/// - Subtle 3D depth, specular rim borders, and dual-layer soft ambient shadows
/// - Dynamic brand gradients for accentuation
/// - Smooth mouse-hover tilt and vertical lift for desktop/web
/// - Micro-interaction feedback on tap/press for touch/mobile
/// - Lightweight, zero-stutter entrance fade/slide animation
/// - Low-end & mobile optimized: avoids heavy runtime BackdropFilter blur shaders,
///   achieving pristine glassmorphism through layered alpha tints, gradient borders,
///   and native compositor shadows.
class GlassmorphicCard extends StatefulWidget {
  const GlassmorphicCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 18.0,
    this.borderWidth = 1.2,
    this.accentGradient,
    this.surfaceColor,
    this.surfaceAlpha = 0.85,
    this.hoverLift = -5.0,
    this.hoverScale = 1.018,
    this.tiltIntensity = 0.025,
    this.isInteractive = true,
    this.enableEntrance = true,
    this.entranceDelayMs = 0,
    this.padding,
    this.margin = EdgeInsets.zero,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double borderWidth;
  final Gradient? accentGradient;
  final Color? surfaceColor;
  final double surfaceAlpha;
  final double hoverLift;
  final double hoverScale;
  final double tiltIntensity;
  final bool isInteractive;
  final bool enableEntrance;
  final int entranceDelayMs;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final Clip clipBehavior;

  @override
  State<GlassmorphicCard> createState() => _GlassmorphicCardState();
}

class _GlassmorphicCardState extends State<GlassmorphicCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController? _entranceController;
  late final Animation<double>? _fadeAnimation;
  late final Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.enableEntrance) {
      _entranceController = AnimationController(
        duration: const Duration(milliseconds: 320),
        vsync: this,
      );
      _fadeAnimation = CurvedAnimation(
        parent: _entranceController!,
        curve: Curves.easeOut,
      );
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.04),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Curves.easeOutCubic,
        ),
      );

      if (widget.entranceDelayMs > 0) {
        Future.delayed(Duration(milliseconds: widget.entranceDelayMs), () {
          if (mounted) _entranceController.forward();
        });
      } else {
        _entranceController.forward();
      }
    } else {
      _entranceController = null;
      _fadeAnimation = null;
      _slideAnimation = null;
    }
  }

  @override
  void dispose() {
    _entranceController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Glass base tints tailored for light and dark palettes
    final baseColor =
        widget.surfaceColor ?? (isDark ? AppTheme.darkCard : Colors.white);
    final glassColor = baseColor.withValues(alpha: widget.surfaceAlpha);

    // Accent used for the hover rim/glow: derived from accentGradient when
    // the caller supplies one (e.g. a per-category color), falling back to
    // the app's brand color everywhere else so existing callers look
    // unchanged.
    final Color hoverAccent = widget.accentGradient is LinearGradient &&
            (widget.accentGradient as LinearGradient).colors.isNotEmpty
        ? (widget.accentGradient as LinearGradient).colors.first
        : AppTheme.brand;

    // Specular border highlights
    final borderColor = _isHovered
        ? hoverAccent.withValues(alpha: isDark ? 0.6 : 0.45)
        : (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE2E8F0));

    // Dynamic rim glow, tinted with the accent color
    final glowColor = _isHovered
        ? hoverAccent.withValues(alpha: isDark ? 0.35 : 0.22)
        : Colors.transparent;

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: widget.margin,
      transform: widget.isInteractive
          ? (Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_isHovered ? -widget.tiltIntensity : 0.0)
            ..translateByDouble(
              0.0,
              _isPressed ? 2.0 : (_isHovered ? widget.hoverLift : 0.0),
              0.0,
              1.0,
            )
            ..scaleByDouble(
              _isPressed ? 0.985 : (_isHovered ? widget.hoverScale : 1.0),
              _isPressed ? 0.985 : (_isHovered ? widget.hoverScale : 1.0),
              _isPressed ? 0.985 : (_isHovered ? widget.hoverScale : 1.0),
              1.0,
            ))
          : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: borderColor,
          width: _isHovered ? widget.borderWidth + 0.5 : widget.borderWidth,
        ),
        boxShadow: [
          // Soft ambient ambient depth shadow
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: _isHovered ? 0.45 : 0.25)
                : const Color(0xFF0F172A).withValues(
                    alpha: _isPressed ? 0.04 : (_isHovered ? 0.16 : 0.07)),
            blurRadius: _isHovered ? 24 : (_isPressed ? 6 : 14),
            offset: Offset(0, _isHovered ? 12 : (_isPressed ? 2 : 6)),
            spreadRadius: _isHovered ? 1.5 : 0,
          ),
          // Dynamic brand gradient reflection rim
          if (_isHovered)
            BoxShadow(
              color: glowColor,
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 1.0,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(widget.borderRadius - widget.borderWidth),
        clipBehavior: widget.clipBehavior,
        child: Stack(
          children: [
            // Subtle diagonal glass specular shine
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.05 : 0.22),
                        Colors.white.withValues(alpha: isDark ? 0.01 : 0.04),
                        Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Accent gradient header stripe if provided
            if (widget.accentGradient != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 3.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: widget.accentGradient),
                ),
              ),
            // Inner content wrapped with optional padding and tap responsiveness
            if (widget.padding != null)
              Padding(padding: widget.padding!, child: widget.child)
            else
              widget.child,
          ],
        ),
      ),
    );

    if (widget.onTap != null && widget.isInteractive) {
      cardContent = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (kIsWeb ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap?.call();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: cardContent,
        ),
      );
    }

    if (widget.enableEntrance &&
        _fadeAnimation != null &&
        _slideAnimation != null) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
