import 'package:flutter/material.dart';

/// A 2.8s cyan-to-teal sweep used for loading placeholders.
///
/// The same widget runs on iOS, Android, and web. When the device asks for
/// reduced motion, the sweep stays on the teal base color.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.4 + (t * 2.8), -0.2),
              end: Alignment(-0.2 + (t * 2.8), 0.2),
              colors: const [
                Color(0xFF99F6E4),
                Color(0xFF22D3EE),
                Color(0xFF0D9488),
                Color(0xFF99F6E4),
              ],
              stops: const [0, 0.42, 0.58, 1],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height = 14, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFCCFBF1),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Venue discovery card placeholder.
class VenueCardSkeleton extends StatelessWidget {
  const VenueCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            ShimmerBox(width: 96, height: 84, radius: 16),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 16),
                  SizedBox(height: 8),
                  ShimmerBox(width: 140, height: 12),
                  SizedBox(height: 8),
                  ShimmerBox(width: 88, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal category carousel placeholder.
class CategoryCarouselSkeleton extends StatelessWidget {
  const CategoryCarouselSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('category-carousel-skeleton'),
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) =>
            const ShimmerBox(width: 148, height: 96, radius: 16),
      ),
    );
  }
}

/// Booking summary placeholder used while a date or quote is loading.
class BookingSummarySkeleton extends StatelessWidget {
  const BookingSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('booking-summary-skeleton'),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 28, radius: 14),
          SizedBox(height: 16),
          ShimmerBox(height: 120, radius: 16),
          SizedBox(height: 12),
          ShimmerBox(height: 48, radius: 12),
          SizedBox(height: 8),
          ShimmerBox(width: 180, height: 16),
        ],
      ),
    );
  }
}

/// Invoice page placeholder shown before the PDF is ready.
class InvoicePreviewSkeleton extends StatelessWidget {
  const InvoicePreviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('invoice-preview-skeleton'),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 180, height: 28, radius: 8),
          SizedBox(height: 8),
          ShimmerBox(width: 120, height: 14),
          SizedBox(height: 24),
          ShimmerBox(height: 18),
          SizedBox(height: 8),
          ShimmerBox(height: 18),
          SizedBox(height: 8),
          ShimmerBox(width: 220, height: 18),
          SizedBox(height: 28),
          ShimmerBox(height: 160, radius: 12),
        ],
      ),
    );
  }
}
