import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';

/// One slide of the Premium Home promo carousel.
@immutable
class PromoSlide {
  const PromoSlide({
    required this.id,
    required this.badge,
    required this.badgeIcon,
    required this.title,
    required this.colors,
    required this.onTap,
    this.subtitle = '',
    this.detail = '',
    this.detailIcon = Icons.place_rounded,
    this.highlight = '',
    this.highlightCaption = '',
    this.imageUrl = '',
  });

  /// Stable id, used for keys and tests.
  final String id;

  /// Short label in the top-left pill, e.g. "TODAY'S CLASS".
  final String badge;
  final IconData badgeIcon;
  final String title;
  final String subtitle;

  /// Secondary line with [detailIcon], e.g. "7:30 AM · Maitrivanam".
  final String detail;
  final IconData detailIcon;

  /// Big right-side figure, e.g. "₹185,000" or "10% OFF".
  final String highlight;
  final String highlightCaption;
  final String imageUrl;

  /// Gradient for this slide; the carousel animates between slides' colours.
  final List<Color> colors;
  final VoidCallback onTap;
}

/// Auto-rotating, multi-colour promo carousel.
///
/// Advances every [interval] (paused while the user is dragging, and disabled
/// when the platform asks for reduced motion). Shows a section badge, an
/// "n/N" counter with arrows and page dots, like the Spotlight row.
class PremiumPromoCarousel extends StatefulWidget {
  const PremiumPromoCarousel({
    super.key,
    required this.slides,
    this.interval = const Duration(seconds: 4),
    this.height = 210,
  });

  final List<PromoSlide> slides;
  final Duration interval;
  final double height;

  @override
  State<PremiumPromoCarousel> createState() => _PremiumPromoCarouselState();
}

class _PremiumPromoCarouselState extends State<PremiumPromoCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant PremiumPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.slides.length) _index = 0;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.slides.length < 2 || reduceMotion) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _dragging || !_controller.hasClients) return;
      _go(_index + 1);
    });
  }

  void _go(int target) {
    final count = widget.slides.length;
    if (count == 0 || !_controller.hasClients) return;
    final next = (target % count + count) % count;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final current = slides[_index.clamp(0, slides.length - 1)];

    final narrow = MediaQuery.sizeOf(context).width < 520;
    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: current.colors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(current.badgeIcon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              current.badge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      key: const Key('premium-promo-carousel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // The badge shrinks (with ellipsis) before anything overflows;
            // the section title only shows when there is room for it.
            // Phones: the badge shrinks (ellipsis) so arrows never overflow.
            // Wider: badge at natural size, title fills, arrows at the end.
            if (narrow) Flexible(child: badge) else badge,
            if (!narrow) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Deals & Happenings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            if (slides.length > 1) ...[
              IconButton(
                key: const Key('premium-promo-prev'),
                tooltip: 'Previous',
                visualDensity: VisualDensity.compact,
                onPressed: () => _go(_index - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${_index + 1}/${slides.length}',
                key: const Key('premium-promo-counter'),
                style: theme.textTheme.labelLarge,
              ),
              IconButton(
                key: const Key('premium-promo-next'),
                tooltip: 'Next',
                visualDensity: VisualDensity.compact,
                onPressed: () => _go(_index + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: widget.height,
          child: Listener(
            onPointerDown: (_) => _dragging = true,
            onPointerUp: (_) => _dragging = false,
            onPointerCancel: (_) => _dragging = false,
            child: PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _SlideCard(slide: slides[i]),
            ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? current.colors.first
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});

  final PromoSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          child: InkWell(
            key: Key('premium-slide-${slide.id}'),
            onTap: slide.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (slide.imageUrl.isNotEmpty)
                  AppNetworkImage(url: slide.imageUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: slide.imageUrl.isEmpty
                          ? slide.colors
                          : [
                              slide.colors.first.withValues(alpha: 0.95),
                              slide.colors.last.withValues(alpha: 0.55),
                            ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              slide.badgeIcon,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              slide.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  slide.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (slide.subtitle.isNotEmpty)
                                  Text(
                                    slide.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (slide.detail.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        slide.detailIcon,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          slide.detail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (slide.highlight.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  slide.highlight,
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (slide.highlightCaption.isNotEmpty)
                                  Text(
                                    slide.highlightCaption,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(width: 10),
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
