import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../owner_venues/presentation/widgets/media_preview.dart';
import '../../domain/media_item.dart';
import '../../domain/venue.dart';

enum VenueMediaTab {
  photos('Photos', Icons.photo_library_outlined),
  video('Short Video', Icons.videocam_outlined),
  virtual3d('3D / 360° Tour', Icons.view_in_ar_outlined);

  const VenueMediaTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Rich media section supporting Photos gallery carousel with thumbnails & lightbox,
/// Short Video walkthrough, and 3D / 360° virtual tours.
class VenueRichMediaViewer extends StatefulWidget {
  const VenueRichMediaViewer({
    super.key,
    required this.venue,
    this.height,
  });

  final Venue venue;
  final double? height;

  @override
  State<VenueRichMediaViewer> createState() => _VenueRichMediaViewerState();
}

class _VenueRichMediaViewerState extends State<VenueRichMediaViewer> {
  VenueMediaTab _selectedTab = VenueMediaTab.photos;
  late final PageController _pageController;
  int _currentPage = 0;
  String _activeTag = 'All';

  Venue get venue => widget.venue;

  List<String> get _allImages {
    if (venue.images.isNotEmpty) {
      return venue.images.map((img) => img.url).where((u) => u.isNotEmpty).toList();
    }
    return [
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800',
    ];
  }

  static const _availableTags = ['All', 'Main Space', 'Dining', 'Suites', 'Exterior'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _allImages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openFullscreen(int initialPage) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (ctx) => _FullscreenGalleryModal(
        images: _allImages,
        initialPage: initialPage,
        venueName: venue.name,
      ),
    );
  }

  MediaItem _mediaItem(String url, MediaKind kind) => MediaItem(
        id: '${venue.id}-${kind.name}',
        venueId: venue.id,
        url: url,
        kind: kind,
        isActive: true,
        isCover: false,
        sortOrder: 0,
        processingStatus: MediaProcessingStatus.ready,
      );

  Future<void> _openTour() async {
    if (venue.tourUrl.isEmpty) return;
    if (venue.tourIsModel) {
      await showMediaPreview(context, _mediaItem(venue.tourUrl, MediaKind.model3d));
      return;
    }
    final uri = Uri.tryParse(venue.tourUrl);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final defaultHeight = mediaWidth >= 1024 ? 380.0 : mediaWidth >= 600 ? 320.0 : 250.0;
    final carouselHeight = widget.height ?? defaultHeight;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Media Type Tabs Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: VenueMediaTab.values.map((tab) {
                        final isSelected = _selectedTab == tab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() => _selectedTab = tab),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                      ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tab.icon,
                                    size: 15,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tab.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '4K ULTRA HD',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_selectedTab) {
              VenueMediaTab.photos => _buildPhotosTab(context, carouselHeight),
              VenueMediaTab.video => _buildVideoTab(context, carouselHeight),
              VenueMediaTab.virtual3d => _build3dTab(context, carouselHeight),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosTab(BuildContext context, double height) {
    final theme = Theme.of(context);
    final images = _allImages;

    return Column(
      key: const ValueKey('tab_photos'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter tag chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: _availableTags.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final tag = _availableTags[index];
              final isSelected = _activeTag == tag;
              return ChoiceChip(
                label: Text(tag, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onSelected: (selected) {
                  if (selected) setState(() => _activeTag = tag);
                },
              );
            },
          ),
        ),

        // Carousel Container
        SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openFullscreen(index),
                    child: AppNetworkImage(
                      url: images[index],
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),

              // Gradient Scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 70,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    ),
                  ),
                ),
              ),

              // Top Bar: Verified Badge & Image Counter + Fullscreen
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    if (venue.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.collections_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentPage + 1}/${images.length}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      onTap: () => _openFullscreen(_currentPage),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Left navigation arrow button
              if (images.length > 1 && _currentPage > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      onPressed: _prevPage,
                    ),
                  ),
                ),

              // Right navigation arrow button
              if (images.length > 1 && _currentPage < images.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.chevron_right_rounded, size: 22),
                      onPressed: _nextPage,
                    ),
                  ),
                ),

              // Indicator Dots
              if (images.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 7,
                        width: isSelected ? 20 : 7,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),

        // Thumbnail strip (when multiple images exist)
        if (images.length > 1)
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final isSelected = index == _currentPage;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 58,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AppNetworkImage(
                      url: images[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVideoTab(BuildContext context, double height) {
    final theme = Theme.of(context);
    final hasVideo = venue.videoUrl.isNotEmpty;

    if (!hasVideo) {
      return Container(
        key: const ValueKey('tab_video_empty'),
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Short Video Walkthrough Unavailable',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The venue manager has not uploaded a video tour yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('tab_video_content'),
      height: height,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_allImages.isNotEmpty)
            AppNetworkImage(url: _allImages.first, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size(60, 60),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 36),
                  onPressed: () => showMediaPreview(
                    context,
                    _mediaItem(venue.videoUrl, MediaKind.video),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${venue.name} Walkthrough',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '▶ 0:45 min HD Tour',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3dTab(BuildContext context, double height) {
    final theme = Theme.of(context);
    final hasTour = venue.tourUrl.isNotEmpty;

    if (!hasTour) {
      return Container(
        key: const ValueKey('tab_3d_empty'),
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.view_in_ar_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              '3D / 360° Virtual Tour Unavailable',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Virtual 3D inspection has not been scanned for this venue yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('tab_3d_content'),
      height: height,
      color: Colors.black87,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_allImages.isNotEmpty)
            AppNetworkImage(url: _allImages.first, fit: BoxFit.cover),
          Container(
            color: Colors.black.withValues(alpha: 0.65),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _openTour,
                  icon: const Icon(Icons.threed_rotation_rounded, size: 22),
                  label: const Text(
                    'Launch 3D / 360° Tour',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Interact & walk through venue spaces in full 3D',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenGalleryModal extends StatefulWidget {
  const _FullscreenGalleryModal({
    required this.images,
    required this.initialPage,
    required this.venueName,
  });

  final List<String> images;
  final int initialPage;
  final String venueName;

  @override
  State<_FullscreenGalleryModal> createState() => _FullscreenGalleryModalState();
}

class _FullscreenGalleryModalState extends State<_FullscreenGalleryModal> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _controller = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.venueName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Photo ${_page + 1} of ${widget.images.length}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: AppNetworkImage(
                    url: widget.images[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          if (widget.images.length > 1 && _page > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  onPressed: () => _controller.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
          if (widget.images.length > 1 && _page < widget.images.length - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  onPressed: () => _controller.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
