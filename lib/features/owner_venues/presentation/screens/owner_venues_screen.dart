import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../venues/domain/venue.dart';
import '../providers/owner_venue_providers.dart';
import 'create_venue_screen.dart';

/// Owner spaces management screen listing all properties with edit, toggle, delete, and add actions.
class OwnerVenuesScreen extends ConsumerStatefulWidget {
  const OwnerVenuesScreen({super.key});

  @override
  ConsumerState<OwnerVenuesScreen> createState() => _OwnerVenuesScreenState();
}

class _OwnerVenuesScreenState extends ConsumerState<OwnerVenuesScreen> {
  Future<void> _confirmDelete(Venue venue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded,
              color: Colors.red, size: 36),
          title: const Text('Delete Space Listing?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to remove "${venue.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(deleteVenueProvider(venue.id).future);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${venue.name}" successfully.'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(Venue venue) async {
    final newStatus = !venue.isActive;
    try {
      await ref.read(
        updateVenueProvider((
          venueId: venue.id,
          isActive: newStatus,
          name: venue.name,
          categoryId: venue.category?.id ?? '',
          description: venue.description,
          city: venue.city,
          state: venue.state,
          latitude: venue.latitude,
          longitude: venue.longitude,
          capacity: venue.capacity,
          pricingBaseAmount: venue.pricingBaseAmount,
          address: venue.address,
          pincode: venue.pincode,
          images: venue.images,
          facilities: venue.facilities.map((f) => f.facility).toList(),
          videoUrl: null,
          tour3dUrl: null,
        )).future,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Listing is now LIVE & bookable! 🟢'
                  : 'Listing paused (Inactive) ⏸️',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myVenuesAsync = ref.watch(myVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Spaces & Properties 🏛️',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Listings',
            onPressed: () => ref.refresh(myVenuesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CreateVenueScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_business),
        label: const Text('List Space'),
      ),
      body: myVenuesAsync.when(
        data: (venues) {
          if (venues.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_business_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No spaces listed yet',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your banquet hall, conference room, lawn, or coworking space to start hosting bookings.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('List Your First Space'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateVenueScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          final totalActive = venues.where((v) => v.isActive).length;
          final avgPrice = venues.isEmpty
              ? 0
              : (venues
                          .map((v) => v.pricingBaseAmount)
                          .reduce((a, b) => a + b) /
                      venues.length)
                  .toInt();

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myVenuesProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Metrics Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        label: 'Total Spaces',
                        value: '${venues.length}',
                        icon: Icons.stadium,
                        theme: theme,
                      ),
                      Container(
                          width: 1,
                          height: 36,
                          color: theme.colorScheme.outlineVariant),
                      _buildMetric(
                        label: 'Active Listings',
                        value: '$totalActive',
                        icon: Icons.check_circle,
                        theme: theme,
                        valueColor: const Color(0xFF2E7D32),
                      ),
                      Container(
                          width: 1,
                          height: 36,
                          color: theme.colorScheme.outlineVariant),
                      _buildMetric(
                        label: 'Avg Base Rate',
                        value: '₹$avgPrice',
                        icon: Icons.currency_rupee,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Properties (${venues.length})',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...venues.map((venue) => _buildVenueCard(venue, theme)),
                const SizedBox(height: 72), // FAB spacing
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error loading spaces: $err'),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.refresh(myVenuesProvider),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildVenueCard(Venue venue, ThemeData theme) {
    final cover = venue.coverImageUrl.isNotEmpty
        ? venue.coverImageUrl
        : 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=1200&q=80';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Thumbnail
              SizedBox(
                width: 105,
                height: 105,
                child: Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.stadium),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              venue.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: venue.isActive
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              venue.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: venue.isActive
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${venue.city}${venue.state.isNotEmpty ? ', ${venue.state}' : ''}',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '₹${venue.pricingBaseAmount.toInt()} / slot',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  Max ${venue.capacity} guests',
                            style: const TextStyle(
                                fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          // Action Buttons: Edit, Toggle, Delete
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Space',
                      style: TextStyle(fontSize: 12.5)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateVenueScreen(existingVenue: venue),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _toggleActive(venue),
                      child: Text(
                        venue.isActive ? 'Pause' : 'Activate',
                        style: TextStyle(
                          fontSize: 12,
                          color: venue.isActive
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 18),
                      tooltip: 'Delete Space',
                      onPressed: () => _confirmDelete(venue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
