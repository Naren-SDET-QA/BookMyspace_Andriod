import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/language_picker_sheet.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../install/presentation/app_install_card.dart';
import '../../../location/presentation/screens/india_place_discovery_screen.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../rewards/domain/rewards.dart';
import '../../../rewards/presentation/rewards_providers.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../domain/app_role.dart';
import '../auth_providers.dart';
import '../role_providers.dart';
import '../widgets/edit_profile_modal.dart';

/// Full-featured Profile Screen with instant Edit Profile modal support,
/// account status, and Supabase profile synchronization.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final roles = ref.watch(currentUserRolesProvider).valueOrNull ?? {};
    final previewAll = ref.watch(previewAllScreensModeProvider);
    final isVenueOwner = roles.canManageVenues || previewAll;
    final isAdmin = roles.canViewAdminTools || previewAll;
    final bookings = ref.watch(myBookingsProvider);
    final saved = ref.watch(savedVenuesProvider);
    final signedIn = user != null || previewAll;
    final isInstituteOwner = roles.contains(AppRole.instituteOwner) || previewAll;
    final coursesEnabled = ref.watch(moduleEnabledProvider('courses'));
    final referralsEnabled = ref.watch(moduleEnabledProvider('referrals'));
    final analyticsEnabled = ref.watch(moduleEnabledProvider('analytics'));

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('profile-ai-help'),
        onPressed: () => context.push(AppRoutes.assistant),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI Help'),
      ),
      appBar: AppBar(
        title: Text(
          l10n.navProfile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveLayoutBuilder(
          builder: (context, responsive) {
            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.horizontalPadding,
                vertical: 16,
              ),
              children: [
                // Profile Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Stack(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.primaryContainer,
                                    border: Border.all(
                                      color: AppTheme.violet,
                                      width: 2.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: user?.avatarUrl.isNotEmpty == true
                                      ? AppNetworkImage(
                                          url: user!.avatarUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Text(
                                            user?.fullName.isNotEmpty == true
                                                ? user!.fullName[0]
                                                      .toUpperCase()
                                                : user?.email.isNotEmpty == true
                                                ? user!.email[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => EditProfileModal.show(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.violet,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),

                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.fullName.isNotEmpty == true
                                        ? user!.fullName
                                        : l10n.guest,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email.isNotEmpty == true
                                        ? user!.email
                                        : l10n.notSignedIn,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (user?.phone.isNotEmpty == true) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      user!.phone,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Edit Profile Button (Triggers EditProfileModal)
                        FilledButton.tonalIcon(
                          onPressed: () => EditProfileModal.show(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text(
                            'Edit Profile',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const _RoleSwitcherSection(),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'My Bookings',
                        count: bookings.maybeWhen(
                          data: (items) =>
                              '${items.where((booking) => booking.isActive).length} active',
                          orElse: () => '—',
                        ),
                        color: AppTheme.violet,
                        onTap: () => context.go(AppRoutes.bookings),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.favorite_rounded,
                        title: 'Saved Spaces',
                        count: saved.maybeWhen(
                          data: (items) => '${items.length} saved',
                          orElse: () => '—',
                        ),
                        color: Colors.pink,
                        onTap: () => context.go(AppRoutes.saved),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const AppInstallCard(),

                if (signedIn) ...[
                  _WalletHighlight(
                    onOpen: () => context.push(AppRoutes.wallet),
                  ),
                  if (referralsEnabled)
                    _ReferHighlight(
                      onOpen: () => context.push(AppRoutes.referrals),
                    ),
                ],
                const _SectionHeader('Bookings & payments'),
                if (signedIn)
                  _ProfileMenuTile(
                    key: const Key('profile-payment-history'),
                    icon: Icons.receipt_long_outlined,
                    title: 'Payments & Receipts',
                    subtitle: 'Payment history, status, and receipts',
                    onTap: () => context.push(AppRoutes.paymentHistory),
                  ),
                _ProfileMenuTile(
                  key: const Key('profile-past-coupons'),
                  icon: Icons.local_offer_outlined,
                  title: 'Coupons & Savings',
                  subtitle:
                      'Redeemed coupon codes, discounts, and savings history',
                  onTap: () => context.push(AppRoutes.pastCoupons),
                ),
                if (signedIn)
                  _ProfileMenuTile(
                    key: const Key('profile-usage-analytics'),
                    icon: Icons.insights_outlined,
                    title: 'My Spending',
                    subtitle: 'Your bookings and spending over time',
                    onTap: () => context.push(AppRoutes.customerAnalytics),
                  ),

                const _SectionHeader('Explore'),
                _ProfileMenuTile(
                  key: const Key('profile-location-discovery'),
                  icon: Icons.travel_explore_outlined,
                  title: 'Browse by Location',
                  subtitle: 'State, district, mandal, town, and PIN search',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const IndiaPlaceDiscoveryScreen(),
                    ),
                  ),
                ),
                _ProfileMenuTile(
                  key: const Key('profile-events'),
                  icon: Icons.event_available_outlined,
                  title: 'Upcoming Events',
                  subtitle: 'Workshops, concerts, and community events',
                  onTap: () => context.push(AppRoutes.eventsList),
                ),
                if (coursesEnabled)
                  _ProfileMenuTile(
                    key: const Key('profile-institutes-directory'),
                    icon: Icons.school_outlined,
                    title: 'Courses & Institutes',
                    subtitle: 'Coaching, academies, batches, and enrollments',
                    onTap: () => context.push(AppRoutes.education),
                  ),

                const _SectionHeader('Preferences'),
                _ProfileMenuTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications & Alerts',
                  subtitle: 'Booking updates, reminders, and offers',
                  onTap: () => context.go(AppRoutes.notifications),
                ),
                _LanguageRow(
                  locale: ref.watch(localeProvider),
                  onTap: () => showLanguagePickerSheet(
                    context,
                    ref,
                    keyPrefix: 'profile-language',
                  ),
                ),
                _SwitchRow(
                  switchKey: const Key('profile-simple-mode'),
                  icon: Icons.accessibility_new_rounded,
                  title: 'Simple Mode',
                  subtitle:
                      'Hides complex filters, enlarges text, and keeps booking to one tap',
                  value: ref.watch(simpleModeProvider),
                  onChanged: (enabled) => ref
                      .read(simpleModeProvider.notifier)
                      .setEnabled(enabled),
                ),
                _SwitchRow(
                  switchKey: const Key('profile-quick-book'),
                  icon: Icons.flash_on_rounded,
                  title: 'Quick Booking',
                  subtitle: ref.watch(bookingModeProvider) == BookingMode.quick
                      ? 'On: 1-tap quick booking is applied'
                      : 'Off: the full booking steps stay available',
                  value: ref.watch(bookingModeProvider) == BookingMode.quick,
                  onChanged: (enabled) => ref
                      .read(bookingModeProvider.notifier)
                      .setMode(
                        enabled ? BookingMode.quick : BookingMode.normal,
                      ),
                ),
                _ThemeModeRow(
                  mode: ref.watch(themeModeProvider),
                  onMode: (mode) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(mode),
                  onOpenThemes: () => context.push(AppRoutes.themeCustomizer),
                ),
                _ProfileMenuTile(
                  icon: Icons.tune_rounded,
                  title: 'All Settings',
                  subtitle: 'Privacy, security, and display options',
                  onTap: () => context.push(AppRoutes.settings),
                ),

                if (signedIn) ...[
                  const _SectionHeader('Business'),
                  _ProfileMenuTile(
                    key: const Key('profile-partner-hub'),
                    icon: Icons.storefront_outlined,
                    title: isVenueOwner
                        ? 'Partner / Venue Owner Hub'
                        : 'Become a Venue Partner',
                    subtitle: isVenueOwner
                        ? 'Venues, bookings, availability, and payouts'
                        : 'List your spaces, halls, and classes',
                    onTap: () => context.push(
                      isVenueOwner
                          ? AppRoutes.ownerDashboard
                          : AppRoutes.ownerRegistration,
                    ),
                  ),
                  if (coursesEnabled && (isInstituteOwner || isAdmin))
                    _ProfileMenuTile(
                      key: const Key('profile-institute-portal'),
                      icon: Icons.school_outlined,
                      title: l10n.instituteOwnerPortal,
                      subtitle:
                          'Faculty, batches, admissions and demo sessions',
                      onTap: () =>
                          context.push(AppRoutes.ownerInstituteDashboard),
                    ),
                  if (analyticsEnabled && (isVenueOwner || isAdmin))
                    _ProfileMenuTile(
                      key: const Key('profile-owner-analytics'),
                      icon: Icons.insights_outlined,
                      title: l10n.analytics,
                      subtitle: 'Bookings, revenue and occupancy trends',
                      onTap: () => context.push(AppRoutes.analytics),
                    ),
                  _ProfileMenuTile(
                    key: const Key('profile-kyc-registration'),
                    icon: Icons.assignment_ind_outlined,
                    title: 'Registration & KYC',
                    subtitle:
                        'Host, academy, and identity verification details',
                    onTap: () => context.push(AppRoutes.unifiedRegistration),
                  ),
                  if (isVenueOwner || isInstituteOwner || isAdmin)
                    _ProfileMenuTile(
                      key: const Key('profile-connected-apps'),
                      icon: Icons.hub_outlined,
                      title: 'Connected Apps & APIs',
                      subtitle:
                          'API keys, webhooks, MCP, and calendar export',
                      onTap: () => context.push(AppRoutes.connectedApps),
                    ),
                ],

                if (isAdmin || roles.contains(AppRole.supportAgent)) ...[
                  const _SectionHeader('Administration'),
                  if (isAdmin)
                    _ProfileMenuTile(
                      key: const Key('profile-admin-console'),
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin Console',
                      subtitle:
                          'Users, venues, settings, audit logs, and system health',
                      onTap: () => context.push(AppRoutes.adminDashboard),
                    ),
                  if (roles.contains(AppRole.supportAgent) && !isAdmin)
                    _ProfileMenuTile(
                      icon: Icons.support_agent_outlined,
                      title: l10n.support,
                      subtitle: 'Tickets your support role can read',
                      onTap: () => context.push(AppRoutes.adminSupport),
                    ),
                ],

                const _SectionHeader('Help'),
                _ProfileMenuTile(
                  key: const Key('profile-help-support'),
                  icon: Icons.support_agent_outlined,
                  title: 'Help & Support',
                  subtitle: 'FAQs, support desk, and booking help',
                  onTap: () => context.push(AppRoutes.support),
                ),

                // Internal QA tools. Never shown in profile/release builds.
                if (kDebugMode) ...[
                  const _SectionHeader('Developer tools'),
                  _ProfileMenuTile(
                    key: const Key('profile-screen-directory'),
                    icon: Icons.grid_view_rounded,
                    title: 'Screen Directory',
                    subtitle: 'Debug only: preview every screen',
                    onTap: () => context.push(AppRoutes.screenDirectory),
                  ),
                  _ProfileMenuTile(
                    key: const Key('profile-features-hub'),
                    icon: Icons.extension_outlined,
                    title: 'Features Hub',
                    subtitle: 'Debug only: modular feature catalog',
                    onTap: () => context.push(AppRoutes.featuresHub),
                  ),
                ],
                const SizedBox(height: 16),

                // Sign out button
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                count,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // BMS2-style glass tile: translucent white surface with a soft violet
    // icon orb, matching the settings screen and the approved reference.
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletHighlight extends ConsumerWidget {
  const _WalletHighlight({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(walletEntriesProvider);
    final summary = entries.maybeWhen(
      data: WalletSummary.fromEntries,
      orElse: () => null,
    );
    final balance = summary == null
        ? (entries.isLoading ? '…' : '—')
        : _rupees(summary.balance);
    return _HighlightCard(
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'BookMySpace Wallet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (summary != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$balance available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Usable on advance bookings and discounts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: const Key('profile-wallet-redeem'),
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              // Theme minimumSize is Size.fromHeight, which is infinite width.
              // That stretches a button in a column and crashes inside a Row.
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }
}

class _ReferHighlight extends ConsumerWidget {
  const _ReferHighlight({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(referralSummaryProvider).valueOrNull;
    final code = summary?.code.isNotEmpty == true ? summary!.code : '—';
    return _HighlightCard(
      onTap: onOpen,
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Refer & Earn',
                  key: Key('profile-refer-earn'),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('Your code: $code'),
                Text(
                  'Reward credits post to your wallet when a referral qualifies',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy referral link',
            onPressed: summary == null
                ? onOpen
                : () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'https://bookmyspace.app/register?ref=${summary.code}',
                      ),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral link copied')),
                    );
                  },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.locale, required this.onTap});

  final Locale locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProfileMenuTile(
      key: const Key('profile-language'),
      icon: Icons.language_rounded,
      title: 'App Language / भाषा',
      subtitle:
          '${languageEnglishName(locale)} · navigation and voice readouts',
      onTap: onTap,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return _ProfileMenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
        key: switchKey,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({
    required this.mode,
    required this.onMode,
    required this.onOpenThemes,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;
  final VoidCallback onOpenThemes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onOpenThemes,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme & Color Engine',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '12 themes, a custom accent, and System, Light, or Dark',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                key: const Key('profile-theme-mode'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    (ThemeMode.system, 'System'),
                    (ThemeMode.light, 'Light'),
                    (ThemeMode.dark, 'Dark'),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: mode == option.$1,
                      onSelected: (_) => onMode(option.$1),
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

String _rupees(double value) {
  if (value == value.roundToDouble()) return '₹${value.toStringAsFixed(0)}';
  return '₹${value.toStringAsFixed(2)}';
}

class _RoleSwitcherSection extends ConsumerWidget {
  const _RoleSwitcherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeRole = ref.watch(activeDevRoleProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Switch Role (DEV Testing Mode)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select role to test Customer, Owner, or Admin permissions:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                key: const Key('role_switch_customer'),
                avatar: const Icon(Icons.person_outline_rounded, size: 16),
                label: const Text('Customer'),
                selected: activeRole == DevRole.customer || activeRole == null,
                onSelected: (_) {
                  ref.read(activeDevRoleProvider.notifier).state =
                      DevRole.customer;
                },
              ),
              FilterChip(
                key: const Key('role_switch_owner'),
                avatar: const Icon(Icons.storefront_outlined, size: 16),
                label: const Text('Venue Owner'),
                selected: activeRole == DevRole.venueOwner,
                onSelected: (_) {
                  ref.read(activeDevRoleProvider.notifier).state =
                      DevRole.venueOwner;
                },
              ),
              FilterChip(
                key: const Key('role_switch_admin'),
                avatar: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                label: const Text('Admin'),
                selected: activeRole == DevRole.admin,
                onSelected: (_) {
                  ref.read(activeDevRoleProvider.notifier).state =
                      DevRole.admin;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
