import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/coupon.dart';
import '../coupon_providers.dart';

/// Screen displaying the authenticated customer's redeemed coupon and promo code history.
class PastCouponsScreen extends ConsumerWidget {
  const PastCouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final couponsAsync = ref.watch(customerRedeemedCouponsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Coupons Used'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(customerRedeemedCouponsProvider),
          ),
        ],
      ),
      body: user == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign In Required',
              message: 'Sign in to view your past redeemed coupons and savings history.',
            )
          : couponsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(height: 100, radius: 16),
                ),
              ),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(customerRedeemedCouponsProvider),
              ),
              data: (coupons) {
                if (coupons.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(customerRedeemedCouponsProvider.future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: EmptyState(
                            icon: Icons.local_offer_outlined,
                            title: 'No Coupons Used Yet',
                            message:
                                'When you apply promo codes and coupons during booking checkout, your discount details and savings will be tracked here.',
                            action: FilledButton.icon(
                              onPressed: () => _showAvailableCouponsModal(context, ref),
                              icon: const Icon(Icons.percent_rounded),
                              label: const Text('View Available Offers'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final totalSavings = coupons.fold<double>(
                  0.0,
                  (sum, item) => sum + item.discountAmount,
                );

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(customerRedeemedCouponsProvider.future),
                  child: ResponsiveLayoutBuilder(
                    builder: (context, responsive) {
                      return ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 16,
                        ),
                        children: [
                          // 1. Savings Summary Banner
                          _SavingsSummaryCard(
                            totalSavings: totalSavings,
                            couponCount: coupons.length,
                          ),
                          const SizedBox(height: 16),

                          // 2. Section Heading
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Redeemed Coupons (${coupons.length})',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showAvailableCouponsModal(context, ref),
                                  icon: const Icon(Icons.local_offer_rounded,
                                      size: 16),
                                  label: const Text('Active Offers'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 3. List of Redeemed Coupons
                          ...coupons.map(
                            (coupon) => _RedeemedCouponTile(coupon: coupon),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  void _showAvailableCouponsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => const _ActiveCouponsSheet(),
    );
  }
}

class _SavingsSummaryCard extends StatelessWidget {
  const _SavingsSummaryCard({
    required this.totalSavings,
    required this.couponCount,
  });

  final double totalSavings;
  final int couponCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A2F), const Color(0xFF12231C)]
              : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
              : const Color(0xFF81C784).withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                  : Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: Color(0xFF2E7D32),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lifetime Coupon Savings',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${totalSavings.toStringAsFixed(0)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  '$couponCount promo ${couponCount == 1 ? 'code' : 'codes'} successfully redeemed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
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

class _RedeemedCouponTile extends StatelessWidget {
  const _RedeemedCouponTile({required this.coupon});

  final RedeemedCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(coupon.redeemedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: coupon.bookingId.isNotEmpty
            ? () {
                context.push(
                  AppRoutes.bookingReceipt.replaceFirst(':id', coupon.bookingId),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Coupon Code Tag
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.violet.withValues(alpha: 0.4),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          size: 14,
                          color: AppTheme.violet,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          coupon.couponCode,
                          style: const TextStyle(
                            color: AppTheme.violet,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Discount Amount Tag
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-₹${coupon.discountAmount.toStringAsFixed(0)} SAVED',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (coupon.couponDescription.isNotEmpty) ...[
                Text(
                  coupon.couponDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // Venue and Booking info
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      coupon.venueName.isNotEmpty
                          ? coupon.venueName
                          : 'BookMySpace Booking',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Date & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          coupon.bookingStatus.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
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

class _ActiveCouponsSheet extends ConsumerWidget {
  const _ActiveCouponsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeAsync = ref.watch(activeCouponsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: AppTheme.violet),
                const SizedBox(width: 8),
                Text(
                  'Available Active Coupons',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            activeAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading offers: $e'),
              ),
              data: (offers) {
                if (offers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No active promo codes currently available.'),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: offers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = offers[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.violet.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.percent_rounded,
                            color: AppTheme.violet,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          c.code,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          c.description.isNotEmpty
                              ? c.description
                              : c.valueLabel,
                        ),
                        trailing: Text(
                          c.valueLabel,
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
