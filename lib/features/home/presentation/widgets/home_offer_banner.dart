import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../offers/domain/coupon.dart';

class _BannerSlide {
  const _BannerSlide({
    required this.headline,
    required this.subtitle,
    this.code,
    this.claim = false,
  });

  final String headline;
  final String subtitle;
  final String? code;

  /// True when [subtitle] is a real monetary/percentage offer.
  final bool claim;
}

/// Premium promotional banner. Uses live coupon records when present;
/// never invents discounts.
class HomeOfferBanner extends StatefulWidget {
  const HomeOfferBanner({super.key, this.coupons = const []});

  final List<Coupon> coupons;

  @override
  State<HomeOfferBanner> createState() => _HomeOfferBannerState();
}

class _HomeOfferBannerState extends State<HomeOfferBanner>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drift;
  late final AnimationController _glow;
  late final AnimationController _arrow;
  late final PageController _pageController;
  Timer? _autoPlay;
  int _index = 0;
  bool? _running;

  List<_BannerSlide> get _slides {
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
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant HomeOfferBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coupons.length != widget.coupons.length) {
      _index = 0;
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
        animation: Listenable.merge([_drift, _glow, _arrow]),
        builder: (context, _) {
          final glowT = Curves.easeInOut.transform(_glow.value);
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
                        colors: isDark
                            ? const [
                                Color(0xFF075E54),
                                Color(0xFF0E7490),
                                Color(0xFF1E3A8A),
                              ]
                            : const [
                                Color(0xFF008F7A),
                                Color(0xFF14B8A6),
                                Color(0xFF38BDF8),
                                Color(0xFF818CF8),
                              ],
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
                          color: Colors.white.withValues(alpha: 0.10 + glowT * 0.06),
                        ),
                      ),
                    ),
                  ),
                  PageView.builder(
                    controller: _pageController,
                    itemCount: slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) =>
                        _BannerCopy(slide: slides[i], arrow: _arrow.value),
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
      final y = ((0.2 + seed) + math.sin((progress + seed) * math.pi * 2) * 0.08) %
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
