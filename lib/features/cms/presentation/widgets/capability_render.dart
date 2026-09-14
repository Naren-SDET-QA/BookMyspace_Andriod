import 'package:flutter/material.dart';

import '../../domain/facility_capabilities.dart';

/// Customer-facing capability display widget.
///
/// Shows resolved capabilities in a clean, readable format.
/// Can be used in venue detail pages and booking flows.
class CapabilityRender extends StatelessWidget {
  const CapabilityRender({
    super.key,
    required this.capabilities,
    this.compact = false,
  });

  final FacilityCapabilities capabilities;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (capabilities.isEmpty) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _CompactRender(capabilities: capabilities);
    }

    return _FullRender(capabilities: capabilities);
  }
}

class _FullRender extends StatelessWidget {
  const _FullRender({required this.capabilities});
  final FacilityCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (capabilities.capacity != null) {
      items.add(_InfoRow(
        icon: Icons.people_outline,
        label: 'Capacity',
        value: '${capabilities.capacity} people',
      ));
    }

    if (capabilities.seating != null && capabilities.seating!.isNotEmpty) {
      items.add(_InfoRow(
        icon: Icons.chair_outlined,
        label: 'Seating',
        value: capabilities.seating!
            .map((s) => s.replaceAll('_', ' '))
            .join(', '),
      ));
    }

    if (capabilities.amenities != null && capabilities.amenities!.isNotEmpty) {
      items.add(_InfoRow(
        icon: Icons.star_outline,
        label: 'Amenities',
        value: capabilities.amenities!
            .map((a) => a.replaceAll('_', ' '))
            .join(', '),
      ));
    }

    if (capabilities.interactionMode != null) {
      items.add(_InfoRow(
        icon: _modeIcon(capabilities.interactionMode!),
        label: 'Booking',
        value: _modeLabel(capabilities.interactionMode!),
      ));
    }

    if (capabilities.approvalRequired == true) {
      items.add(_InfoRow(
        icon: Icons.approval_outlined,
        label: 'Approval',
        value: 'Required before confirmation',
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Facility Details',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  static IconData _modeIcon(InteractionMode mode) {
    switch (mode) {
      case InteractionMode.bookable:
        return Icons.calendar_today_outlined;
      case InteractionMode.registration:
        return Icons.how_to_reg_outlined;
      case InteractionMode.informationOnly:
        return Icons.info_outline;
    }
  }

  static String _modeLabel(InteractionMode mode) {
    switch (mode) {
      case InteractionMode.bookable:
        return 'Bookable online';
      case InteractionMode.registration:
        return 'Registration required';
      case InteractionMode.informationOnly:
        return 'Information only';
    }
  }
}

class _CompactRender extends StatelessWidget {
  const _CompactRender({required this.capabilities});
  final FacilityCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (capabilities.capacity != null) {
      chips.add(_CompactChip(
        icon: Icons.people_outline,
        label: '${capabilities.capacity}',
      ));
    }

    if (capabilities.interactionMode != null) {
      chips.add(_CompactChip(
        icon: _modeIcon(capabilities.interactionMode!),
        label: _modeLabel(capabilities.interactionMode!),
      ));
    }

    if (capabilities.approvalRequired == true) {
      chips.add(const _CompactChip(
        icon: Icons.approval_outlined,
        label: 'Approval req.',
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  static IconData _modeIcon(InteractionMode mode) {
    switch (mode) {
      case InteractionMode.bookable:
        return Icons.calendar_today_outlined;
      case InteractionMode.registration:
        return Icons.how_to_reg_outlined;
      case InteractionMode.informationOnly:
        return Icons.info_outline;
    }
  }

  static String _modeLabel(InteractionMode mode) {
    switch (mode) {
      case InteractionMode.bookable:
        return 'Bookable';
      case InteractionMode.registration:
        return 'Register';
      case InteractionMode.informationOnly:
        return 'Info only';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 14),
      label: Text(label, style: Theme.of(context).textTheme.bodySmall),
      padding: EdgeInsets.zero,
    );
  }
}
