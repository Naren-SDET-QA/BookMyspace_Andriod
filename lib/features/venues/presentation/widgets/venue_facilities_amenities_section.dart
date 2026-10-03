import 'package:flutter/material.dart';

import '../../domain/venue.dart';

/// "Facilities & Amenities" section with icons, responsive wrap/scroll, and expand toggle.
class VenueFacilitiesAmenitiesSection extends StatefulWidget {
  const VenueFacilitiesAmenitiesSection({
    super.key,
    required this.facilities,
    required this.accent,
  });

  final List<VenueFacility> facilities;
  final Color accent;

  @override
  State<VenueFacilitiesAmenitiesSection> createState() =>
      _VenueFacilitiesAmenitiesSectionState();
}

class _VenueFacilitiesAmenitiesSectionState
    extends State<VenueFacilitiesAmenitiesSection> {
  bool _expanded = false;

  static const int _initialLimit = 8;

  static IconData _facilityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wifi') || lower.contains('internet')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('park') || lower.contains('car')) {
      return Icons.local_parking_rounded;
    }
    if (lower.contains('ac') || lower.contains('air') || lower.contains('cool')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('power') || lower.contains('generator') || lower.contains('backup')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('restroom') || lower.contains('washroom') || lower.contains('toilet')) {
      return Icons.wc_rounded;
    }
    if (lower.contains('sound') || lower.contains('speaker') || lower.contains('audio') || lower.contains('dj')) {
      return Icons.speaker_rounded;
    }
    if (lower.contains('cater') || lower.contains('food') || lower.contains('dining') || lower.contains('kitchen')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('security') || lower.contains('cctv') || lower.contains('guard')) {
      return Icons.security_rounded;
    }
    if (lower.contains('dress') || lower.contains('room') || lower.contains('suite') || lower.contains('bride')) {
      return Icons.meeting_room_rounded;
    }
    if (lower.contains('stage') || lower.contains('podium')) {
      return Icons.theater_comedy_rounded;
    }
    if (lower.contains('projector') || lower.contains('screen') || lower.contains('tv')) {
      return Icons.tv_rounded;
    }
    if (lower.contains('pool') || lower.contains('swim')) {
      return Icons.pool_rounded;
    }
    if (lower.contains('gym') || lower.contains('fitness')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('valet')) {
      return Icons.car_rental_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.facilities.where((f) => f.isAvailable).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasOverflow = available.length > _initialLimit;
    final displayed = (_expanded || !hasOverflow)
        ? available
        : available.take(_initialLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Facilities & Amenities',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasOverflow) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show Less' : 'View All (${available.length})'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayed.map((f) {
            final icon = _facilityIcon(f.facility);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width > 64
                    ? MediaQuery.sizeOf(context).width - 64
                    : 260,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: widget.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        f.facility,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
