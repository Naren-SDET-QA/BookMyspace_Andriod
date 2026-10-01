import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/cms/domain/facility_capabilities.dart';
import 'package:bookmyspace/features/cms/domain/catalog_content.dart';

void main() {
  group('InteractionMode', () {
    test('fromJson parses valid values', () {
      expect(InteractionMode.fromJson('bookable'), InteractionMode.bookable);
      expect(InteractionMode.fromJson('registration'),
          InteractionMode.registration);
      expect(InteractionMode.fromJson('informationOnly'),
          InteractionMode.informationOnly);
    });

    test('fromJson returns informationOnly for null/unknown', () {
      expect(InteractionMode.fromJson(null), InteractionMode.informationOnly);
      expect(
          InteractionMode.fromJson('unknown'), InteractionMode.informationOnly);
    });

    test('toJson returns name', () {
      expect(InteractionMode.bookable.toJson(), 'bookable');
      expect(InteractionMode.registration.toJson(), 'registration');
      expect(InteractionMode.informationOnly.toJson(), 'informationOnly');
    });
  });

  group('IntConstraint', () {
    test('isValid validates correctly', () {
      const c = IntConstraint(min: 10, max: 100, step: 5);
      expect(c.isValid(10), isTrue);
      expect(c.isValid(15), isTrue);
      expect(c.isValid(100), isTrue);
      expect(c.isValid(5), isFalse);
      expect(c.isValid(101), isFalse);
      expect(c.isValid(12), isFalse);
    });

    test('validate returns error message', () {
      const c = IntConstraint(min: 10, max: 100);
      expect(c.validate(5, 'Capacity'), 'Capacity must be at least 10.');
      expect(c.validate(101, 'Capacity'), 'Capacity must be at most 100.');
      expect(c.validate(50, 'Capacity'), isNull);
    });

    test('fromJson/toJson round trip', () {
      const original = IntConstraint(min: 10, max: 100, step: 5);
      final json = original.toJson();
      final parsed = IntConstraint.fromJson(json);
      expect(parsed, original);
    });

    test('isEmpty returns true when all null', () {
      expect(const IntConstraint().isEmpty, isTrue);
      expect(const IntConstraint(min: 10).isEmpty, isFalse);
    });
  });

  group('ListConstraint', () {
    test('isAllowed validates against allowed values', () {
      const c = ListConstraint(allowedValues: ['a', 'b', 'c']);
      expect(c.isAllowed('a'), isTrue);
      expect(c.isAllowed('d'), isFalse);
    });

    test('isAllowed allows all when no constraint', () {
      const c = ListConstraint();
      expect(c.isAllowed('anything'), isTrue);
    });

    test('validate checks maxItems', () {
      const c = ListConstraint(maxItems: 2);
      expect(c.validate(['a', 'b'], 'Seating'), isNull);
      expect(c.validate(['a', 'b', 'c'], 'Seating'),
          'Seating must have at most 2 items.');
    });

    test('validate checks allowed values', () {
      const c = ListConstraint(allowedValues: ['x', 'y']);
      expect(c.validate(['x', 'z'], 'Amenities'),
          '"z" is not allowed for Amenities.');
    });

    test('fromJson/toJson round trip', () {
      const original = ListConstraint(allowedValues: ['a', 'b'], maxItems: 5);
      final json = original.toJson();
      final parsed = ListConstraint.fromJson(json);
      expect(parsed, original);
    });
  });

  group('TimeSlot', () {
    test('isValid checks start < end', () {
      expect(const TimeSlot(start: '09:00', end: '17:00').isValid, isTrue);
      expect(const TimeSlot(start: '17:00', end: '09:00').isValid, isFalse);
      expect(const TimeSlot(start: '09:00', end: '09:00').isValid, isFalse);
    });

    test('error returns message for invalid slots', () {
      expect(const TimeSlot(start: '25:00', end: '17:00').error, isNotNull);
      expect(const TimeSlot(start: '09:00', end: '17:00').error, isNull);
      expect(const TimeSlot(start: '17:00', end: '09:00').error,
          'Start time must be before end time.');
    });

    test('fromJson/toJson round trip', () {
      const original = TimeSlot(start: '09:00', end: '17:00');
      final json = original.toJson();
      final parsed = TimeSlot.fromJson(json);
      expect(parsed, original);
    });
  });

  group('FacilityCapabilities', () {
    test('mergeWith takes non-null from child', () {
      const parent = FacilityCapabilities(capacity: 100);
      const child = FacilityCapabilities(capacity: 50);
      final merged = child.mergeWith(parent);
      expect(merged.capacity, 50);
    });

    test('mergeWith falls back to parent for null', () {
      const parent = FacilityCapabilities(capacity: 100, amenities: ['wifi']);
      const child = FacilityCapabilities();
      final merged = child.mergeWith(parent);
      expect(merged.capacity, 100);
      expect(merged.amenities, ['wifi']);
    });

    test('resolve with full hierarchy', () {
      const type = FacilityCapabilities(capacity: 200);
      const section = FacilityCapabilities(capacity: 100);
      const subsection = FacilityCapabilities(capacity: 50);

      final resolved = FacilityCapabilities.resolve(
        subsection: subsection,
        section: section,
        type: type,
      );
      expect(resolved.capacity, 50);
    });

    test('resolve inherits from type when child null', () {
      const type = FacilityCapabilities(capacity: 200, amenities: ['wifi']);
      final resolved = FacilityCapabilities.resolve(type: type);
      expect(resolved.capacity, 200);
      expect(resolved.amenities, ['wifi']);
    });

    test('validate checks capacity', () {
      const caps = FacilityCapabilities(capacity: -1);
      final errors = caps.validate();
      expect(errors, contains('Capacity must be positive.'));
    });

    test('validate checks constraints', () {
      const caps = FacilityCapabilities(capacity: 5);
      const constraints = CapabilityConstraints(
        capacity: IntConstraint(min: 10),
      );
      final errors = caps.validate(constraints: constraints);
      expect(errors, isNotEmpty);
    });

    test('validate checks time slot overlaps', () {
      const caps = FacilityCapabilities(timeSlots: [
        TimeSlot(start: '09:00', end: '12:00'),
        TimeSlot(start: '11:00', end: '13:00'),
      ]);
      final errors = caps.validate();
      expect(errors.any((e) => e.contains('overlap')), isTrue);
    });

    test('fromJson/toJson round trip', () {
      const original = FacilityCapabilities(
        capacity: 100,
        seating: ['theater', 'round_table'],
        amenities: ['ac', 'wifi'],
        interactionMode: InteractionMode.bookable,
        approvalRequired: true,
        timeSlots: [TimeSlot(start: '09:00', end: '17:00')],
      );
      final json = original.toJson();
      final parsed = FacilityCapabilities.fromJson(json);
      expect(parsed, original);
    });

    test('fromJson handles null and empty', () {
      expect(FacilityCapabilities.fromJson(null), isNull);
      final empty = FacilityCapabilities.fromJson({});
      expect(empty, isNotNull);
      expect(empty!.isEmpty, isTrue);
    });

    test('isEmpty returns true when all null', () {
      expect(const FacilityCapabilities().isEmpty, isTrue);
      expect(const FacilityCapabilities(capacity: 10).isEmpty, isFalse);
    });
  });

  group('CatalogNode capabilities', () {
    test('CatalogSubsection preserves capabilities through copyWith', () {
      const caps = FacilityCapabilities(capacity: 50);
      const sub = CatalogSubsection(key: 'test', capabilities: caps);
      final copy =
          sub.copyWith(capabilities: const FacilityCapabilities(capacity: 100));
      expect(copy.capabilities?.capacity, 100);
    });

    test('CatalogSection preserves capabilities through copyWith', () {
      const caps = FacilityCapabilities(capacity: 100);
      const section = CatalogSection(key: 'test', capabilities: caps);
      final copy = section.copyWith(
          capabilities: const FacilityCapabilities(capacity: 200));
      expect(copy.capabilities?.capacity, 200);
    });

    test('CatalogFacilityType preserves capabilities through copyWith', () {
      const caps = FacilityCapabilities(capacity: 200);
      const type = CatalogFacilityType(key: 'test', capabilities: caps);
      final copy = type.copyWith(
          capabilities: const FacilityCapabilities(capacity: 300));
      expect(copy.capabilities?.capacity, 300);
    });

    test('toJson includes capabilities when non-empty', () {
      const caps = FacilityCapabilities(capacity: 50);
      const sub = CatalogSubsection(key: 'test', capabilities: caps);
      final json = sub.toJson();
      expect(json['capabilities'], isNotNull);
      expect(json['capabilities']['capacity'], 50);
    });

    test('toJson omits capabilities when empty', () {
      const sub = CatalogSubsection(key: 'test');
      final json = sub.toJson();
      expect(json.containsKey('capabilities'), isFalse);
    });

    test('fromJson parses capabilities', () {
      final json = {
        'key': 'test',
        'capabilities': {'capacity': 50},
      };
      final sub = CatalogSubsection.fromJson(json);
      expect(sub?.capabilities?.capacity, 50);
    });

    test('fromJson handles missing capabilities', () {
      final json = {'key': 'test'};
      final sub = CatalogSubsection.fromJson(json);
      expect(sub?.capabilities, isNull);
    });
  });

  group('CapabilityConstraints', () {
    test('mergeWith takes non-null from child', () {
      const parent = CapabilityConstraints(
        capacity: IntConstraint(min: 10),
      );
      const child = CapabilityConstraints(
        capacity: IntConstraint(min: 20),
      );
      final merged = child.mergeWith(parent);
      expect(merged.capacity?.min, 20);
    });

    test('mergeWith falls back to parent for null', () {
      const parent = CapabilityConstraints(
        capacity: IntConstraint(min: 10),
        seating: ListConstraint(maxItems: 5),
      );
      const child = CapabilityConstraints();
      final merged = child.mergeWith(parent);
      expect(merged.capacity?.min, 10);
      expect(merged.seating?.maxItems, 5);
    });

    test('fromJson/toJson round trip', () {
      const original = CapabilityConstraints(
        capacity: IntConstraint(min: 10, max: 100),
        seating: ListConstraint(allowedValues: ['a', 'b']),
        lockApprovalRequired: true,
      );
      final json = original.toJson();
      final parsed = CapabilityConstraints.fromJson(json);
      expect(parsed?.capacity?.min, original.capacity?.min);
      expect(parsed?.capacity?.max, original.capacity?.max);
      expect(parsed?.seating?.allowedValues, original.seating?.allowedValues);
      expect(parsed?.lockApprovalRequired, original.lockApprovalRequired);
    });
  });
}
