# Phase 5 — Universal Facility Capability System

## Design

Capabilities are stored as a structured `FacilityCapabilities` object on each `CatalogNode`. They inherit downward (subsection → section → facility type → defaults) and are overridable at every level. Owners configure within admin-defined constraints (min/max/allowed values). No pricing in CMS — pricing stays in the venues domain.

### Capability Categories

| Capability | Type | Default | Admin Constraint | Notes |
|---|---|---|---|---|
| `capacity` | `int?` | `null` | `min`, `max`, `step` | Max occupancy; null = not applicable |
| `seating` | `List<String>` | `[]` | `allowedValues`, `maxItems` | Options like "theater", "round_table", "classroom" |
| `availability` | `AvailabilityConfig?` | `null` | `allowedDays`, `minDuration`, `maxDuration` | Recurring schedule + date exceptions |
| `timeSlots` | `List<TimeSlot>` | `[]` | `maxSlots`, `allowedStartTimes`, `minGap` | Available time windows |
| `amenities` | `List<String>` | `[]` | `allowedValues`, `maxItems` | Feature tags like "ac", "parking", "wifi" |
| `interactionMode` | `InteractionMode` | `.informationOnly` | `allowedModes` | bookable / registration / informationOnly |
| `approvalRequired` | `bool` | `false` | locked (admin-only) | Owner/admin approval before confirmation |

### Inheritance Resolution

```dart
// ResolvedCapabilities merges downward: subsection overrides section overrides type overrides defaults
final resolved = FacilityCapabilities.resolve(
  subsection: subsection.capabilities,
  section: section.capabilities,
  type: type.capabilities,
);
```

Each level only overrides fields it explicitly sets. Null means "inherit from parent".

### Owner "Within Bounds" Model

Admins set constraints on each capability. Owners configure within those bounds:

```dart
class CapabilityConstraints {
  final IntConstraint? capacity;
  final ListConstraint? seating;
  final ListConstraint? amenities;
  final ScheduleConstraint? availability;
  final SlotsConstraint? timeSlots;
  final List<InteractionMode>? allowedModes;
  final bool? lockApprovalRequired;  // if true, owners can't toggle
}
```

Example: Admin sets `capacity: IntConstraint(min: 10, max: 500, step: 5)`. Owner can set capacity to 50, 55, 60... but not 5 or 600.

### Files to Create

| File | Purpose |
|---|---|
| `lib/features/cms/domain/facility_capabilities.dart` | `FacilityCapabilities`, `AvailabilityConfig`, `TimeSlot`, `InteractionMode`, `CapabilityConstraints` models + validation |
| `lib/features/cms/presentation/capabilities_providers.dart` | Resolved capability providers (inheritance + merge + constraint checking) |
| `lib/features/cms/presentation/widgets/capability_editor.dart` | Reusable admin/owner capability editor widget |
| `lib/features/cms/presentation/widgets/capability_render.dart` | Customer-facing capability display widget |
| `test/features/cms/facility_capabilities_test.dart` | Domain model + inheritance + validation tests |
| `test/features/cms/capability_editor_test.dart` | Widget tests for editor |

### Files to Modify

| File | Changes |
|---|---|
| `lib/features/cms/domain/catalog_content.dart` | Add `FacilityCapabilities? capabilities` and `CapabilityConstraints? constraints` to `CatalogNode`, propagate through `copyWith`/`fromJson`/`toJson` |
| `lib/features/cms/domain/catalog_validation.dart` | Add capability validation (capacity > 0, valid time slots, constraint bounds) |
| `lib/features/cms/presentation/screens/admin_catalog_screen.dart` | Add "Capabilities" tab/section to `_NodeEditor` using `CapabilityEditor` |
| `lib/features/cms/presentation/screens/owner_facility_builder_screen.dart` | Show resolved capabilities in owner wizard; validate against constraints |
| `lib/features/cms/presentation/owner_facility_controller.dart` | Validate capabilities against constraints in `validationError` |
| `test/features/cms/catalog_content_test.dart` | Add capability round-trip and inheritance tests |
| `test/features/cms/catalog_editing_test.dart` | Add capability mutation tests |
| `test/features/cms/catalog_validation_test.dart` | Add capability validation tests |
| `test/features/cms/admin_catalog_screen_test.dart` | Add capability editor widget tests |

### Storage

No new tables. Capabilities serialize into the existing `feature_flags.config` JSON under `category_catalog`, as part of each node's `toJson()`. The `capabilities` and `constraints` keys are optional — nodes without them inherit from their parent or fall back to defaults.

### Backward Compatibility

- `CatalogNode.capabilities` defaults to `null`
- `CatalogNode.constraints` defaults to `null`
- `fromJson` treats missing/null as empty (all defaults)
- `toJson` omits null capabilities/constraints (no bloat in existing documents)
- Existing admin/owner screens continue to work unchanged
- Customer render path treats null capabilities as "information only, no booking"

### Validation Rules

- `capacity`: must be positive int if present; must be within parent constraint bounds
- `seating`: each option must be non-empty, max 50 chars; must be in `allowedValues` if constraint set
- `timeSlots`: start < end, no overlaps, max 24 slots; must respect `maxSlots` and `minGap`
- `amenities`: each non-empty, max 100 chars, max 50 items; must be in `allowedValues` if constraint set
- `interactionMode`: must be a valid enum value; must be in `allowedModes` if constraint set
- `approvalRequired`: bool; locked if admin sets `lockApprovalRequired: true`

### What Does NOT Change

- booking, payment, auth, navigation, 3D Glass Matrix, inventory, media library
- No AI, MCP, external APIs
- No new database tables or migrations
- No new storage buckets
- Pricing stays in the venues domain
