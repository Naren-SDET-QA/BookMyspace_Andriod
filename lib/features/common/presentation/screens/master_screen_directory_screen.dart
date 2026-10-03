import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/role_providers.dart';
import '../../../venues/presentation/venue_providers.dart';

enum ScreenDomain {
  all('All Screens', Icons.apps_rounded, Color(0xFF6366F1)),
  discovery('1. Discovery & Customer', Icons.travel_explore_rounded, Color(0xFF10B981)),
  booking('2. Booking Engine & Checkout', Icons.shopping_cart_checkout_rounded, Color(0xFFF59E0B)),
  owner('3. Owner & Partner Portal', Icons.storefront_rounded, Color(0xFF3B82F6)),
  education('4. Education & Institutes', Icons.school_rounded, Color(0xFF8B5CF6)),
  admin('5. Super Admin & CMS', Icons.admin_panel_settings_rounded, Color(0xFFEF4444)),
  supplementary('Supplementary & Tools', Icons.extension_rounded, Color(0xFF06B6D4));

  const ScreenDomain(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class ScreenDirectoryItem {
  const ScreenDirectoryItem({
    required this.domain,
    required this.name,
    required this.route,
    required this.audience,
    required this.description,
    required this.icon,
    this.demoParamRoute,
  });

  final ScreenDomain domain;
  final String name;
  final String route;
  final String audience;
  final String description;
  final IconData icon;
  final String? demoParamRoute;
}

const List<ScreenDirectoryItem> masterScreenCatalog = [
  // ==================== DOMAIN 1: Discovery & Customer-Facing ====================
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Home Discovery Screen',
    route: AppRoutes.home,
    audience: 'All Users / Customers',
    description: 'Hero booking intent cards, categories, flash discounts, near-you carousel, and city picker.',
    icon: Icons.home_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'India Location & Multi-Tier Discovery',
    route: AppRoutes.venueDiscovery,
    audience: 'All Users / Customers',
    description: 'Pan-India state hierarchy (Karnataka, Maharashtra, Delhi, etc.), multi-sport filter, and map toggle.',
    icon: Icons.travel_explore_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Venue Details & Facilities',
    route: AppRoutes.venueDetails,
    demoParamRoute: '/venues/5056d55e-e893-4218-8240-4368bb564200',
    audience: 'All Users / Customers',
    description: '3D Glass photo carousel, amenities list, pricing matrix, host profile, and instant hold trigger.',
    icon: Icons.location_city_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Reviews & Ratings',
    route: '/venues/:id/reviews',
    demoParamRoute: '/venues/5056d55e-e893-4218-8240-4368bb564200/reviews',
    audience: 'Verified Customers',
    description: 'Verified badge, star ratings breakdown, user testimonials, and photo attachment grid.',
    icon: Icons.star_rate_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Favorites & Saved Spaces',
    route: AppRoutes.saved,
    audience: 'Signed-in Customers',
    description: 'Bookmarked venues, quick-rebook shortcuts, and price-drop notifications.',
    icon: Icons.favorite_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Voice Search & AI Assistant',
    route: AppRoutes.assistant,
    audience: 'All Users',
    description: 'Voice speech-to-text input, natural language space querying, and conversational recommendations.',
    icon: Icons.mic_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Elderly / Simple Mode',
    route: AppRoutes.settings,
    audience: 'Seniors / Accessibility',
    description: 'High-contrast typography, 1-tap fast booking, and simplified navigation toggled via settings.',
    icon: Icons.accessibility_new_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Notification Hub',
    route: AppRoutes.notifications,
    audience: 'All Users',
    description: 'Booking confirmations, reminder countdowns, slot cancellations, and promotional alerts.',
    icon: Icons.notifications_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'App Preferences & Settings',
    route: AppRoutes.settings,
    audience: 'All Users',
    description: 'Language selector, notifications switches, dark/light theme, and security settings.',
    icon: Icons.tune_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.discovery,
    name: 'Theme Customizer',
    route: AppRoutes.themeCustomizer,
    audience: 'All Users',
    description: 'Live color accent changer, dark mode, high contrast mode, and dynamic palette tester.',
    icon: Icons.palette_rounded,
  ),

  // ==================== DOMAIN 2: Booking Engine & Checkout ====================
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Hold Timer & Court Selection',
    route: AppRoutes.bookingFlow,
    demoParamRoute: '/venues/5056d55e-e893-4218-8240-4368bb564200/book',
    audience: 'Active Bookers',
    description: 'Real-time 10-minute hold countdown, court selector pill matrix, and anti-sniping protection.',
    icon: Icons.timer_outlined,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Slot Picker & Conflict Resolution',
    route: AppRoutes.bookingFlow,
    demoParamRoute: '/venues/5056d55e-e893-4218-8240-4368bb564200/book',
    audience: 'Active Bookers',
    description: 'Interactive hourly slot grid, morning/evening filters, and instant lock prevention.',
    icon: Icons.calendar_month_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Function Hall Pricing & Addons',
    route: AppRoutes.bookingFlow,
    demoParamRoute: '/venues/5056d55e-e893-4218-8240-4368bb564200/book',
    audience: 'Event Bookers',
    description: 'Full-day/half-day slot toggle, guest capacity tier, catering, and sound equipment addons.',
    icon: Icons.celebration_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Booking Confirmation & Summary',
    route: AppRoutes.bookings,
    audience: 'Confirmed Bookers',
    description: 'Itemized fee breakdown, coupon discount chip, GST calculation, and venue address card.',
    icon: Icons.receipt_long_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Split Payments Flow',
    route: AppRoutes.paymentHistory,
    audience: 'Group Organizers',
    description: 'Invite co-players via WhatsApp/SMS, multi-link payment split, and group payment progress tracker.',
    icon: Icons.call_split_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Razorpay Checkout & Webhook',
    route: '/bookings/preview-booking/pay',
    demoParamRoute: AppRoutes.paymentHistory,
    audience: 'Paying Customers',
    description: 'UPI, Credit/Debit cards, Net Banking, fallback polling, and digital payment receipts.',
    icon: Icons.payment_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Active Booking Detail & QR Pass',
    route: AppRoutes.bookings,
    audience: 'Booked Customers',
    description: 'Cryptographic dynamic QR check-in pass, directions button, and cancel booking option.',
    icon: Icons.qr_code_2_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Cancel Booking & Refund Engine',
    route: AppRoutes.bookings,
    audience: 'Canceling Bookers',
    description: 'Tiered cancellation policy, refund estimation calculator, and automated wallet/bank credit.',
    icon: Icons.cancel_outlined,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.booking,
    name: 'Offline Booking Sync & Queue',
    route: AppRoutes.ownerOfflineBooking,
    audience: 'All Users & Staff',
    description: 'Background SQLite/cache queue, auto-sync when network returns, and conflict resilience.',
    icon: Icons.sync_problem_rounded,
  ),

  // ==================== DOMAIN 3: Owner & Partner Portal ====================
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Owner Registration & KYC',
    route: AppRoutes.ownerRegistration,
    audience: 'Prospective Venue Owners',
    description: 'GSTIN validation, bank account verification, business proof upload, and onboarding progress.',
    icon: Icons.badge_outlined,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Owner Dashboard & Revenue',
    route: AppRoutes.ownerDashboard,
    audience: 'Venue Owners & Managers',
    description: 'Today’s occupancy, gross revenue, upcoming bookings counter, and active courts summary.',
    icon: Icons.dashboard_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Add/Edit Venue & Facilities',
    route: AppRoutes.ownerVenueCreate,
    audience: 'Venue Owners',
    description: 'Multi-sport amenities picker, court dimension specs, photos uploader, and location pin.',
    icon: Icons.add_business_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Dynamic Pricing & Peak Hours',
    route: AppRoutes.adminBusinessPricing,
    audience: 'Venue Owners & Admins',
    description: 'Weekend surge pricing, morning discounts, festival surcharge, and custom rates by court.',
    icon: Icons.price_change_outlined,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Function Hall & Event Setup',
    route: AppRoutes.ownerVenueCreate,
    audience: 'Hall Owners',
    description: 'Full-day, morning, evening slot definitions, dining hall capacity, and package tariffs.',
    icon: Icons.event_seat_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Slot Availability & Blackout',
    route: AppRoutes.ownerAvailability,
    audience: 'Venue Owners',
    description: 'Calendar view to block slots for tournament, maintenance, or rain closures.',
    icon: Icons.event_busy_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Owner Bookings & Walk-ins',
    route: AppRoutes.ownerBookings,
    audience: 'Venue Staff & Owners',
    description: 'Real-time schedule grid, walk-in customer manual booking, and cash payment collection.',
    icon: Icons.book_online_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'QR Scanner & Rapid Check-in',
    route: AppRoutes.qrScanner,
    audience: 'Front-desk Staff',
    description: 'Camera QR reader, 1-second pass validation, attendance marking, and fraud warning alert.',
    icon: Icons.qr_code_scanner_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Owner Analytics & Trends',
    route: AppRoutes.analytics,
    audience: 'Venue Owners',
    description: 'Slot utilization rates, repeat customer retention curve, and popular hours breakdown.',
    icon: Icons.insights_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.owner,
    name: 'Owner Settlements & Payouts',
    route: AppRoutes.ownerPayments,
    audience: 'Venue Owners',
    description: 'Net balance, Razorpay Route transfer history, bank transfer requests, and commission breakdown.',
    icon: Icons.account_balance_rounded,
  ),

  // ==================== DOMAIN 4: Education & Academy Management ====================
  ScreenDirectoryItem(
    domain: ScreenDomain.education,
    name: 'Institutes & Classes Directory',
    route: AppRoutes.education,
    audience: 'Learners & Parents',
    description: 'Academy cards, coaching discipline filter (Badminton, Cricket, Swimming), and demo badges.',
    icon: Icons.school_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.education,
    name: 'Institute Profile & Facilities',
    route: AppRoutes.educationInstituteDetails,
    demoParamRoute: '/education/institutes/preview-demo-institute',
    audience: 'Learners & Parents',
    description: 'Facility photos, certified coach bios, batch schedules, syllabus, and trial booking button.',
    icon: Icons.account_balance_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.education,
    name: 'Class / Batch Details & Timetable',
    route: AppRoutes.coursesList,
    demoParamRoute: '/courses/preview-demo-course',
    audience: 'Enrolled Students',
    description: 'Weekly schedule grid, skill level (Beginner/Intermediate/Pro), and seat capacity.',
    icon: Icons.schedule_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.education,
    name: 'Student Enrollment & Fees',
    route: AppRoutes.coursesList,
    demoParamRoute: '/courses/preview-demo-course/enroll',
    audience: 'Learners & Parents',
    description: 'Monthly/quarterly fee selection, sibling discounts, online fee receipt, and student form.',
    icon: Icons.how_to_reg_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.education,
    name: 'Instructor Profile & Credentials',
    route: AppRoutes.instructorProfile,
    demoParamRoute: '/instructors/preview-demo-instructor',
    audience: 'Learners & Parents',
    description: 'NIS certifications, tournament achievements, teaching experience, and batch reviews.',
    icon: Icons.person_pin_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.education,
    name: 'Institute Owner Portal',
    route: AppRoutes.ownerInstituteDashboard,
    audience: 'Academy Directors',
    description: 'Batch student roster, attendance tracker, coach assignment, and tuition collection.',
    icon: Icons.business_center_rounded,
  ),

  // ==================== DOMAIN 5: Super Admin & CMS ====================
  ScreenDirectoryItem(
    domain: ScreenDomain.admin,
    name: 'Admin Dashboard & KPIs',
    route: AppRoutes.adminDashboard,
    audience: 'Super Admin Staff',
    description: 'Platform GMV, active users, pending venue approvals, critical alerts, and quick actions.',
    icon: Icons.admin_panel_settings_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.admin,
    name: 'User & Role Management (RBAC)',
    route: AppRoutes.adminUsers,
    audience: 'Super Admin',
    description: 'User listings, role promotion/revocation (Admin, Owner, Support, Staff), and ban actions.',
    icon: Icons.manage_accounts_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.admin,
    name: 'Venue Moderation & Blacklist',
    route: AppRoutes.adminVenues,
    audience: 'Platform Operations',
    description: 'Pending KYC review, document verification, inspection status, and platform suspension.',
    icon: Icons.verified_user_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.admin,
    name: 'Platform Settings & Dynamic Fees',
    route: AppRoutes.adminSettings,
    audience: 'Super Admin',
    description: 'Convenience fee %, GST configuration, cancellation rules, and module toggles.',
    icon: Icons.settings_suggest_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.admin,
    name: 'Audit Logs & Security Ledger',
    route: AppRoutes.adminAudit,
    audience: 'Compliance & Security',
    description: 'Immutable timeline of user promotions, pricing overrides, venue approvals, and refunds.',
    icon: Icons.history_edu_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.admin,
    name: 'System Health & Diagnostics',
    route: AppRoutes.adminHealth,
    audience: 'Site Reliability Engineering',
    description: 'Supabase connectivity, Razorpay API ping, OneSignal push status, and cache memory metrics.',
    icon: Icons.monitor_heart_rounded,
  ),

  // ==================== Supplementary Production Screens ====================
  ScreenDirectoryItem(
    domain: ScreenDomain.supplementary,
    name: 'Unified Registration & Multi-KYC',
    route: AppRoutes.unifiedRegistration,
    audience: 'All Roles',
    description: '1-step unified onboarding form covering customer, partner, academy, and enterprise roles.',
    icon: Icons.assignment_ind_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.supplementary,
    name: 'Plug & Play Features Hub',
    route: AppRoutes.featuresHub,
    audience: 'All Users',
    description: 'Interactive catalog of modular features: Maps, KYC, QR Check-in, AI Copilot, and Voice.',
    icon: Icons.extension_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.supplementary,
    name: 'Connected Apps, MCP & APIs',
    route: AppRoutes.connectedApps,
    audience: 'Developers & Partners',
    description: 'REST API tokens, Model Context Protocol (MCP) server endpoints, and webhook management.',
    icon: Icons.hub_rounded,
  ),
  ScreenDirectoryItem(
    domain: ScreenDomain.supplementary,
    name: 'Past Coupons & Savings',
    route: AppRoutes.pastCoupons,
    audience: 'Customers',
    description: 'Historical list of applied promotional codes and total savings accrued on BookMySpace.',
    icon: Icons.local_offer_rounded,
  ),
];

class MasterScreenDirectoryScreen extends ConsumerStatefulWidget {
  const MasterScreenDirectoryScreen({super.key});

  @override
  ConsumerState<MasterScreenDirectoryScreen> createState() =>
      _MasterScreenDirectoryScreenState();
}

class _MasterScreenDirectoryScreenState
    extends ConsumerState<MasterScreenDirectoryScreen> {
  ScreenDomain _selectedDomain = ScreenDomain.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Venue routes can use a live listing id. Every other parameterized
  /// place keeps its own demo path so an institute or class is not opened
  /// with a venue id. A demo path that is more specific than a shared list
  /// route opens that place directly.
  String _destinationFor(ScreenDirectoryItem item) {
    if (item.route.contains(':id')) {
      if (item.route.startsWith('/venues')) {
        final venues = ref.read(popularVenuesProvider).valueOrNull ?? [];
        final realId =
            venues.isNotEmpty ? venues.first.id : 'preview-demo-venue';
        return item.route.replaceAll(':id', realId);
      }
      return item.demoParamRoute ?? item.route;
    }
    final demo = item.demoParamRoute;
    if (demo != null && demo != item.route) return demo;
    return item.route;
  }

  void _navigateToScreen(ScreenDirectoryItem item) {
    final destination = _destinationFor(item);
    try {
      context.navigateSafely(destination);
    } catch (_) {
      final fallback = item.demoParamRoute;
      if (fallback != null && fallback != destination) {
        try {
          context.navigateSafely(fallback);
          return;
        } catch (_) {}
      }
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewModeActive = ref.watch(previewAllScreensModeProvider);

    final filtered = masterScreenCatalog.where((item) {
      if (_selectedDomain != ScreenDomain.all &&
          item.domain != _selectedDomain) {
        return false;
      }
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.route.toLowerCase().contains(q) ||
          item.audience.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Screen Directory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview Mode Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: previewModeActive
                  ? AppTheme.brand.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: previewModeActive
                      ? AppTheme.brand.withValues(alpha: 0.3)
                      : theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 520;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display All Screens Mode',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: previewModeActive ? AppTheme.brandDark : null,
                      ),
                    ),
                    Text(
                      previewModeActive
                          ? 'RoleGate bypass active: Admin and Owner portals are unlocked for review.'
                          : 'Turn this on to open Admin and Owner places on this device.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
                final toggle = Switch.adaptive(
                  value: previewModeActive,
                  onChanged: (val) {
                    ref.read(previewAllScreensModeProvider.notifier).state = val;
                  },
                );
                final icon = Icon(
                  previewModeActive
                      ? Icons.verified_user_rounded
                      : Icons.visibility_outlined,
                  color: previewModeActive
                      ? AppTheme.brandDark
                      : theme.colorScheme.primary,
                  size: 26,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          icon,
                          const SizedBox(width: 12),
                          Expanded(child: copy),
                        ],
                      ),
                      Align(alignment: Alignment.centerRight, child: toggle),
                    ],
                  );
                }
                return Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: copy),
                    toggle,
                  ],
                );
              },
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by screen title, route, or domain...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Every domain stays on screen. A horizontal strip clips the last
          // places on a phone and hides them from a mouse wheel on desktop.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chipTextWidth = math.max(80.0, constraints.maxWidth - 72);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in ScreenDomain.values)
                      _DomainChip(
                        domain: d,
                        count: d == ScreenDomain.all
                            ? masterScreenCatalog.length
                            : masterScreenCatalog
                                .where((item) => item.domain == d)
                                .length,
                        selected: _selectedDomain == d,
                        maxTextWidth: chipTextWidth,
                        onSelected: () => setState(() => _selectedDomain = d),
                      ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Screen List. One column on a phone, two from a tablet, three
          // on a wide desktop, so every place is reachable without a
          // single stretched card.
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'No screens match your query',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1200
                          ? 3
                          : constraints.maxWidth >= 800
                              ? 2
                              : 1;
                      final rowCount = (filtered.length / columns).ceil();
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: rowCount,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, row) {
                          final start = row * columns;
                          final end = math.min(start + columns, filtered.length);
                          final slice = filtered.sublist(start, end);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var column = 0; column < columns; column++) ...[
                                if (column > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: column < slice.length
                                      ? _ScreenCatalogCard(
                                          item: slice[column],
                                          onOpen: () => _navigateToScreen(slice[column]),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScreenCatalogCard extends StatelessWidget {
  const _ScreenCatalogCard({
    required this.item,
    required this.onOpen,
  });

  final ScreenDirectoryItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openButton = FilledButton.tonalIcon(
      onPressed: onOpen,
      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
      label: const Text('Open'),
      style: FilledButton.styleFrom(
        // Theme minimumSize is Size.fromHeight, which is infinite width.
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 460;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaPill(
                        label: item.domain.label,
                        color: item.domain.color,
                        background: item.domain.color.withValues(alpha: 0.1),
                      ),
                      _MetaPill(
                        label: item.audience,
                        color: theme.colorScheme.onSurfaceVariant,
                        background: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stacked) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DomainIcon(item: item),
                        const SizedBox(width: 12),
                        Expanded(child: heading),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DomainIcon(item: item),
                        const SizedBox(width: 14),
                        Expanded(child: heading),
                        const SizedBox(width: 12),
                        openButton,
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(
                    item.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Route: ${item.route}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (stacked) ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: openButton),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DomainIcon extends StatelessWidget {
  const _DomainIcon({required this.item});

  final ScreenDirectoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: item.domain.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(item.icon, color: item.domain.color, size: 24),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _DomainChip extends StatelessWidget {
  const _DomainChip({
    required this.domain,
    required this.count,
    required this.selected,
    required this.maxTextWidth,
    required this.onSelected,
  });

  final ScreenDomain domain;
  final int count;
  final bool selected;
  final double maxTextWidth;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      avatar: Icon(
        domain.icon,
        size: 16,
        color: selected ? Colors.white : domain.color,
      ),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxTextWidth),
        child: Text(
          '${domain.label} ($count)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
      selected: selected,
      selectedColor: domain.color,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(
        color: selected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

