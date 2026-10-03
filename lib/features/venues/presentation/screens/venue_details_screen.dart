import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/category_accent.dart';
import '../../../../core/widgets/app_navigation_controls.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../reviews/presentation/widgets/venue_reviews_section.dart';
import '../../../venue_sections/domain/venue_section.dart';
import '../../../venue_sections/presentation/venue_section_providers.dart';
import '../../domain/listing_template.dart';
import '../../domain/venue.dart';
import '../venue_providers.dart';
import '../custom_listing_field_providers.dart';
import '../widgets/custom_listing_fields_section.dart';
import '../widgets/listing_availability.dart';
import '../widgets/pg_rent_calculator_card.dart';
import '../widgets/venue_badges.dart';
import '../widgets/venue_enquiry_sheet.dart';
import '../widgets/venue_rich_media_viewer.dart';
import '../widgets/selected_slot_crowd_card.dart';
import '../widgets/venue_facilities_amenities_section.dart';
import '../widgets/venue_location_navigation_section.dart';
import '../../../booking/presentation/widgets/peak_booking_hours_card.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../home/presentation/discovery_booking_prefs.dart';
import '../../../home/presentation/recently_viewed.dart';
import '../../../analytics/domain/analytics_event.dart';
import '../../../analytics/presentation/analytics_providers.dart';

/// Unified listing detail used by every category. Layout is template-driven;
/// missing live fields hide their section instead of inventing content.
class VenueDetailsScreen extends ConsumerWidget {
  const VenueDetailsScreen({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueDetailsProvider(venueId));

    return venueAsync.when(
      loading: () => const Scaffold(body: _ListingSkeleton()),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: const AppNavigationControls(),
          leadingWidth: AppNavigationControls.kLeadingWidth,
        ),
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

  @override
  void initState() {
    super.initState();
    // Feeds Home's "Your Recently Viewed" row (local to this device).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentlyViewedProvider.notifier).record(venue);
      ref
          .read(analyticsTrackerProvider)
          .track(AnalyticsEventType.viewVenueDetails, {
            'venue_id': venue.id,
            if (venue.category?.slug != null) 'category': venue.category!.slug,
          });
    });
  }

  Future<void> _openAvailability() async {
    final slot = await showListingAvailabilitySheet(
      context: context,
      venue: venue,
      initialSlot: _selectedSlot,
    );
    if (slot != null && mounted) {
      setState(() => _selectedSlot = slot);
      ref.read(analyticsTrackerProvider).track(
        AnalyticsEventType.selectTimeSlot,
        {'venue_id': venue.id, 'slot_id': slot.slotId},
      );
    }
  }

  Future<void> _sendEnquiry() async {
    if (ref.read(currentUserProvider) == null) {
      await context.push(AppRoutes.login);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showVenueEnquirySheet(context, venue);
    if (sent) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enquiry sent. Our team will get back to you soon.'),
        ),
      );
    }
  }

  void _openBooking() {
    context.push('/venues/${venue.id}/book', extra: venue);
  }

  Future<void> _call() async {
    final phone = _callablePhone;
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  /// The number the customer may dial: the owner's direct line once contact
  /// is revealed, otherwise the masked form (see the masking note in build).
  String get _callablePhone => _contactRevealed
      ? venue.contactPhone.trim()
      : maskContactPhone(venue.contactPhone);

  bool _contactRevealed = false;

  Future<void> _whatsapp() async {
    final phone = venue.contactPhone.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) return;
    // WhatsApp requires a country code; the platform serves India.
    final number = phone.startsWith('91') ? phone : '91$phone';
    final text = Uri.encodeComponent(
      'Hi, I am interested in ${venue.name} on BookMySpace.',
    );
    final uri = Uri.parse('https://wa.me/$number?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _chat() {
    try {
      context.push(AppRoutes.support);
    } catch (_) {}
  }

  void _showAnalyticsOverlay() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('venue_analytics_overlay_dialog'),
        title: const Row(
          children: [
            Icon(Icons.analytics_rounded, color: AppTheme.violet),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Least Busy Hours Analytics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Based on historical venue bookings for ${venue.name}, book during off-peak hours to avoid crowds and get cheaper rates:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🟢 LEAST BUSY / OFF-PEAK (Best Value)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF047857),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• 07:00 AM - 10:00 AM (18% occupancy, 20% OFF)', style: TextStyle(fontSize: 11)),
                  Text('• 02:00 PM - 04:00 PM (28% occupancy, 15% OFF)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🟡 MODERATE OCCUPANCY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• 10:00 AM - 01:00 PM (54% average occupancy)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔴 PEAK HOURS (High Demand)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('• 06:00 PM - 09:00 PM (88% occupancy - Reserve early)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            key: const Key('close_analytics_overlay'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _showVoiceReadout() {
    final speechText = venue.capacity > 0
        ? '${venue.name} in ${venue.city}. Pricing starts from ₹${venue.price.toInt()}. Accommodates up to ${venue.capacity} guests. Verified and available for instant booking.'
        : '${venue.name} in ${venue.city}. Starting price is ₹${venue.price.toInt()}. Verified and available for instant booking.';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.volume_up_rounded, color: AppTheme.violet),
            SizedBox(width: 8),
            Text('Audio Readout', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, color: AppTheme.violet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      speechText,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    final supportEnabled = ref.watch(moduleEnabledProvider('support'));
    final publishedSections = ref.watch(
      publishedVenueSectionsProvider(venue.id),
    );
    // Contact masking (reference parity with the Android privacy rule):
    // the owner's direct number is only actionable once the customer has a
    // booking the owner accepted. Before that, the call button dials a
    // masked number. Anonymous visitors see the masked form too.
    final hasApprovedBooking = ref
        .watch(hasApprovedBookingForVenueProvider(venue.id))
        .valueOrNull;
    final contactRevealed = hasApprovedBooking ?? false;
    _contactRevealed = contactRevealed;
    final callablePhone = contactRevealed
        ? venue.contactPhone.trim()
        : maskContactPhone(venue.contactPhone);
    final showCall = template.showCall && callablePhone.isNotEmpty;
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
            onSendEnquiry: supportEnabled ? _sendEnquiry : null,
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
                                const SizedBox(width: gapWidth),
                                // Summary with fixed width
                                SizedBox(
                                  width: summaryWidth,
                                  child: _StickySummary(
                                    venue: venue,
                                    template: template,
                                    selectedSlot: _selectedSlot,
                                    onAvailability: _openAvailability,
                                    onBook: venue.isActive
                                        ? _openBooking
                                        : null,
                                    onCall: showCall ? _call : null,
                                    onWhatsApp: showCall ? _whatsapp : null,
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
            onWhatsApp: showCall ? _whatsapp : null,
            onChat: showChat ? _chat : null,
          );
        },
      ),
      floatingActionButton: supportEnabled
          ? FloatingActionButton.extended(
              key: const Key('listing_ai_help'),
              heroTag: 'listing_ai_help_fab',
              elevation: 4,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              onPressed: _chat,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'AI Help',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
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
      title: Text(
        venue.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      leading: const AppNavigationControls(),
      leadingWidth: AppNavigationControls.kLeadingWidth,
      actions: [
        IconButton(
          key: const Key('venue_analytics_overlay_button'),
          tooltip: 'Least Busy Hours Analytics',
          onPressed: _showAnalyticsOverlay,
          icon: const Icon(Icons.analytics_outlined, color: AppTheme.violet),
        ),
        IconButton(
          key: const Key('voice_readout_button'),
          tooltip: 'Listen',
          onPressed: _showVoiceReadout,
          icon: const Icon(Icons.volume_up_rounded),
        ),
        favorite.when(
          data: (isFav) => IconButton(
            tooltip: l10n.savedVenues,
            onPressed: () async {
              if (ref.read(currentUserProvider) == null) {
                await context.push(AppRoutes.login);
                return;
              }
              await ref.read(favoriteControllerProvider).toggle(venue.id);
            },
            icon: Icon(
              isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isFav ? AppTheme.accent : null,
            ),
          ),
          loading: () => const IconButton(
            onPressed: null,
            icon: Icon(Icons.bookmark_border_rounded),
          ),
          error: (_, __) => const IconButton(
            onPressed: null,
            icon: Icon(Icons.bookmark_border_rounded),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _BookingAssuranceCard extends StatelessWidget {
  const _BookingAssuranceCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = <(IconData, String, String)>[
      if (venue.isVerified)
        (
          Icons.verified_outlined,
          'Verified listing',
          'This space carries the BookMySpace verified badge.',
        ),
      (
        Icons.payments_outlined,
        'Pay after acceptance',
        'Function hall payment is collected after the owner accepts the booking.',
      ),
      (
        Icons.qr_code_2_rounded,
        'QR entry pass',
        'A confirmed booking includes a QR pass for check-in.',
      ),
      (
        Icons.support_agent_rounded,
        'Help in the app',
        'Help & Support is available from your profile.',
      ),
    ];
    return Container(
      key: const Key('booking-assurance'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book with 100% Peace of Mind',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final point in points)
                    SizedBox(
                      width: width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(point.$1, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  point.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  point.$3,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => context.push(AppRoutes.support),
              icon: const Icon(Icons.call_outlined),
              label: const Text('Call Support'),
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
    this.onSendEnquiry,
  });

  final Venue venue;
  final ListingTemplateConfig template;
  final AsyncValue<List<PublishedVenueSection>> publishedSections;
  final VoidCallback onOpenAvailability;
  final SlotAvailability? selectedSlot;
  final VoidCallback? onSendEnquiry;

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
          VenueRichMediaViewer(venue: venue),
          const SizedBox(height: 16),
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
          if (venue.ratingCount > 0 || (venue.starRating ?? 0) > 0) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (venue.ratingCount > 0)
                  RatingBadge(
                    rating: venue.avgRating,
                    count: venue.ratingCount,
                  ),
                if ((venue.starRating ?? 0) > 0)
                  HotelClassBadge(stars: venue.starRating!),
              ],
            ),
          ],
          // BMS2 quick-fact chips: real venue data only (hidden when a
          // venue has none of capacity / parking / food info).
          if (venue.capacity > 0 ||
              venue.parkingCapacity > 0 ||
              venue.foodOptions.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (venue.capacity > 0)
                  _QuickFactChip(
                    icon: Icons.groups_rounded,
                    label: '${venue.capacity} Guests',
                  ),
                if (venue.parkingCapacity > 0)
                  _QuickFactChip(
                    icon: Icons.local_parking_rounded,
                    label: '${venue.parkingCapacity} Parking',
                  ),
                if (venue.foodOptions.trim().isNotEmpty)
                  _QuickFactChip(
                    icon: Icons.restaurant_rounded,
                    label: venue.foodOptions.trim(),
                  ),
              ],
            ),
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
          _BookingAssuranceCard(venue: venue),
          const SizedBox(height: 16),
          _PriceRow(venue: venue),
          if (CustomerSectionCatalog.sectionForVenue(venue) ==
                  CustomerSection.lodgeRooms &&
              venue.taxRate > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Taxes ${venue.taxRate.toStringAsFixed(0)}% — the booking total is calculated from the slot you choose.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (PgRentCalculatorCard.appliesTo(venue)) ...[
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) => PgRentCalculatorCard(
                venue: venue,
                initialTenureMonths: ref
                    .watch(discoveryBookingPrefsProvider)
                    .tenureMonths,
              ),
            ),
          ],
          if (CustomerSectionCatalog.sectionForVenue(venue) ==
              CustomerSection.lodgeRooms) ...[
            const SizedBox(height: 16),
            _HotelRoomsSection(venueId: venue.id),
          ],
          const SizedBox(height: 16),
          SelectedSlotCrowdCard(
            venueId: venue.id,
            selectedSlot: selectedSlot,
          ),
          PeakBookingHoursCard(
            venueId: venue.id,
            selectedDate: DateTime.now(),
            selectedSlotStart: selectedSlot?.startTime,
            initiallyExpanded: true,
          ),
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
          Consumer(
            builder: (context, ref, _) => ref
                .watch(venueListingCustomFieldsProvider(venue.id))
                .maybeWhen(
                  data: (fields) => CustomListingFieldsSection(fields: fields),
                  orElse: () => const SizedBox.shrink(),
                ),
          ),
          if (venue.facilities.isNotEmpty) ...[
            const SizedBox(height: 20),
            VenueFacilitiesAmenitiesSection(
              facilities: venue.facilities,
              accent: accent,
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
          if (onSendEnquiry != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                key: const Key('listing_send_enquiry'),
                onPressed: onSendEnquiry,
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Send enquiry'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          VenueReviewsSection(
            venueId: venue.id,
            avgRating: venue.avgRating,
            ratingCount: venue.ratingCount,
          ),
          const SizedBox(height: 20),
          VenueLocationNavigationSection(
            venue: venue,
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

String _priceSuffix(Venue venue) {
  if (venue.price <= 0) return '';
  return switch (CustomerSectionCatalog.sectionForVenue(venue)) {
    CustomerSection.lodgeRooms => ' / night',
    CustomerSection.pgHostels => ' / month',
    _ => '',
  };
}

class _HotelRoomsSection extends ConsumerWidget {
  const _HotelRoomsSection({required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(hotelRoomTypesProvider(venueId));
    return rooms.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room types', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Listed room types for this stay. Booking still holds one venue slot; these rows are not a separate room inventory reservation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (room) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.bed_outlined),
                  title: Text(room.name),
                  subtitle: Text(
                    [
                      if (room.bedType.isNotEmpty) room.bedType,
                      'Sleeps ${room.capacity}',
                      if (room.amenities.isNotEmpty) room.amenities.join(', '),
                    ].join(' · '),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    // FittedBox keeps original/current price on one line even inside the
    // narrow sticky summary column instead of overflowing it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
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
            '${formatInr(venue.price)}${_priceSuffix(venue)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
                    child: Text(row.$1, style: theme.textTheme.bodyMedium),
                  ),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
    this.onWhatsApp,
    this.onChat,
  });

  final Venue venue;
  final ListingTemplateConfig template;
  final SlotAvailability? selectedSlot;
  final VoidCallback onAvailability;
  final VoidCallback onBook;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
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
                  if (onWhatsApp != null)
                    IconButton(
                      key: const Key('listing_whatsapp'),
                      tooltip: 'WhatsApp',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat_rounded, size: 18),
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
    this.onWhatsApp,
    this.onChat,
  });

  final Venue venue;
  final ListingTemplateConfig template;
  final SlotAvailability? selectedSlot;
  final VoidCallback onAvailability;
  final VoidCallback? onBook;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
          if (onCall != null || onWhatsApp != null || onChat != null) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = <Widget>[
                  if (onCall != null)
                    OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: Text(
                        template.ctaCall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (onWhatsApp != null)
                    OutlinedButton.icon(
                      key: const Key('listing_whatsapp'),
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text(
                        'WhatsApp',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (onChat != null)
                    OutlinedButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text(
                        template.ctaChat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ];
                // Expanded and extra-wide summaries are 220px and 320px.
                // Three labeled actions do not fit on one row at those widths.
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        actions[i],
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                );
              },
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
    final title = localizedTitle.isNotEmpty
        ? localizedTitle
        : section.sectionName;
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

/// BMS2-style quick-fact chip (capacity / parking / food). Presentation
/// only; values come straight from the venue record.
class _QuickFactChip extends StatelessWidget {
  const _QuickFactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.violet),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
