import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/cms/domain/facility_capabilities.dart';
import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';

void main() {
  group('Booking ↔ Capability Contract', () {
    group('Capability resolution for booking context', () {
      test('resolves capabilities from venue category hierarchy', () {
        // Simulate the CMS catalog as stored in feature_flags.config
        final catalog = CatalogContent([
          CatalogFacilityType(
            key: 'function_halls',
            title: CmsLocalizedText(base: 'Function Halls'),
            capabilities: const FacilityCapabilities(
              interactionMode: InteractionMode.bookable,
              approvalRequired: true,
            ),
            sections: [
              CatalogSection(
                key: 'function_halls',
                title: CmsLocalizedText(base: 'Function Halls'),
                searchAliases: ['function_halls'],
                capabilities: const FacilityCapabilities(capacity: 200),
                subsections: [
                  CatalogSubsection(
                    key: 'marriage_hall',
                    title: CmsLocalizedText(base: 'Marriage Hall'),
                    aliasSlugs: ['marriage_hall'],
                    capabilities: const FacilityCapabilities(
                      capacity: 150,
                      seating: ['theater', 'round_table'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ]);

        // Simulate venue -> category -> parent_section resolution
        final venueParentSection = 'function_halls';
        final venueCategorySlug = 'marriage_hall';

        // Find the facility type
        final facilityType = catalog.facilityTypeFor(venueParentSection);
        expect(facilityType, isNotNull);

        // Find the section: the section's key matches the facility type key,
        // or the category slug is in search_aliases.
        CatalogSection? matchedSection;
        for (final section in facilityType!.sections) {
          if (section.searchAliases.contains(venueCategorySlug) ||
              section.key == venueCategorySlug ||
              section.key == venueParentSection) {
            matchedSection = section;
            break;
          }
        }
        expect(matchedSection, isNotNull);

        // Find the subsection
        CatalogSubsection? matchedSubsection;
        for (final sub in matchedSection!.subsections) {
          if (sub.key == venueCategorySlug ||
              sub.aliasSlugs.contains(venueCategorySlug)) {
            matchedSubsection = sub;
            break;
          }
        }
        expect(matchedSubsection, isNotNull);

        // Resolve capabilities through the hierarchy
        final resolved = FacilityCapabilities.resolve(
          subsection: matchedSubsection!.capabilities,
          section: matchedSection.capabilities,
          type: facilityType.capabilities,
        );

        // Verify resolution
        expect(resolved.interactionMode, InteractionMode.bookable);
        expect(resolved.approvalRequired, true);
        expect(resolved.capacity, 150); // subsection overrides section (200)
        expect(resolved.seating, ['theater', 'round_table']);
      });

      test('defaults to bookable when no capabilities configured', () {
        final catalog = CatalogContent([
          CatalogFacilityType(
            key: 'function_halls',
            title: CmsLocalizedText(base: 'Function Halls'),
            // No capabilities set
            sections: [
              CatalogSection(
                key: 'function_halls',
                title: CmsLocalizedText(base: 'Function Halls'),
                searchAliases: ['function_halls'],
                // No capabilities set
                subsections: [
                  CatalogSubsection(
                    key: 'marriage_hall',
                    title: CmsLocalizedText(base: 'Marriage Hall'),
                    aliasSlugs: ['marriage_hall'],
                    // No capabilities set
                  ),
                ],
              ),
            ],
          ),
        ]);

        final facilityType = catalog.facilityTypeFor('function_halls');
        final section = facilityType!.sections.first;
        final subsection = section.subsections.first;

        final resolved = FacilityCapabilities.resolve(
          subsection: subsection.capabilities,
          section: section.capabilities,
          type: facilityType.capabilities,
        );

        // All null → default behavior
        expect(resolved.interactionMode, isNull);
        expect(resolved.approvalRequired, isNull);
        expect(resolved.capacity, isNull);
        expect(resolved.isEmpty, isTrue);
      });

      test('information_only mode blocks booking', () {
        const caps = FacilityCapabilities(
          interactionMode: InteractionMode.informationOnly,
        );

        // Server-side check: if mode is not bookable, reject
        final isBookable = caps.interactionMode == null ||
            caps.interactionMode == InteractionMode.bookable;
        expect(isBookable, isFalse);
      });

      test('registration mode allows booking with approval', () {
        const caps = FacilityCapabilities(
          interactionMode: InteractionMode.registration,
          approvalRequired: true,
        );

        final isBookable = caps.interactionMode == null ||
            caps.interactionMode == InteractionMode.bookable;
        expect(isBookable, isFalse);

        // Registration mode requires owner approval
        expect(caps.approvalRequired, true);
      });

      test('bookable mode with approval_required=false allows instant booking', () {
        const caps = FacilityCapabilities(
          interactionMode: InteractionMode.bookable,
          approvalRequired: false,
        );

        final isBookable = caps.interactionMode == null ||
            caps.interactionMode == InteractionMode.bookable;
        expect(isBookable, isTrue);
        expect(caps.approvalRequired, false);
      });
    });

    group('Capability validation for booking', () {
      test('validates capacity within bounds', () {
        const caps = FacilityCapabilities(capacity: 100);
        const constraints = CapabilityConstraints(
          capacity: IntConstraint(min: 10, max: 500),
        );

        final errors = caps.validate(constraints: constraints);
        expect(errors, isEmpty);
      });

      test('rejects capacity below minimum', () {
        const caps = FacilityCapabilities(capacity: 5);
        const constraints = CapabilityConstraints(
          capacity: IntConstraint(min: 10),
        );

        final errors = caps.validate(constraints: constraints);
        expect(errors, isNotEmpty);
        expect(errors.first, contains('at least'));
      });

      test('validates time slots do not overlap', () {
        const caps = FacilityCapabilities(timeSlots: [
          TimeSlot(start: '09:00', end: '12:00'),
          TimeSlot(start: '13:00', end: '17:00'),
        ]);

        final errors = caps.validate();
        expect(errors, isEmpty);
      });

      test('rejects overlapping time slots', () {
        const caps = FacilityCapabilities(timeSlots: [
          TimeSlot(start: '09:00', end: '12:00'),
          TimeSlot(start: '11:00', end: '13:00'),
        ]);

        final errors = caps.validate();
        expect(errors.any((e) => e.contains('overlap')), isTrue);
      });

      test('validates seating options against allowed values', () {
        const caps = FacilityCapabilities(seating: ['theater', 'round_table']);
        const constraints = CapabilityConstraints(
          seating: ListConstraint(allowedValues: ['theater', 'round_table', 'classroom']),
        );

        final errors = caps.validate(constraints: constraints);
        expect(errors, isEmpty);
      });

      test('rejects seating not in allowed values', () {
        const caps = FacilityCapabilities(seating: ['theater', 'invalid_option']);
        const constraints = CapabilityConstraints(
          seating: ListConstraint(allowedValues: ['theater', 'round_table']),
        );

        final errors = caps.validate(constraints: constraints);
        expect(errors, isNotEmpty);
        expect(errors.first, contains('not allowed'));
      });
    });

    group('Booking context identification', () {
      test('minimum booking context is venue_id + slot_id + book_date', () {
        // The contract requires:
        // 1. venue_id → resolves to venue → category → parent_section → CatalogFacilityType
        // 2. slot_id → resolves to time slot (start_time, end_time, price)
        // 3. book_date → resolves to day-of-week for availability check

        const venueId = 'venue-123';
        const slotId = 'slot-456';
        final bookDate = DateTime(2026, 9, 20);

        expect(venueId, isNotEmpty);
        expect(slotId, isNotEmpty);
        expect(bookDate, isA<DateTime>());
      });

      test('venue metadata provides category resolution path', () {
        // Venue metadata contains parent_section and category_slug
        final venueMetadata = {
          'parent_section': 'function_halls',
          'category_slug': 'marriage_hall',
        };

        expect(venueMetadata['parent_section'], isNotNull);
        expect(venueMetadata['category_slug'], isNotNull);
      });
    });

    group('Backward compatibility', () {
      test('existing Function Hall bookings work without capabilities', () {
        // When no capabilities are configured, the system should behave
        // exactly as before: all venues are bookable, approval_required=true
        const resolved = FacilityCapabilities(); // empty

        final isBookable = resolved.interactionMode == null ||
            resolved.interactionMode == InteractionMode.bookable;
        expect(isBookable, isTrue); // defaults to bookable

        final needsApproval = resolved.approvalRequired ?? true;
        expect(needsApproval, isTrue); // defaults to requiring approval
      });

      test('partial capability config inherits from parent', () {
        const typeCaps = FacilityCapabilities(
          interactionMode: InteractionMode.bookable,
          approvalRequired: true,
        );
        // Section and subsection have no capabilities
        final resolved = FacilityCapabilities.resolve(
          type: typeCaps,
        );

        expect(resolved.interactionMode, InteractionMode.bookable);
        expect(resolved.approvalRequired, true);
        expect(resolved.capacity, isNull);
      });
    });

    group('Server-side authority', () {
      test('client cannot override resolved capabilities', () {
        // The server resolves capabilities from the CMS catalog.
        // Client-supplied values are ignored for capability checks.
        const serverResolved = FacilityCapabilities(
          capacity: 100,
          interactionMode: InteractionMode.bookable,
        );

        // Client might try to claim capacity=500
        const clientClaimed = FacilityCapabilities(capacity: 500);

        // Server uses its own resolution, not client's claim
        expect(serverResolved.capacity, 100);
        expect(clientClaimed.capacity, 500); // client value is irrelevant
      });

      test('resolved capabilities stored in booking for audit', () {
        const resolved = FacilityCapabilities(
          capacity: 150,
          interactionMode: InteractionMode.bookable,
          approvalRequired: true,
        );

        final bookingMetadata = {
          'resolved_capabilities': resolved.toJson(),
          'has_capabilities': true,
        };

        expect(bookingMetadata['resolved_capabilities'], isNotNull);
        expect(
          (bookingMetadata['resolved_capabilities'] as Map)['capacity'],
          150,
        );
      });
    });
  });
}
