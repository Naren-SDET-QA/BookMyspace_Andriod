import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_network_image.dart';

/// Shared BookMySpace brand mark.
///
/// The PNG is generated from the canonical Android `ic_bms_logo.xml` vector,
/// so Flutter, iOS and Android use the same emblem rather than platform icons.
/// Logo with two soft rings. The rings stay still when reduced motion is on.
class PulsingBrandMark extends StatefulWidget {
  const PulsingBrandMark({
    super.key,
    this.size = 72,
    this.logoUrlOverride,
    this.animate = true,
  });

  final double size;

  /// Admin logo URL (see `LivePulsingBrandMark`); null = bundled asset.
  final String? logoUrlOverride;

  /// When false the rings are not drawn (admin "loading animation" off).
  final bool animate;

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
    final mark = BookMySpaceMark(
      size: widget.size,
      logoUrlOverride: widget.logoUrlOverride,
    );
    if (reduce || !widget.animate) return mark;
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
    this.logoUrlOverride,
  });

  final double size;
  final String semanticLabel;

  /// When set, renders this network logo instead of the bundled asset.
  /// `LiveBrandMark` (cms/live_brand.dart) feeds this from the admin
  /// branding row — the single source of truth for the logo.
  final String? logoUrlOverride;

  @override
  Widget build(BuildContext context) {
    final url = logoUrlOverride?.trim();
    final Widget image;
    if (url != null && url.isNotEmpty) {
      image = AppNetworkImage(url: url, fit: BoxFit.contain);
    } else {
      image = Image.asset(
        'assets/icons/bookmyspace_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

/// The BookMySpace wordmark used wherever the product name is displayed.
/// Admin-editable: [appName] splits into Book/My/Space coloring when it has
/// three words, otherwise renders as-is; [firstColor]/[restColor] override
/// the default brand violet.
class BookMySpaceWordmark extends StatelessWidget {
  const BookMySpaceWordmark({
    super.key,
    this.fontSize = 22,
    this.textColor,
    this.textAlign = TextAlign.left,
    this.appName = 'BookMySpace',
    this.firstColor,
    this.restColor,
  });

  final double fontSize;
  final Color? textColor;
  final TextAlign textAlign;
  final String appName;
  final Color? firstColor;
  final Color? restColor;

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

    final brand = firstColor ?? AppTheme.brand;
    final name = appName.trim().isEmpty ? 'BookMySpace' : appName.trim();
    // Custom names (e.g. "My Venue App") render in a single style so admin
    // renames never produce broken Book/My/Space splits.
    if (name != 'BookMySpace') {
      return Text(
        name,
        style: baseStyle.copyWith(color: textColor ?? brand),
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Book', style: baseStyle.copyWith(color: brand)),
          TextSpan(
            text: 'My',
            style: baseStyle.copyWith(
              color: restColor ?? textColor ?? baseStyle.color,
            ),
          ),
          TextSpan(text: 'Space', style: baseStyle.copyWith(color: brand)),
        ],
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Compact horizontal logo lockup for app bars and headers.
/// Admin overrides flow through [logoUrlOverride]/[appName] so the SAME
/// widget renders bundled defaults or admin branding without call-site churn.
class BookMySpaceBrand extends StatelessWidget {
  const BookMySpaceBrand({
    super.key,
    this.markSize = 36,
    this.fontSize = 20,
    this.logoUrlOverride,
    this.appName = 'BookMySpace',
    this.firstColor,
    this.restColor,
  });

  final double markSize;
  final double fontSize;
  final String? logoUrlOverride;
  final String appName;
  final Color? firstColor;
  final Color? restColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BookMySpaceMark(size: markSize, logoUrlOverride: logoUrlOverride),
        SizedBox(width: markSize * 0.22),
        BookMySpaceWordmark(
          fontSize: fontSize,
          appName: appName,
          firstColor: firstColor,
          restColor: restColor,
        ),
      ],
    );
  }
}
