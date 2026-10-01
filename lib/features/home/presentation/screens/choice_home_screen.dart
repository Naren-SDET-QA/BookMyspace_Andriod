import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/router/search_route.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/bookmyspace_brand.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../discovery_booking_prefs.dart';
import '../discovery_location.dart';
import '../home_category_catalog.dart';
import '../recently_viewed.dart';
import '../widgets/home_feed_sections.dart' show HomeGuestsPickerSheet;
import '../widgets/location_picker_sheet.dart';

/// The two customer Homes an admin can turn on from Home settings.
///
/// [moment] is the light page ("Your Space for Every Moment").
/// [life] is the dark page ("Spaces for Your Life").
enum ChoiceHomeStyle { moment, life }

/// Admin-chosen Home. Booking still uses the existing routes: hotels go to
/// stays, PG goes to PG, classes open Education, and halls search by slot.
class ChoiceHomeScreen extends ConsumerStatefulWidget {
  const ChoiceHomeScreen({super.key, required this.style});

  final ChoiceHomeStyle style;

  @override
  ConsumerState<ChoiceHomeScreen> createState() => _ChoiceHomeScreenState();
}

class _ChoiceHomeScreenState extends ConsumerState<ChoiceHomeScreen> {
  final _query = TextEditingController();

  bool get _dark => widget.style == ChoiceHomeStyle.life;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  SearchRouteParams _located({String? categorySlug, String? query, int? minCapacity}) {
    final location = ref.read(discoveryLocationProvider);
    return SearchRouteParams(
      query: query ?? '',
      categorySlug: categorySlug,
      city: location.city,
      latitude: location.latitude,
      longitude: location.longitude,
      radiusKm: location.hasCoordinates ? location.radiusKm : null,
      pincode: location.pincode,
      minCapacity: minCapacity,
    );
  }

  String _areaQuery() {
    final location = ref.read(discoveryLocationProvider);
    if (location.hasCity) return location.city!.trim();
    return location.pincode?.trim() ?? '';
  }

  void _openSearch({String? categorySlug, String? query, int? minCapacity}) {
    context.go(
      _located(
        categorySlug: categorySlug,
        query: query,
        minCapacity: minCapacity,
      ).searchLocation,
    );
  }

  void _openHalls() {
    final cats =
        ref.read(venueCategoriesProvider).valueOrNull ?? const <VenueCategory>[];
    const section = MainHomeSection.functionHalls;
    final slug = section.matchMaster(cats)?.slug ?? section.id;
    final guests = ref.read(discoveryBookingPrefsProvider).guests;
    _openSearch(categorySlug: slug, minCapacity: guests);
  }

  void _openStayList(String path) {
    final area = _areaQuery();
    context.push(
      area.isEmpty ? path : '$path?q=${Uri.encodeQueryComponent(area)}',
    );
  }

  void _submitSearch() {
    _openSearch(query: _query.text.trim());
  }

  Future<void> _pickCheckIn() async {
    final prefs = ref.read(discoveryBookingPrefsProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: prefs.day,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final notifier = ref.read(discoveryBookingPrefsProvider.notifier);
    notifier.setDate(picked);
    final next = ref.read(discoveryBookingPrefsProvider);
    if (!next.checkOutDay.isAfter(next.day)) {
      notifier.setCheckOut(next.day.add(const Duration(days: 1)));
    }
  }

  Future<void> _pickCheckOut() async {
    final prefs = ref.read(discoveryBookingPrefsProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: prefs.checkOutDay,
      firstDate: prefs.day.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null || !mounted) return;
    ref.read(discoveryBookingPrefsProvider.notifier).setCheckOut(picked);
  }

  Future<void> _pickGuests() async {
    final current = ref.read(discoveryBookingPrefsProvider).guests;
    final picked = await HomeGuestsPickerSheet.show(context, selected: current);
    if (picked == null || !mounted) return;
    ref.read(discoveryBookingPrefsProvider.notifier).setGuests(picked);
  }

  void _pickLocation() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: _dark ? const Color(0xFF12182B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const LocationPickerSheet(),
    );
  }

  void _openVenue(Venue venue) {
    ref.read(recentlyViewedProvider.notifier).record(venue);
    context.push(AppRoutes.venueDetails.replaceAll(':id', venue.id));
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(discoveryLocationProvider);
    final prefs = ref.watch(discoveryBookingPrefsProvider);
    final signedIn = ref.watch(authNotifierProvider).user != null;
    final nearby = ref.watch(nearbyVenuesProvider).valueOrNull ?? const <Venue>[];
    final popular =
        ref.watch(popularVenuesProvider).valueOrNull ?? const <Venue>[];
    final venues = nearby.isNotEmpty ? nearby : popular;
    final ink = _dark ? Colors.white : const Color(0xFF1B1548);
    final muted = _dark ? const Color(0xFFC9D0E8) : const Color(0xFF6B6490);

    return Scaffold(
      key: Key(_dark ? 'choice-home-life' : 'choice-home-moment'),
      backgroundColor: _dark ? const Color(0xFF070B18) : const Color(0xFFF6F4FF),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                dark: _dark,
                location: location,
                signedIn: signedIn,
                onLocation: _pickLocation,
                onNotifications: () => context.go(AppRoutes.notifications),
                onProfile: () => signedIn
                    ? context.go(AppRoutes.profile)
                    : context.push(AppRoutes.login),
              ),
            ),
            SliverToBoxAdapter(child: _Hero(dark: _dark)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _SearchCard(
                  dark: _dark,
                  controller: _query,
                  hint: _dark
                      ? 'Search spaces, locations...'
                      : 'Search for halls, PGs, hotels, classes...',
                  checkIn: prefs.day,
                  checkOut: prefs.checkOutDay,
                  guests: prefs.guests,
                  onCheckIn: _pickCheckIn,
                  onCheckOut: _pickCheckOut,
                  onGuests: _pickGuests,
                  onSearch: _submitSearch,
                ),
              ),
            ),
            if (_dark)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _LifeCategoryPills(),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _SpotlightRow(
                  dark: _dark,
                  onHalls: _openHalls,
                  onPg: () => _openStayList(AppRoutes.pgList),
                  onClasses: () => context.push(AppRoutes.education),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                child: _QuickRow(
                  dark: _dark,
                  onHotels: () => _openStayList(AppRoutes.staysList),
                  onEvents: () => context.push(AppRoutes.eventsList),
                  onMeetings: () => _openSearch(query: 'Meetings'),
                  onConferences: () => _openSearch(query: 'Conferences'),
                  onParties: () => _openSearch(query: 'Parties'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dark ? 'Trending Spaces' : 'Featured Near You',
                        key: const Key('choice-home-featured-title'),
                        style: TextStyle(
                          color: ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('choice-home-view-all'),
                      onPressed: () => _openSearch(),
                      child: Text(
                        _dark ? 'See All' : 'View All',
                        style: TextStyle(
                          color: _dark
                              ? const Color(0xFFC4B5FD)
                              : const Color(0xFF6D28D9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: venues.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      child: Text(
                        'Spaces near you will show here.',
                        key: const Key('choice-home-empty'),
                        style: TextStyle(color: muted),
                      ),
                    )
                  : SizedBox(
                      height: 228,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: venues.length.clamp(0, 8),
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final venue = venues[index];
                          return _VenueTile(
                            venue: venue,
                            dark: _dark,
                            onTap: () => _openVenue(venue),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dark,
    required this.location,
    required this.signedIn,
    required this.onLocation,
    required this.onNotifications,
    required this.onProfile,
  });

  final bool dark;
  final DiscoveryLocation location;
  final bool signedIn;
  final VoidCallback onLocation;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xFF1B1548);
    final muted = dark ? const Color(0xFFB7C0DC) : const Color(0xFF7A749C);
    final region = (location.state != null && location.state!.trim().isNotEmpty)
        ? location.state!.trim()
        : 'India';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('choice-home-location'),
              onTap: onLocation,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFF7C3AED), size: 20),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            region,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BookMySpaceMark(size: 22),
              const SizedBox(width: 4),
              BookMySpaceWordmark(
                fontSize: 13,
                textColor: dark ? Colors.white : null,
              ),
            ],
          ),
          IconButton(
            key: const Key('choice-home-notifications'),
            visualDensity: VisualDensity.compact,
            onPressed: onNotifications,
            icon: Icon(Icons.notifications_none_rounded, color: ink),
          ),
          IconButton(
            key: const Key('choice-home-profile'),
            visualDensity: VisualDensity.compact,
            onPressed: onProfile,
            icon: Icon(
              signedIn ? Icons.account_circle : Icons.account_circle_outlined,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (dark) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spaces for\nYour Life',
              key: Key('choice-home-title'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                height: 1.02,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Book. Learn. Stay. Celebrate.',
              style: TextStyle(
                color: Color(0xFFD5DCF2),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Space\nfor Every Moment',
            key: Key('choice-home-title'),
            style: TextStyle(
              color: Color(0xFF24185F),
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Book Halls, PGs, Hotels, Classes and more...',
            style: TextStyle(
              color: Color(0xFF5C567E),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.dark,
    required this.controller,
    required this.hint,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onGuests,
    required this.onSearch,
  });

  final bool dark;
  final TextEditingController controller;
  final String hint;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onGuests;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    final fill = dark ? const Color(0xFF141A2E) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF1B1548);
    final muted = dark ? const Color(0xFF9AA6C7) : const Color(0xFF8A84A8);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(28),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x146D28D9),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
        border: Border.all(
          color: dark ? const Color(0xFF2A3354) : const Color(0xFFE7E3F7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          children: [
            TextField(
              key: const Key('choice-home-search'),
              controller: controller,
              style: TextStyle(color: ink),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: muted),
                prefixIcon: Icon(Icons.search_rounded, color: muted),
                filled: true,
                fillColor: dark ? const Color(0xFF0E1426) : const Color(0xFFF7F6FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateChip(
                    key: const Key('choice-home-check-in'),
                    label: 'Check In',
                    value: dateFormat.format(checkIn),
                    dark: dark,
                    onTap: onCheckIn,
                  ),
                ),
                Expanded(
                  child: _DateChip(
                    key: const Key('choice-home-check-out'),
                    label: 'Check Out',
                    value: dateFormat.format(checkOut),
                    dark: dark,
                    onTap: onCheckOut,
                  ),
                ),
                Expanded(
                  child: _DateChip(
                    key: const Key('choice-home-guests'),
                    label: 'Guests',
                    value: '$guests Guest${guests == 1 ? '' : 's'}',
                    dark: dark,
                    icon: Icons.people_alt_outlined,
                    onTap: onGuests,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextButton(
                  key: const Key('choice-home-search-button'),
                  onPressed: onSearch,
                  child: const Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    super.key,
    required this.label,
    required this.value,
    required this.dark,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
  });

  final String label;
  final String value;
  final bool dark;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xFF1B1548);
    final muted = dark ? const Color(0xFF9AA6C7) : const Color(0xFF8A84A8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: muted, fontSize: 10)),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifeCategoryPills extends StatelessWidget {
  const _LifeCategoryPills();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MiniPill(label: 'Weddings', color: Color(0xFFF472B6)),
        _MiniPill(label: 'PG Rooms', color: Color(0xFF60A5FA)),
        _MiniPill(label: 'Classes', color: Color(0xFF34D399)),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

class _SpotlightRow extends StatelessWidget {
  const _SpotlightRow({
    required this.dark,
    required this.onHalls,
    required this.onPg,
    required this.onClasses,
  });

  final bool dark;
  final VoidCallback onHalls;
  final VoidCallback onPg;
  final VoidCallback onClasses;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Spot(
        keyName: 'choice-home-halls',
        title: 'Function Halls',
        subtitle: dark ? 'Weddings & Events' : 'Weddings • Events • Parties',
        icon: Icons.account_balance_rounded,
        colors: const [Color(0xFFF472B6), Color(0xFFFB7185)],
        onTap: onHalls,
      ),
      _Spot(
        keyName: 'choice-home-pg',
        title: 'PGs & Stays',
        subtitle: dark ? 'Rooms • PG • Hostels' : 'Paying Guest • Rooms • Hostel',
        icon: Icons.apartment_rounded,
        colors: const [Color(0xFF60A5FA), Color(0xFF818CF8)],
        onTap: onPg,
      ),
      _Spot(
        keyName: 'choice-home-classes',
        title: 'Classes',
        subtitle: dark ? 'Learn & Grow' : 'Learn • Grow • Future',
        icon: Icons.school_rounded,
        colors: const [Color(0xFF34D399), Color(0xFF2DD4BF)],
        onTap: onClasses,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _SpotCard(spot: cards[i], dark: dark, tall: true)),
        ],
      ],
    );
  }
}

class _Spot {
  const _Spot({
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String keyName;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot, required this.dark, required this.tall});

  final _Spot spot;
  final bool dark;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tall ? 156 : 92,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key(spot.keyName),
        onTap: spot.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: spot.colors,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!dark)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Popular',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(spot.icon, color: Colors.white, size: 22),
                const SizedBox(height: 6),
                Text(
                  spot.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  spot.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.dark,
    required this.onHotels,
    required this.onEvents,
    required this.onMeetings,
    required this.onConferences,
    required this.onParties,
  });

  final bool dark;
  final VoidCallback onHotels;
  final VoidCallback onEvents;
  final VoidCallback onMeetings;
  final VoidCallback onConferences;
  final VoidCallback onParties;

  @override
  Widget build(BuildContext context) {
    final items = [
      (key: 'choice-home-hotels', label: 'Hotels', icon: Icons.apartment_rounded, onTap: onHotels),
      (key: 'choice-home-events', label: 'Events', icon: Icons.calendar_month_rounded, onTap: onEvents),
      (key: 'choice-home-meetings', label: 'Meetings', icon: Icons.groups_rounded, onTap: onMeetings),
      (key: 'choice-home-conferences', label: 'Conferences', icon: Icons.mic_rounded, onTap: onConferences),
      (key: 'choice-home-parties', label: 'Parties', icon: Icons.celebration_rounded, onTap: onParties),
    ];
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: InkWell(
              key: Key(item.key),
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF171E34) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: dark
                            ? null
                            : const [
                                BoxShadow(
                                  color: Color(0x146D28D9),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Icon(item.icon, color: const Color(0xFF7C3AED)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? Colors.white : const Color(0xFF1B1548),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({
    required this.venue,
    required this.dark,
    required this.onTap,
  });

  final Venue venue;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = venue.price > 0 ? venue.price : venue.pricingBaseAmount;
    final price = amount > 0
        ? NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          ).format(amount)
        : null;
    return SizedBox(
      width: 168,
      child: Material(
        color: dark ? const Color(0xFF141A2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('choice-home-venue-${venue.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: AppNetworkImage(
                  url: venue.coverOrSampleImageUrl,
                  height: 112,
                  width: 168,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? Colors.white : const Color(0xFF1B1548),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (venue.city.isNotEmpty)
                      Text(
                        venue.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark ? const Color(0xFF9AA6C7) : const Color(0xFF8A84A8),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (price != null)
                          Expanded(
                            child: Text(
                              price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dark ? Colors.white : const Color(0xFF1B1548),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (venue.avgRating > 0) ...[
                          const Icon(Icons.star_rounded, color: Color(0xFFF5B942), size: 16),
                          Text(
                            venue.avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: dark ? Colors.white : const Color(0xFF1B1548),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
