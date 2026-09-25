import 'package:flutter/foundation.dart';

/// Interaction modes for a facility node.
enum InteractionMode {
  bookable,
  registration,
  informationOnly;

  static InteractionMode fromJson(String? value) {
    if (value == null) return InteractionMode.informationOnly;
    return InteractionMode.values.asNameMap()[value] ??
        InteractionMode.informationOnly;
  }

  String toJson() => name;
}

/// Integer constraint with min, max, and step.
@immutable
class IntConstraint {
  const IntConstraint({this.min, this.max, this.step});

  final int? min;
  final int? max;
  final int? step;

  bool isValid(int value) {
    if (min != null && value < min!) return false;
    if (max != null && value > max!) return false;
    if (step != null && step! > 0) {
      final base = min ?? 0;
      if ((value - base) % step! != 0) return false;
    }
    return true;
  }

  String? validate(int value, String label) {
    if (min != null && value < min!) {
      return '$label must be at least $min.';
    }
    if (max != null && value > max!) {
      return '$label must be at most $max.';
    }
    if (step != null && step! > 0) {
      final base = min ?? 0;
      if ((value - base) % step! != 0) {
        return '$label must be in steps of $step from $base.';
      }
    }
    return null;
  }

  static IntConstraint? fromJson(Object? json) {
    if (json is! Map) return null;
    return IntConstraint(
      min: _readInt(json['min']),
      max: _readInt(json['max']),
      step: _readInt(json['step']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (step != null) 'step': step,
      };

  bool get isEmpty => min == null && max == null && step == null;

  @override
  bool operator ==(Object other) =>
      other is IntConstraint &&
      other.min == min &&
      other.max == max &&
      other.step == step;

  @override
  int get hashCode => Object.hash(min, max, step);
}

/// List constraint with allowed values and max items.
@immutable
class ListConstraint {
  const ListConstraint({this.allowedValues, this.maxItems});

  final List<String>? allowedValues;
  final int? maxItems;

  bool isAllowed(String value) {
    if (allowedValues != null && !allowedValues!.contains(value)) return false;
    return true;
  }

  String? validate(List<String> values, String label) {
    if (maxItems != null && values.length > maxItems!) {
      return '$label must have at most $maxItems items.';
    }
    if (allowedValues != null) {
      for (final v in values) {
        if (!allowedValues!.contains(v)) {
          return '"$v" is not allowed for $label.';
        }
      }
    }
    return null;
  }

  static ListConstraint? fromJson(Object? json) {
    if (json is! Map) return null;
    return ListConstraint(
      allowedValues: _readStringList(json['allowed_values']),
      maxItems: _readInt(json['max_items']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (allowedValues != null) 'allowed_values': allowedValues,
        if (maxItems != null) 'max_items': maxItems,
      };

  bool get isEmpty => allowedValues == null && maxItems == null;

  @override
  bool operator ==(Object other) =>
      other is ListConstraint &&
      _listEquals(other.allowedValues, allowedValues) &&
      other.maxItems == maxItems;

  @override
  int get hashCode => Object.hash(
        allowedValues != null ? Object.hashAll(allowedValues!) : null,
        maxItems,
      );
}

/// Schedule constraint for availability.
@immutable
class ScheduleConstraint {
  const ScheduleConstraint({
    this.allowedDays,
    this.minDurationMinutes,
    this.maxDurationMinutes,
  });

  final List<String>? allowedDays;
  final int? minDurationMinutes;
  final int? maxDurationMinutes;

  static ScheduleConstraint? fromJson(Object? json) {
    if (json is! Map) return null;
    return ScheduleConstraint(
      allowedDays: _readStringList(json['allowed_days']),
      minDurationMinutes: _readInt(json['min_duration_minutes']),
      maxDurationMinutes: _readInt(json['max_duration_minutes']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (allowedDays != null) 'allowed_days': allowedDays,
        if (minDurationMinutes != null)
          'min_duration_minutes': minDurationMinutes,
        if (maxDurationMinutes != null)
          'max_duration_minutes': maxDurationMinutes,
      };

  bool get isEmpty =>
      allowedDays == null &&
      minDurationMinutes == null &&
      maxDurationMinutes == null;
}

/// Time slots constraint.
@immutable
class SlotsConstraint {
  const SlotsConstraint({
    this.maxSlots,
    this.allowedStartTimes,
    this.minGapMinutes,
  });

  final int? maxSlots;
  final List<String>? allowedStartTimes;
  final int? minGapMinutes;

  static SlotsConstraint? fromJson(Object? json) {
    if (json is! Map) return null;
    return SlotsConstraint(
      maxSlots: _readInt(json['max_slots']),
      allowedStartTimes: _readStringList(json['allowed_start_times']),
      minGapMinutes: _readInt(json['min_gap_minutes']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (maxSlots != null) 'max_slots': maxSlots,
        if (allowedStartTimes != null) 'allowed_start_times': allowedStartTimes,
        if (minGapMinutes != null) 'min_gap_minutes': minGapMinutes,
      };

  bool get isEmpty =>
      maxSlots == null && allowedStartTimes == null && minGapMinutes == null;
}

/// Admin-defined constraints on owner-editable capabilities.
@immutable
class CapabilityConstraints {
  const CapabilityConstraints({
    this.capacity,
    this.seating,
    this.amenities,
    this.availability,
    this.timeSlots,
    this.allowedModes,
    this.lockApprovalRequired,
  });

  final IntConstraint? capacity;
  final ListConstraint? seating;
  final ListConstraint? amenities;
  final ScheduleConstraint? availability;
  final SlotsConstraint? timeSlots;
  final List<InteractionMode>? allowedModes;
  final bool? lockApprovalRequired;

  static CapabilityConstraints? fromJson(Object? json) {
    if (json is! Map) return null;
    final modes = json['allowed_modes'];
    return CapabilityConstraints(
      capacity: IntConstraint.fromJson(json['capacity']),
      seating: ListConstraint.fromJson(json['seating']),
      amenities: ListConstraint.fromJson(json['amenities']),
      availability: ScheduleConstraint.fromJson(json['availability']),
      timeSlots: SlotsConstraint.fromJson(json['time_slots']),
      allowedModes: modes is List
          ? modes.map((e) => InteractionMode.fromJson(e?.toString())).toList()
          : null,
      lockApprovalRequired: json['lock_approval_required'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (capacity != null && !capacity!.isEmpty)
          'capacity': capacity!.toJson(),
        if (seating != null && !seating!.isEmpty) 'seating': seating!.toJson(),
        if (amenities != null && !amenities!.isEmpty)
          'amenities': amenities!.toJson(),
        if (availability != null && !availability!.isEmpty)
          'availability': availability!.toJson(),
        if (timeSlots != null && !timeSlots!.isEmpty)
          'time_slots': timeSlots!.toJson(),
        if (allowedModes != null)
          'allowed_modes': [for (final m in allowedModes!) m.toJson()],
        if (lockApprovalRequired != null)
          'lock_approval_required': lockApprovalRequired,
      };

  bool get isEmpty =>
      (capacity == null || capacity!.isEmpty) &&
      (seating == null || seating!.isEmpty) &&
      (amenities == null || amenities!.isEmpty) &&
      (availability == null || availability!.isEmpty) &&
      (timeSlots == null || timeSlots!.isEmpty) &&
      allowedModes == null &&
      lockApprovalRequired == null;

  /// Merges this constraint set with [parent], taking non-null values from
  /// this set first, falling back to [parent].
  CapabilityConstraints mergeWith(CapabilityConstraints parent) {
    return CapabilityConstraints(
      capacity: capacity ?? parent.capacity,
      seating: seating ?? parent.seating,
      amenities: amenities ?? parent.amenities,
      availability: availability ?? parent.availability,
      timeSlots: timeSlots ?? parent.timeSlots,
      allowedModes: allowedModes ?? parent.allowedModes,
      lockApprovalRequired: lockApprovalRequired ?? parent.lockApprovalRequired,
    );
  }
}

/// One available time window.
@immutable
class TimeSlot {
  const TimeSlot({required this.start, required this.end});

  final String start;
  final String end;

  bool get isValid {
    final s = _parseMinutes(start);
    final e = _parseMinutes(end);
    if (s == null || e == null) return false;
    return s < e;
  }

  String? get error {
    final s = _parseMinutes(start);
    final e = _parseMinutes(end);
    if (s == null || e == null) return 'Invalid time format. Use HH:MM.';
    if (s >= e) return 'Start time must be before end time.';
    return null;
  }

  static TimeSlot? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = json['start']?.toString();
    final end = json['end']?.toString();
    if (start == null || end == null) return null;
    return TimeSlot(start: start, end: end);
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  static int? _parseMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Recurring availability schedule with optional date exceptions.
@immutable
class AvailabilityConfig {
  const AvailabilityConfig({this.weeklySchedule, this.dateExceptions});

  final Map<String, List<TimeSlot>>? weeklySchedule;
  final Map<String, List<TimeSlot>>? dateExceptions;

  static AvailabilityConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    return AvailabilityConfig(
      weeklySchedule: _readSchedule(json['weekly_schedule']),
      dateExceptions: _readSchedule(json['date_exceptions']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (weeklySchedule != null && weeklySchedule!.isNotEmpty)
          'weekly_schedule': {
            for (final e in weeklySchedule!.entries)
              e.key: [for (final s in e.value) s.toJson()],
          },
        if (dateExceptions != null && dateExceptions!.isNotEmpty)
          'date_exceptions': {
            for (final e in dateExceptions!.entries)
              e.key: [for (final s in e.value) s.toJson()],
          },
      };

  bool get isEmpty =>
      (weeklySchedule == null || weeklySchedule!.isEmpty) &&
      (dateExceptions == null || dateExceptions!.isEmpty);

  static Map<String, List<TimeSlot>>? _readSchedule(Object? json) {
    if (json is! Map) return null;
    final result = <String, List<TimeSlot>>{};
    for (final entry in json.entries) {
      if (entry.value is! List) continue;
      final slots = <TimeSlot>[];
      for (final slot in entry.value) {
        final parsed = TimeSlot.fromJson(slot);
        if (parsed != null) slots.add(parsed);
      }
      if (slots.isNotEmpty) result[entry.key.toString()] = slots;
    }
    return result.isEmpty ? null : result;
  }
}

/// All configurable capabilities for a catalog node.
///
/// Null fields mean "inherit from parent". Empty lists mean "no value set".
@immutable
class FacilityCapabilities {
  const FacilityCapabilities({
    this.capacity,
    this.seating,
    this.availability,
    this.timeSlots,
    this.amenities,
    this.interactionMode,
    this.approvalRequired,
  });

  final int? capacity;
  final List<String>? seating;
  final AvailabilityConfig? availability;
  final List<TimeSlot>? timeSlots;
  final List<String>? amenities;
  final InteractionMode? interactionMode;
  final bool? approvalRequired;

  /// Merges this node's values with [parent], taking non-null values from
  /// this node first, falling back to [parent].
  FacilityCapabilities mergeWith(FacilityCapabilities parent) {
    return FacilityCapabilities(
      capacity: capacity ?? parent.capacity,
      seating: seating ?? parent.seating,
      availability: availability ?? parent.availability,
      timeSlots: timeSlots ?? parent.timeSlots,
      amenities: amenities ?? parent.amenities,
      interactionMode: interactionMode ?? parent.interactionMode,
      approvalRequired: approvalRequired ?? parent.approvalRequired,
    );
  }

  /// Resolves capabilities through the full hierarchy: subsection overrides
  /// section overrides type overrides defaults.
  static FacilityCapabilities resolve({
    FacilityCapabilities? subsection,
    FacilityCapabilities? section,
    FacilityCapabilities? type,
  }) {
    const defaults = FacilityCapabilities();
    final fromType = type?.mergeWith(defaults) ?? defaults;
    final fromSection = section?.mergeWith(fromType) ?? fromType;
    return subsection?.mergeWith(fromSection) ?? fromSection;
  }

  /// Validates this capability set against [constraints].
  List<String> validate({CapabilityConstraints? constraints}) {
    final errors = <String>[];

    if (capacity != null && constraints?.capacity != null) {
      final err = constraints!.capacity!.validate(capacity!, 'Capacity');
      if (err != null) errors.add(err);
    }
    if (capacity != null && capacity! <= 0) {
      errors.add('Capacity must be positive.');
    }

    if (seating != null && constraints?.seating != null) {
      final err = constraints!.seating!.validate(seating!, 'Seating');
      if (err != null) errors.add(err);
    }

    if (amenities != null && constraints?.amenities != null) {
      final err = constraints!.amenities!.validate(amenities!, 'Amenities');
      if (err != null) errors.add(err);
    }

    if (timeSlots != null) {
      final maxSlots = constraints?.timeSlots?.maxSlots;
      if (maxSlots != null && timeSlots!.length > maxSlots) {
        errors.add('At most $maxSlots time slots allowed.');
      }
      for (int i = 0; i < timeSlots!.length; i++) {
        final slotErr = timeSlots![i].error;
        if (slotErr != null) errors.add('Time slot ${i + 1}: $slotErr');
      }
      // Check overlaps
      for (int i = 0; i < timeSlots!.length; i++) {
        for (int j = i + 1; j < timeSlots!.length; j++) {
          if (_slotsOverlap(timeSlots![i], timeSlots![j])) {
            errors.add('Time slots ${i + 1} and ${j + 1} overlap.');
          }
        }
      }
    }

    if (interactionMode != null && constraints?.allowedModes != null) {
      if (!constraints!.allowedModes!.contains(interactionMode)) {
        errors
            .add('Interaction mode "${interactionMode!.name}" is not allowed.');
      }
    }

    return errors;
  }

  static bool _slotsOverlap(TimeSlot a, TimeSlot b) {
    final aStart = _parseMinutes(a.start);
    final aEnd = _parseMinutes(a.end);
    final bStart = _parseMinutes(b.start);
    final bEnd = _parseMinutes(b.end);
    if (aStart == null || aEnd == null || bStart == null || bEnd == null) {
      return false;
    }
    return aStart < bEnd && bStart < aEnd;
  }

  static int? _parseMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static FacilityCapabilities? fromJson(Object? json) {
    if (json is! Map) return null;
    final modes = json['interaction_mode'];
    return FacilityCapabilities(
      capacity: _readInt(json['capacity']),
      seating: _readStringList(json['seating']),
      availability: AvailabilityConfig.fromJson(json['availability']),
      timeSlots: _readTimeSlots(json['time_slots']),
      amenities: _readStringList(json['amenities']),
      interactionMode:
          modes != null ? InteractionMode.fromJson(modes?.toString()) : null,
      approvalRequired: json['approval_required'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (capacity != null) 'capacity': capacity,
        if (seating != null && seating!.isNotEmpty) 'seating': seating,
        if (availability != null && !availability!.isEmpty)
          'availability': availability!.toJson(),
        if (timeSlots != null && timeSlots!.isNotEmpty)
          'time_slots': [for (final s in timeSlots!) s.toJson()],
        if (amenities != null && amenities!.isNotEmpty) 'amenities': amenities,
        if (interactionMode != null)
          'interaction_mode': interactionMode!.toJson(),
        if (approvalRequired != null) 'approval_required': approvalRequired,
      };

  bool get isEmpty =>
      capacity == null &&
      (seating == null || seating!.isEmpty) &&
      (availability == null || availability!.isEmpty) &&
      (timeSlots == null || timeSlots!.isEmpty) &&
      (amenities == null || amenities!.isEmpty) &&
      interactionMode == null &&
      approvalRequired == null;

  @override
  bool operator ==(Object other) =>
      other is FacilityCapabilities &&
      other.capacity == capacity &&
      _listEquals(other.seating, seating) &&
      other.availability == availability &&
      _listEquals(other.timeSlots, timeSlots) &&
      _listEquals(other.amenities, amenities) &&
      other.interactionMode == interactionMode &&
      other.approvalRequired == approvalRequired;

  @override
  int get hashCode => Object.hash(
        capacity,
        seating != null ? Object.hashAll(seating!) : null,
        availability,
        timeSlots != null ? Object.hashAll(timeSlots!) : null,
        amenities != null ? Object.hashAll(amenities!) : null,
        interactionMode,
        approvalRequired,
      );
}

// ---------------------------------------------------------------------------
// Shared parsing helpers
// ---------------------------------------------------------------------------

int? _readInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<String>? _readStringList(Object? value) {
  if (value is! List) return null;
  final out = <String>[];
  for (final entry in value) {
    if (entry is String && entry.trim().isNotEmpty) {
      out.add(entry.trim());
    }
  }
  return out.isEmpty ? null : List.unmodifiable(out);
}

List<TimeSlot>? _readTimeSlots(Object? value) {
  if (value is! List) return null;
  final out = <TimeSlot>[];
  for (final entry in value) {
    final slot = TimeSlot.fromJson(entry);
    if (slot != null) out.add(slot);
  }
  return out.isEmpty ? null : List.unmodifiable(out);
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
