import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../cms/domain/cms_banner.dart';
import '../../../offers/domain/coupon.dart';

class _BannerSlide {
  const _BannerSlide({
    required this.headline,
    required this.subtitle,
    this.code,
    this.claim = false,
    this.imageUrl,
  });

  final String headline;
  final String subtitle;
  final String? code;

  /// True when [subtitle] is a real monetary/percentage offer.
  final bool claim;

  /// Real per-banner image from the CMS record, when the banner has one.
  /// Never fabricated: coupon-sourced and default slides have no backing
  /// image field, so this stays null for those and the slide falls back to
  /// the animated color background instead of a made-up picture.
  final String? imageUrl;
}

/// Centralized per-banner color theme. To add another banner's look, add
/// one entry here -- nothing else in this file needs to change. Themes
/// cycle by slide index (`index % length`) when there are more slides than
/// themes, and each provides its own dark/light variant so the gradient
/// keeps working with the existing fixed white banner text. All entries are
/// deliberately deep/saturated (not pastel) so white text stays readable.
class _BannerColorTheme {
  const _BannerColorTheme({required this.dark, required this.light});

  final List<Color> dark;
  final List<Color> light;
}

const List<_BannerColorTheme> _bannerColorThemes = [
  // Teal/blue -- the original banner look, kept as the first theme.
  _BannerColorTheme(
    dark: [Color(0xFF075E54), Color(0xFF0E7490), Color(0xFF1E3A8A)],
    light: [Color(0xFF00695C), Color(0xFF0E7490), Color(0xFF1D4ED8)],
  ),
  // Violet/magenta.
  _BannerColorTheme(
    dark: [Color(0xFF4C1D95), Color(0xFF7E22CE), Color(0xFFA21CAF)],
    light: [Color(0xFF5B21B6), Color(0xFF9333EA), Color(0xFFC026D3)],
  ),
  // Amber/rose.
  _BannerColorTheme(
    dark: [Color(0xFF7C2D12), Color(0xFFB45309), Color(0xFF9D174D)],
    light: [Color(0xFF9A3412), Color(0xFFD97706), Color(0xFFBE185D)],
  ),
  // Emerald/cyan.
  _BannerColorTheme(
    dark: [Color(0xFF064E3B), Color(0xFF0D9488), Color(0xFF075985)],
    light: [Color(0xFF065F46), Color(0xFF0D9488), Color(0xFF0369A1)],
  ),
];

/// Deterministic lookup -- never randomized, so the same slide always
/// resolves to the same theme on every rebuild.
List<Color> _bannerColorsFor(int index, bool isDark) {
  final theme = _bannerColorThemes[index % _bannerColorThemes.length];
  return isDark ? theme.dark : theme.light;
}

/// Premium promotional banner. Uses live coupon records when present;
/// never invents discounts.
class HomeOfferBanner extends StatefulWidget {
  const HomeOfferBanner({
    super.key,
    this.coupons = const [],
    this.cmsBanners = const [],
  });

  final List<Coupon> coupons;
  final List<CmsBanner> cmsBanners;

  @override
  State<HomeOfferBanner> createState() => _HomeOfferBannerState();
}

class _HomeOfferBannerState extends State<HomeOfferBanner>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drift;
  late final AnimationController _glow;
  late final AnimationController _arrow;
  // Drives the banner's background color crossfade when the carousel moves
  // to a new slide. Purely a UI transition -- it never affects which slide
  // is showing, only how the color of the current one animates in.
  late final AnimationController _colorTransition;
  late final PageController _pageController;
  Timer? _autoPlay;
  int _index = 0;
  int _previousIndex = 0;
  bool? _running;

  List<_BannerSlide> get _slides {
    if (widget.cmsBanners.isNotEmpty) {
      return [
        for (final banner in widget.cmsBanners)
          _BannerSlide(
            headline: banner.title,
            subtitle: banner.subtitle,
            imageUrl: banner.imageUrl,
          ),
      ];
    }
    if (widget.coupons.isEmpty) {
      return const [
        _BannerSlide(
          headline: 'Book verified spaces',
          subtitle: 'Halls, turfs, and workspaces — live availability.',
        ),
      ];
    }
    return [
      for (final coupon in widget.coupons)
        _BannerSlide(
          headline: 'Book More, Save More!',
          subtitle: coupon.description.isNotEmpty
              ? coupon.description
              : coupon.valueLabel,
          code: coupon.code,
          claim: true,
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _arrow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _colorTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 1,
    );
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant HomeOfferBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coupons.length != widget.coupons.length) {
      _index = 0;
      _previousIndex = 0;
      _colorTransition.value = 1;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _syncAutoPlay();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _setRunning(active && mounted);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final intended = !reduce && !_isWidgetTest;
    if (_running == intended) return;
    _setRunning(!reduce);
  }

  void _setRunning(bool running) {
    final allowLoop = running && !_isWidgetTest;
    _running = allowLoop;
    if (allowLoop) {
      if (!_drift.isAnimating) _drift.repeat();
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
      if (!_arrow.isAnimating) _arrow.repeat(reverse: true);
      _syncAutoPlay();
    } else {
      _drift.stop();
      _glow.stop();
      _arrow.stop();
      _autoPlay?.cancel();
      _autoPlay = null;
    }
  }

  bool get _isWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  /// Slide changed (by autoplay, swipe, or dot tap alike). Kicks off the
  /// background color crossfade to the new slide's theme; the slide index
  /// itself and everything else about the carousel is unaffected.
  void _onPageChanged(int i) {
    if (i == _index) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _previousIndex = _index;
      _index = i;
    });
    if (reduceMotion || _isWidgetTest) {
      _colorTransition.value = 1;
    } else {
      _colorTransition
        ..value = 0
        ..forward();
    }
  }

  void _syncAutoPlay() {
    _autoPlay?.cancel();
    _autoPlay = null;
    if (_slides.length < 2) return;
    if (_isWidgetTest) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _autoPlay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoPlay?.cancel();
    _drift.dispose();
    _glow.dispose();
    _arrow.dispose();
    _colorTransition.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: slides[_index.clamp(0, slides.length - 1)].headline,
      child: AnimatedBuilder(
        animation: Listenable.merge([_drift, _glow, _arrow, _colorTransition]),
        builder: (context, _) {
          final glowT = Curves.easeInOut.transform(_glow.value);
          // Crossfade from the previous slide's theme to the current
          // slide's theme as `_colorTransition` runs 0 -> 1. At rest
          // (value == 1, the steady state between slide changes) this is
          // simply the current slide's colors -- deterministic, never
          // randomized.
          final fromColors = _bannerColorsFor(_previousIndex, isDark);
          final toColors = _bannerColorsFor(_index, isDark);
          final colorT = Curves.easeInOut.transform(_colorTransition.value);
          final bannerColors = List.generate(
            toColors.length,
            (i) => Color.lerp(fromColors[i], toColors[i], colorT)!,
          );
          return Container(
            height: 156,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brand.withValues(alpha: 0.18 + glowT * 0.12),
                  blurRadius: 22 + glowT * 8,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1 + _drift.value * 0.35, -1),
                        end: Alignment(1.2 - _drift.value * 0.25, 1.1),
                        colors: bannerColors,
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _ParticlePainter(
                      progress: _drift.value,
                      glow: glowT,
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                      -1.1 + _drift.value * 0.15,
                      -1.2,
                    ),
                    child: IgnorePointer(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withValues(alpha: 0.10 + glowT * 0.06),
                        ),
                      ),
                    ),
                  ),
                  PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) {
                      final slide = slides[i];
                      final hasImage =
                          slide.imageUrl != null && slide.imageUrl!.isNotEmpty;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Real per-banner image (CMS-authored), when this
                          // slide has one -- each banner shows its own
                          // picture instead of every slide looking the
                          // same. Slides with no backing image (coupons,
                          // the no-data fallback) simply skip this and show
                          // the animated color background underneath.
                          if (hasImage) ...[
                            AppNetworkImage(
                              url: slide.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                            // Scrim so the existing white text/CTA stay
                            // readable over an arbitrary photo.
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xB3000000),
                                    Color(0x40000000),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          _BannerCopy(slide: slide, arrow: _arrow.value),
                        ],
                      );
                    },
                  ),
                  if (slides.length > 1)
                    Positioned(
                      left: 20,
                      bottom: 12,
                      child: Row(
                        children: [
                          for (var i = 0; i < slides.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _index ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: i == _index ? 0.95 : 0.4,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({required this.slide, required this.arrow});

  final _BannerSlide slide;
  final double arrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 28),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (slide.code != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      'Use code ${slide.code}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                slide.claim ? Icons.card_giftcard_rounded : Icons.auto_awesome,
                color: Colors.white.withValues(alpha: 0.95),
                size: 32,
              ),
              const SizedBox(height: 10),
              Transform.translate(
                offset: Offset(4 * (arrow - 0.5), 0),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress, required this.glow});

  final double progress;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const count = 14;
    for (var i = 0; i < count; i++) {
      final seed = i * 0.137;
      final x = (seed * 1.7 + progress * (0.18 + (i % 3) * 0.04)) % 1.0;
      final y =
          ((0.2 + seed) + math.sin((progress + seed) * math.pi * 2) * 0.08) %
              1.0;
      final r = 1.6 + (i % 4) * 0.7 + glow * 0.6;
      paint.color = Colors.white.withValues(
        alpha: 0.12 + (i % 5) * 0.04 + glow * 0.08,
      );
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.glow != glow;
  }
}

/// Soft shimmer used only for home loading placeholders.
class HomeShimmerBox extends StatefulWidget {
  const HomeShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 16,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<HomeShimmerBox> createState() => _HomeShimmerBoxState();
}

class _HomeShimmerBoxState extends State<HomeShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: ShaderMask(
            shaderCallback: (rect) {
              final t = _controller.value;
              return LinearGradient(
                begin: Alignment(-1.0 + t * 2, 0),
                end: Alignment(-0.2 + t * 2, 0),
                colors: [
                  base.withValues(alpha: 0.35),
                  base.withValues(alpha: 0.7),
                  base.withValues(alpha: 0.35),
                ],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: Container(
              width: widget.width,
              height: widget.height,
              color: base.withValues(alpha: 0.45),
            ),
          ),
        );
      },
    );
  }
}
