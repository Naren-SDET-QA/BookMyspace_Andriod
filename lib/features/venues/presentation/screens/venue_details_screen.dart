import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/category_accent.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../booking/domain/booking.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../reviews/presentation/widgets/venue_reviews_section.dart';
import '../../../venue_sections/domain/venue_section.dart';
import '../../../venue_sections/presentation/venue_section_providers.dart';
import '../../domain/listing_template.dart';
import '../../domain/venue.dart';
import '../venue_providers.dart';
import '../widgets/listing_availability.dart';
import '../widgets/venue_badges.dart';

/// Unified listing detail used by every category. Layout is template-driven;
/// missing live fields hide their section instead of inventing content.
class VenueDetailsScreen extends ConsumerWidget {
  const VenueDetailsScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailsProvider(venueId));

    return venueAsync.when(
      loading: () => const Scaffold(
        body: _ListingSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
        ),
      ),
      data: (venue) => _VenueDetailsScaffold(venue: venue),
    );
  }
}

class _VenueDetailsScaffold extends ConsumerStatefulWidget {
  const _VenueDetailsScaffold({required this.venue});

  final Venue venue;

  @override
  ConsumerState<_VenueDetailsScaffold> createState() =>
      _VenueDetailsScaffoldState();
}

class _VenueDetailsScaffoldState extends ConsumerState<_VenueDetailsScaffold> {
  SlotAvailability? _selectedSlot;

  Venue get venue => widget.venue;
  ListingTemplateConfig get template => venue.listingTemplate;

  Future<void> _openAvailability() async {
    final slot = await showListingAvailabilitySheet(
      context: context,
      venue: venue,
      initialSlot: _selectedSlot,
    );
    if (slot != null && mounted) {
      setState(() => _selectedSlot = slot);
    }
  }

  void _openBooking() {
    context.push('/venues/${venue.id}/book', extra: venue);
  }

  Future<void> _call() async {
    final phone = venue.contactPhone.trim();
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  void _chat() {
    context.push(AppRoutes.support);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    final supportEnabled = ref.watch(moduleEnabledProvider('support'));
    final publishedSections =
        ref.watch(publishedVenueSectionsProvider(venue.id));
    final showCall = template.showCall && venue.contactPhone.trim().isNotEmpty;
    final showChat = template.showChat && supportEnabled;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final responsive = ResponsiveInfo.fromConstraints(constraints);
          final content = _ListingBody(
            venue: venue,
            template: template,
            publishedSections: publishedSections,
            onOpenAvailability: _openAvailability,
            selectedSlot: _selectedSlot,
          );
          if (responsive.isExpanded || responsive.isExtraWide) {
            final summaryWidth = responsive.isExtraWide ? 320.0 : 220.0;
            const gapWidth = 16.0;

            return CustomScrollView(
              slivers: [
                _heroBar(context, l10n, favorite),
                SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: responsive.maxContentWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          responsive.horizontalPadding,
                          16,
                          responsive.horizontalPadding,
                          24,
                        ),
                        // Measure available width AFTER padding is applied
                        child: LayoutBuilder(
                          builder: (context, innerConstraints) {
                            final availableWidth = innerConstraints.maxWidth;
                            final contentMaxWidth =
                                availableWidth - summaryWidth - gapWidth;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Content takes available space minus summary and gap
                                Flexible(
                                  flex: 1,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: contentMaxWidth,
                                    ),
                                    child: content,
                                  ),
                                ),
                                SizedBox(width: gapWidth),
                                // Summary with fixed width
                                SizedBox(
                                  width: summaryWidth,
                                  child: _StickySummary(
                                    venue: venue,
                                    template: template,
                                    selectedSlot: _selectedSlot,
                                    onAvailability: _openAvailability,
                                    onBook: venue.isActive ? _openBooking : null,
                                    onCall: showCall ? _call : null,
                                    onChat: showChat ? _chat : null,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return CustomScrollView(
            slivers: [
              _heroBar(context, l10n, favorite),
              SliverToBoxAdapter(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final responsive = ResponsiveInfo.fromConstraints(
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
          );
          if (responsive.isExpanded || responsive.isExtraWide) {
            return const SizedBox.shrink();
          }
          if (!venue.isActive) return const SizedBox.shrink();
          return _StickyCtaBar(
            venue: venue,
            template: template,
            selectedSlot: _selectedSlot,
            onAvailability: _openAvailability,
            onBook: _openBooking,
            onCall: showCall ? _call : null,
            onChat: showChat ? _chat : null,
          );
        },
      ),
      floatingActionButton: supportEnabled
          ? FloatingActionButton.small(
              key: const Key('listing_ai_help'),
              tooltip: l10n.support,
              onPressed: _chat,
              child: const Icon(Icons.support_agent_rounded),
            )
          : null,
    );
  }

  SliverAppBar _heroBar(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<bool> favorite,
  ) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 260,
      leading: IconButton(
        tooltip: l10n.back,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _HeroGallery(venue: venue),
      ),
      actions: [
        favorite.when(
          data: (isFav) => IconButton(
            tooltip: l10n.savedVenues,
            onPressed: () async {
              if (ref.read(currentUserProvider) == null) {
                context.push(AppRoutes.login);
                return;
              }
              await ref.read(favoriteControllerProvider).toggle(venue.id);
            },
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              color: isFav ? AppTheme.accent : null,
            ),
          ),
          loading: () => const IconButton(
            onPressed: null,
            icon: Icon(Icons.favorite_outline_rounded),
          ),
          error: (_, __) => const IconButton(
            onPressed: null,
            icon: Icon(Icons.favorite_outline_rounded),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (venue.images.isNotEmpty)
          PageView.builder(
            itemCount: venue.images.length,
            itemBuilder: (context, i) => AppNetworkImage(
              url: venue.images[i].url,
              fit: BoxFit.cover,
            ),
          )
        else
          const ColoredBox(
            color: AppTheme.darkCanvas,
            child: Center(child: BookMySpaceMark(size: 80)),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 72,
          bottom: 16,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (venue.category != null)
                _OverlayChip(
                  icon: Icons.category_outlined,
                  label: venue.category!.name,
                ),
              if (venue.hasDiscount)
                _OverlayChip(
                  icon: Icons.local_offer_outlined,
                  label:
                      '${(((venue.originalPrice! - venue.price) / venue.originalPrice!) * 100).round()}% OFF',
                  color: Colors.orange,
                ),
              if (venue.distanceKm != null)
                _OverlayChip(
                  icon: Icons.near_me_outlined,
                  label: formatDistance(venue.distanceKm),
                ),
            ],
          ),
        ),
        if (venue.images.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: _OverlayChip(
              icon: Icons.photo_library_outlined,
              label: '${venue.images.length}',
            ),
          ),
      ],
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.black).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingBody extends StatelessWidget {
  const _ListingBody({
    required this.venue,
    required this.template,
    required this.publishedSections,
    required this.onOpenAvailability,
    this.selectedSlot,
  });

  final Venue venue;
  final ListingTemplateConfig template;
  final AsyncValue<List<PublishedVenueSection>> publishedSections;
  final VoidCallback onOpenAvailability;
  final SlotAvailability? selectedSlot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = categoryAccentColor(venue.category?.parentSection);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredFadeSlideIn(
            index: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    venue.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (venue.isVerified) const VerifiedBadge(),
              ],
            ),
          ),
          if (venue.ratingCount > 0) ...[
            const SizedBox(height: 6),
            RatingBadge(rating: venue.avgRating, count: venue.ratingCount),
          ],
          const SizedBox(height: 8),
          StaggeredFadeSlideIn(
            index: 1,
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    venue.address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PriceRow(venue: venue),
          if (venue.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.aboutThisVenue, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              venue.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _KeySpecsCard(venue: venue, template: template),
          if (venue.facilities.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.amenities, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: venue.facilities
                  .where((f) => f.isAvailable)
                  .map(
                    (f) => Chip(
                      avatar: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: accent,
                      ),
                      label: Text(f.facility),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (venue.operatingHours.isNotEmpty &&
              template.specKeys.contains('hours')) ...[
            const SizedBox(height: 20),
            Text(l10n.operatingHours, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _HoursList(hours: venue.operatingHours),
          ],
          if (venue.cancellationSummary.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Cancellation policy', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              venue.cancellationSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (venue.rules.isNotEmpty) ...[
            const SizedBox(height: 20),
            GlassmorphicCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Venue rules',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    venue.rules,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('listing_availability'),
              onPressed: onOpenAvailability,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(
                selectedSlot == null
                    ? template.ctaAvailability
                    : '${selectedSlot!.label} · ${selectedSlot!.displayStart}–${selectedSlot!.displayEnd}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 20),
          VenueReviewsSection(venueId: venue.id),
          const SizedBox(height: 20),
          Text(l10n.address, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _VenueMap(
            latitude: venue.latitude,
            longitude: venue.longitude,
            name: venue.name,
            accent: accent,
          ),
          publishedSections.maybeWhen(
            data: (sections) => sections.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _OwnerPublishedSections(sections: sections),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          const _AssuranceCard(),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = categoryAccentColor(venue.category?.parentSection);
    return Row(
      children: [
        if (venue.hasDiscount) ...[
          Text(
            formatInr(venue.originalPrice!),
            style: theme.textTheme.titleSmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          formatInr(venue.price),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _KeySpecsCard extends StatelessWidget {
  const _KeySpecsCard({required this.venue, required this.template});

  final Venue venue;
  final ListingTemplateConfig template;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    for (final key in template.specKeys) {
      switch (key) {
        case 'capacity':
          if (venue.capacity > 0) {
            rows.add(('Capacity', '${venue.capacity}'));
          }
        case 'parking':
          if (venue.parkingCapacity > 0) {
            rows.add(('Parking', '${venue.parkingCapacity} vehicles'));
          }
        case 'food':
          if (venue.foodOptions.isNotEmpty) {
            rows.add(('Catering', venue.foodOptions));
          }
        case 'hours':
          break;
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key specifications',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.violet,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                      child: Text(row.$1, style: theme.textTheme.bodyMedium)),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HoursList extends StatelessWidget {
  const _HoursList({required this.hours});

  final List<VenueOperatingHours> hours;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: hours.map((h) {
        final label = _dayNames[h.dayOfWeek.clamp(0, 6)];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Text(
                  h.isClosed ? 'Closed' : '${h.opensAt} – ${h.closesAt}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _VenueMap extends StatelessWidget {
  const _VenueMap({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.accent = AppTheme.violet,
  });

  final double latitude;
  final double longitude;
  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bookmyspace.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.location_pin, color: accent, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssuranceCard extends StatelessWidget {
  const _AssuranceCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppTheme.violet),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'BookMySpace holds payment until the owner confirms. You only pay for a real, available slot.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyCtaBar extends StatelessWidget {
  const _StickyCtaBar({
    required this.venue,
    required this.template,
    required this.onAvailability,
    required this.onBook,
    this.selectedSlot,
    this.onCall,
    this.onChat,
  });

  final Venue venue;
  final ListingTemplateConfig template;
  final SlotAvailability? selectedSlot;
  final VoidCallback onAvailability;
  final VoidCallback onBook;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final price = selectedSlot?.priceAmount ?? venue.price;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Starting from',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                formatInr(price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.violet,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onCall != null)
                    IconButton(
                      key: const Key('listing_call'),
                      tooltip: template.ctaCall,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onCall,
                      icon: const Icon(Icons.call_rounded, size: 18),
                    ),
                  if (onChat != null)
                    IconButton(
                      key: const Key('listing_chat'),
                      tooltip: template.ctaChat,
                      visualDensity: VisualDensity.compact,
                      onPressed: onChat,
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                    ),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('listing_availability_cta'),
                      onPressed: onAvailability,
                      child: Text(
                        template.ctaAvailability,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton(
                      key: const Key('listing_book_cta'),
                      onPressed: onBook,
                      child: Text(
                        template.ctaBook,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickySummary extends StatelessWidget {
  const _StickySummary({
    required this.venue,
    required this.template,
    required this.onAvailability,
    required this.onBook,
    this.selectedSlot,
    this.onCall,
    this.onChat,
  });

  final Venue venue;
  final ListingTemplateConfig template;
  final SlotAvailability? selectedSlot;
  final VoidCallback onAvailability;
  final VoidCallback? onBook;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Booking summary',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _PriceRow(venue: venue),
          if (selectedSlot != null) ...[
            const SizedBox(height: 8),
            Text(
              '${selectedSlot!.label} · ${selectedSlot!.displayStart}–${selectedSlot!.displayEnd}',
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('listing_availability_cta'),
            onPressed: onAvailability,
            child: Text(template.ctaAvailability),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('listing_book_cta'),
            onPressed: onBook,
            child: Text(template.ctaBook),
          ),
          if (onCall != null || onChat != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: Text(template.ctaCall),
                    ),
                  ),
                if (onCall != null && onChat != null) const SizedBox(width: 8),
                if (onChat != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text(template.ctaChat),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ListingSkeleton extends StatelessWidget {
  const _ListingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 240, radius: 0),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              SkeletonBox(height: 28),
              SizedBox(height: 12),
              SkeletonBox(height: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 90),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerPublishedSections extends StatelessWidget {
  const _OwnerPublishedSections({required this.sections});

  final List<PublishedVenueSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final ordered = [...sections]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _OwnerPublishedSectionCard(
            section: ordered[i],
            theme: theme,
            language: language,
          ),
        ],
      ],
    );
  }
}

class _OwnerPublishedSectionCard extends StatelessWidget {
  const _OwnerPublishedSectionCard({
    required this.section,
    required this.theme,
    required this.language,
  });

  final PublishedVenueSection section;
  final ThemeData theme;
  final String language;

  @override
  Widget build(BuildContext context) {
    final localizedTitle = section.localizedTitle(language);
    final title =
        localizedTitle.isNotEmpty ? localizedTitle : section.sectionName;
    final content = section.localizedContent(language);

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_ownerSectionIconFor(section.sectionIcon), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (section.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppNetworkImage(
                  url: section.imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (section.visibleSubsections.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: section.visibleSubsections
                    .map(
                      (s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _ownerSectionIconFor(String? name) {
  switch (name) {
    case 'info_outline':
      return Icons.info_outline;
    case 'check_circle_outline':
      return Icons.check_circle_outline;
    case 'photo_library_outlined':
      return Icons.photo_library_outlined;
    case 'gavel_outlined':
      return Icons.gavel_outlined;
    case 'help_outline':
      return Icons.help_outline;
    case 'place_outlined':
      return Icons.place_outlined;
    case 'dashboard_customize_outlined':
      return Icons.dashboard_customize_outlined;
    default:
      return Icons.widgets_outlined;
  }
}
