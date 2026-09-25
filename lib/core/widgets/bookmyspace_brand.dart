import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared BookMySpace brand mark.
///
/// The PNG is generated from the canonical Android `ic_bms_logo.xml` vector,
/// so Flutter, iOS and Android use the same emblem rather than platform icons.
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
    final baseStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
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
  const BookMySpaceBrand({
    super.key,
    this.markSize = 36,
    this.fontSize = 20,
  });

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
