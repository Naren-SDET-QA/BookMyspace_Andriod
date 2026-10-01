import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared BookMySpace brand mark.
///
/// The PNG is generated from the canonical Android `ic_bms_logo.xml` vector,
/// so Flutter, iOS and Android use the same emblem rather than platform icons.
/// Logo with two soft rings. The rings stay still when reduced motion is on.
class PulsingBrandMark extends StatefulWidget {
  const PulsingBrandMark({super.key, this.size = 72});

  final double size;

  @override
  State<PulsingBrandMark> createState() => _PulsingBrandMarkState();
}

class _PulsingBrandMarkState extends State<PulsingBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final mark = BookMySpaceMark(size: widget.size);
    if (reduce) return mark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return SizedBox(
          width: widget.size + 28,
          height: widget.size + 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Ring(
                size: widget.size + 8 + (t * 16),
                opacity: 0.28 - (t * 0.16),
              ),
              _Ring(size: widget.size + 18 + ((1 - t) * 10), opacity: 0.16),
              child!,
            ],
          ),
        );
      },
      child: mark,
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: opacity.clamp(0, 1)),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: opacity * 0.6),
            blurRadius: 12,
          ),
        ],
      ),
    );
  }
}

class BookMySpaceMark extends StatelessWidget {
  const BookMySpaceMark({
    super.key,
    this.size = 64,
    this.semanticLabel = 'BookMySpace',
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Image.asset(
        'assets/icons/bookmyspace_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// The BookMySpace wordmark used wherever the product name is displayed.
class BookMySpaceWordmark extends StatelessWidget {
  const BookMySpaceWordmark({
    super.key,
    this.fontSize = 22,
    this.textColor,
    this.textAlign = TextAlign.left,
  });

  final double fontSize;
  final Color? textColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -fontSize * 0.025,
          color: textColor ?? Theme.of(context).colorScheme.onSurface,
        ) ??
        TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: textColor ?? AppTheme.textPrimary,
        );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Book',
            style: baseStyle.copyWith(color: AppTheme.brand),
          ),
          TextSpan(text: 'My', style: baseStyle),
          TextSpan(
            text: 'Space',
            style: baseStyle.copyWith(color: AppTheme.brand),
          ),
        ],
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Compact horizontal logo lockup for app bars and headers.
class BookMySpaceBrand extends StatelessWidget {
  const BookMySpaceBrand({super.key, this.markSize = 36, this.fontSize = 20});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BookMySpaceMark(size: markSize),
        SizedBox(width: markSize * 0.22),
        BookMySpaceWordmark(fontSize: fontSize),
      ],
    );
  }
}
