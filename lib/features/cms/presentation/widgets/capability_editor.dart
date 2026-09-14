import 'package:flutter/material.dart';

import '../../domain/facility_capabilities.dart';

/// Reusable editor widget for facility capabilities.
///
/// Used in both admin catalog editor and owner facility builder.
/// Admins see all fields plus constraint configuration.
/// Owners see only the fields they can configure within constraints.
class CapabilityEditor extends StatelessWidget {
  const CapabilityEditor({
    super.key,
    required this.capabilities,
    required this.onChanged,
    this.constraints,
    this.isOwner = false,
    this.readOnly = false,
  });

  final FacilityCapabilities capabilities;
  final ValueChanged<FacilityCapabilities> onChanged;
  final CapabilityConstraints? constraints;
  final bool isOwner;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        _SectionHeader(title: 'Capabilities'),
        const SizedBox(height: 12),
        _CapacityField(
          capacity: capabilities.capacity,
          constraints: constraints?.capacity,
          readOnly: readOnly,
          onChanged: (v) => _update(capabilities: FacilityCapabilities(
            capacity: v,
            seating: capabilities.seating,
            availability: capabilities.availability,
            timeSlots: capabilities.timeSlots,
            amenities: capabilities.amenities,
            interactionMode: capabilities.interactionMode,
            approvalRequired: capabilities.approvalRequired,
          )),
        ),
        const SizedBox(height: 16),
        _SeatingField(
          seating: capabilities.seating ?? const [],
          constraints: constraints?.seating,
          readOnly: readOnly,
          onChanged: (v) => _update(capabilities: FacilityCapabilities(
            capacity: capabilities.capacity,
            seating: v.isEmpty ? null : v,
            availability: capabilities.availability,
            timeSlots: capabilities.timeSlots,
            amenities: capabilities.amenities,
            interactionMode: capabilities.interactionMode,
            approvalRequired: capabilities.approvalRequired,
          )),
        ),
        const SizedBox(height: 16),
        _AmenitiesField(
          amenities: capabilities.amenities ?? const [],
          constraints: constraints?.amenities,
          readOnly: readOnly,
          onChanged: (v) => _update(capabilities: FacilityCapabilities(
            capacity: capabilities.capacity,
            seating: capabilities.seating,
            availability: capabilities.availability,
            timeSlots: capabilities.timeSlots,
            amenities: v.isEmpty ? null : v,
            interactionMode: capabilities.interactionMode,
            approvalRequired: capabilities.approvalRequired,
          )),
        ),
        const SizedBox(height: 16),
        _InteractionModeField(
          mode: capabilities.interactionMode ?? InteractionMode.informationOnly,
          allowedModes: constraints?.allowedModes,
          readOnly: readOnly,
          onChanged: (v) => _update(capabilities: FacilityCapabilities(
            capacity: capabilities.capacity,
            seating: capabilities.seating,
            availability: capabilities.availability,
            timeSlots: capabilities.timeSlots,
            amenities: capabilities.amenities,
            interactionMode: v,
            approvalRequired: capabilities.approvalRequired,
          )),
        ),
        const SizedBox(height: 16),
        if (!isOwner || (constraints?.lockApprovalRequired != true))
          _ApprovalField(
            required: capabilities.approvalRequired ?? false,
            readOnly: readOnly || (isOwner && constraints?.lockApprovalRequired == true),
            onChanged: (v) => _update(capabilities: FacilityCapabilities(
              capacity: capabilities.capacity,
              seating: capabilities.seating,
              availability: capabilities.availability,
              timeSlots: capabilities.timeSlots,
              amenities: capabilities.amenities,
              interactionMode: capabilities.interactionMode,
              approvalRequired: v,
            )),
          ),
        ],
      ),
    );
  }

  void _update({required FacilityCapabilities capabilities}) {
    onChanged(capabilities);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _CapacityField extends StatelessWidget {
  const _CapacityField({
    required this.capacity,
    this.constraints,
    required this.readOnly,
    required this.onChanged,
  });

  final int? capacity;
  final IntConstraint? constraints;
  final bool readOnly;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: capacity?.toString() ?? '',
      decoration: InputDecoration(
        labelText: 'Capacity',
        border: const OutlineInputBorder(),
        helperText: _helperText,
        counterText: '',
      ),
      keyboardType: TextInputType.number,
      readOnly: readOnly,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final parsed = int.tryParse(value.trim());
        if (parsed == null) return 'Enter a whole number.';
        if (parsed <= 0) return 'Must be positive.';
        if (constraints != null) {
          return constraints!.validate(parsed, 'Capacity');
        }
        return null;
      },
      onChanged: (value) {
        if (value.trim().isEmpty) {
          onChanged(null);
          return;
        }
        final parsed = int.tryParse(value.trim());
        if (parsed != null && parsed > 0) onChanged(parsed);
      },
    );
  }

  String get _helperText {
    final parts = <String>['Max occupancy.'];
    if (constraints != null) {
      if (constraints!.min != null) parts.add('Min: ${constraints!.min}');
      if (constraints!.max != null) parts.add('Max: ${constraints!.max}');
      if (constraints!.step != null) parts.add('Step: ${constraints!.step}');
    }
    return parts.join(' ');
  }
}

class _SeatingField extends StatelessWidget {
  const _SeatingField({
    required this.seating,
    this.constraints,
    required this.readOnly,
    required this.onChanged,
  });

  final List<String> seating;
  final ListConstraint? constraints;
  final bool readOnly;
  final ValueChanged<List<String>> onChanged;

  static const _presets = [
    'theater',
    'round_table',
    'classroom',
    'boardroom',
    'u_shape',
    'hollow_square',
    'crescent',
    'banquet',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Seating Options', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in _presets)
              FilterChip(
                label: Text(option.replaceAll('_', ' ')),
                selected: seating.contains(option),
                onSelected: readOnly
                    ? null
                    : (selected) {
                        final next = List<String>.from(seating);
                        if (selected) {
                          if (constraints == null ||
                              constraints!.isAllowed(option)) {
                            next.add(option);
                          }
                        } else {
                          next.remove(option);
                        }
                        onChanged(next);
                      },
              ),
          ],
        ),
        if (constraints?.maxItems != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Max ${constraints!.maxItems} options.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _AmenitiesField extends StatelessWidget {
  const _AmenitiesField({
    required this.amenities,
    this.constraints,
    required this.readOnly,
    required this.onChanged,
  });

  final List<String> amenities;
  final ListConstraint? constraints;
  final bool readOnly;
  final ValueChanged<List<String>> onChanged;

  static const _presets = [
    'ac',
    'parking',
    'wifi',
    'catering',
    'sound_system',
    'projector',
    'stage',
    'lighting',
    'restrooms',
    'changing_room',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Amenities', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in _presets)
              FilterChip(
                label: Text(option.replaceAll('_', ' ')),
                selected: amenities.contains(option),
                onSelected: readOnly
                    ? null
                    : (selected) {
                        final next = List<String>.from(amenities);
                        if (selected) {
                          if (constraints == null ||
                              constraints!.isAllowed(option)) {
                            next.add(option);
                          }
                        } else {
                          next.remove(option);
                        }
                        onChanged(next);
                      },
              ),
          ],
        ),
        if (constraints?.maxItems != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Max ${constraints!.maxItems} items.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _InteractionModeField extends StatelessWidget {
  const _InteractionModeField({
    required this.mode,
    this.allowedModes,
    required this.readOnly,
    required this.onChanged,
  });

  final InteractionMode mode;
  final List<InteractionMode>? allowedModes;
  final bool readOnly;
  final ValueChanged<InteractionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final modes = allowedModes ?? InteractionMode.values;
    return DropdownButtonFormField<InteractionMode>(
      initialValue: mode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Interaction Mode',
        border: OutlineInputBorder(),
        helperText: 'How customers interact with this facility.',
      ),
      items: [
        for (final m in modes)
          DropdownMenuItem(
            value: m,
            child: Text(_labelFor(m)),
          ),
      ],
      onChanged: readOnly
          ? null
          : (next) {
              if (next != null) onChanged(next);
            },
    );
  }

  static String _labelFor(InteractionMode mode) {
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

class _ApprovalField extends StatelessWidget {
  const _ApprovalField({
    required this.required,
    required this.readOnly,
    required this.onChanged,
  });

  final bool required;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Approval Required'),
      subtitle: Text(
        required
            ? 'Bookings require owner/admin approval before confirmation.'
            : 'Bookings are confirmed automatically.',
      ),
      value: required,
      onChanged: readOnly ? null : onChanged,
    );
  }
}
