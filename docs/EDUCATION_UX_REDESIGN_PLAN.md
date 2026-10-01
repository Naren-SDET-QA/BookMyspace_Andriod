# Education/Courses redesign — audit + file-by-file plan

Status: audit complete, no code changed yet. This corrects and supersedes the
"LIKELY GENUINE GAPS" section of the earlier feature-coverage map — the
Courses feature has grown substantially since that audit (18 files now vs. 7
then), most likely from work done directly on the Mac outside this
conversation. Re-audited against the actual current files, not the earlier
snapshot.

## What already exists (do not duplicate any of this)

**Customer flow** — `lib/features/courses/presentation/screens/`:
- `education_hub_screen.dart` — Education landing, institute browse, gated by
  `moduleEnabledProvider('courses')` (the existing feature_flags system).
- `courses_list_screen.dart`, `institute_detail_screen.dart`,
  `course_detail_screen.dart` — browse → institute → course.
- `my_courses_screen.dart` — learner's enrollments, feedback, invoice access.
- Widgets: `course_card.dart`, `course_demo_actions.dart`,
  `register_demo_sheet.dart`, `course_upload_field.dart`, `external_link.dart`
  (safe external-link handling — already does the "leaving the app" warning
  the task prompt asked for), `feedback_dialog.dart`, `invoice_view.dart`.

**Owner flow:**
- `owner_courses_screen.dart`, `owner_course_editor_screen.dart` — course/batch
  CRUD, already wired to the RLS policies applied earlier this session
  (`courses_org_write`, and now `course_batches_owner_insert/update/delete`).

**Admin:**
- `admin_education_screen.dart` — a 2-tab (Institutes / Courses) screen plus a
  "Modules" button into the existing `AdminModulesScreen`. This is real but
  far short of the 17-item sidebar CMS requested.

**Domain/repository** (`course_repository.dart`, `course.dart` — 522 lines,
`CourseDemoMethod` enum, `MyEnrolledCourse`, `CourseFeedback` all already
modeled): `saveCourse` already accepts `categoryId`, `discountAmount`,
`demoMethods`, `demoVideoUrl`, `demoThumbnailUrl`, `brochureUrl`,
`externalRegistrationUrl`, `contactPhone`, `publish` — i.e. most of "FIELD
CONFIGURATION" and "DEMO REGISTRATION OPTIONS" data shape from the earlier
task prompt is already implemented, not a gap anymore.

**Infrastructure already reusable as-is:** `AppRole`/`RoleGate`, `AppLocalizations`
with English + Telugu (`te`) already registered as a supported locale,
`ResponsiveLayoutBuilder`/`ResponsiveInfo` (compact/medium/expanded/extraWide
breakpoint system already matches the spirit of the 7 requested breakpoints),
`core/widgets/accessibility.dart`, `EmptyState`/`ErrorView`/`SkeletonBox` for
loading/empty/error states, `AppNetworkImage`.

## Real gaps, verified against current code (not assumed)

**1. Course detail section order does not match the requested 17-item order.**
Current order in `course_detail_screen.dart` (from actual structure): hero
(image/title/institute) → Details chips (duration/mode/etc, all in one row)
→ Demo and Registration → Faculty → fee card + Enroll → (further down)
Feedback → batch/enrollment management tile. Missing entirely as distinct
sections: **location/map, "what students will learn," a standalone
brochure/documents section (brochure exists only inside the demo actions
widget, not as its own section), FAQ, and a sticky bottom action bar** (the
enroll action is currently inline in the scroll, not pinned). Reordering
"Faculty" (spec position 6) to before "Duration/timings/mode" (positions
7-9) and moving "Demo" from its current early position to spec position 12
(after "what students will learn") are both pure presentation-layer
reorders — no data model change needed since all these fields already exist
on `Course`.

**2. Admin sidebar has 2 of 17 requested sections as distinct screens.**
Institutes and Courses exist as tabs. Missing as first-class admin surfaces:
Dashboard, Education Categories, Batches, Faculty, Demo Classes,
Registrations, Feedback, Payments, Invoices, Media Library, Form Fields,
Module Settings (partially covered — the button exists but jumps to the
generic `AdminModulesScreen`, not an education-scoped one), Preview, Audit
Logs (the `audit_logs` table and `AuditLogRepository` already exist per the
earlier audit — this is a *reuse*, not a build), App Settings. This is the
largest remaining piece of work in the whole request.

**3. Field-level admin configuration (labels, help text, required/optional,
visible/admin-only, ordering, Telugu translations per field) has no UI
anywhere yet.** The data-shape question from the earlier migration-plan
discussion (target_type/target_id on `module_feature_configs` etc.) is still
unresolved and still not applied — building the Form Fields admin screen
depends on that decision being made first, or on confirming courses can use
its own dedicated config columns instead. This should not be assumed either
way without you confirming which path.

**4. No dedicated Telugu strings exist yet for course-specific copy** — need
to confirm which of the new headings/labels already have `te` entries in
`app_localizations.dart` (1252 lines, so partially populated) vs. need adding.

**5. No tests exist yet for any of the 16 listed test areas** (course
browsing, institute details, demo registration, enrollment, invoice
visibility, owner CRUD, admin CRUD, draft/publish, module enable/disable,
configurable fields, role isolation, upload validation, back navigation,
accessibility, responsive layouts, no-overflow) — this is a real, large gap,
separate from the UI work itself.

## Proposed batches (small, independently verifiable)

Given I have no Flutter toolchain anywhere in my reach this session (cloud
container has no SDK and no pub.dev egress; the linked-Mac `device_bash`
bridge is a separate sandboxed Linux VM without Flutter/Xcode either —
confirmed directly a few turns ago) every batch below needs you to run
`dart format` / `flutter analyze` / `flutter test` on your Mac and paste
results back, the same way we just did for the RLS test. Given that
round-trip cost, small batches matter more here than usual — a single giant
change with no verification step would be exactly the kind of unverified
claim this session has been avoiding all along.

- **Batch 1** — reorder `course_detail_screen.dart` to the exact 17-section
  order, add the 4 missing sections (location/map, what-you'll-learn,
  standalone documents/brochure, FAQ) using only fields already on `Course`
  (no new data needed for map: institute has no lat/long yet, so "location
  and map" will render address text with a graceful fallback, not a broken
  map, and I'll flag that as its own small gap rather than fabricate
  coordinates), and make the bottom action bar sticky. Presentation-layer
  only, matching your "do not change backend logic" instruction from the
  earlier UI-order request.
- **Batch 2** — reorder `education_hub_screen.dart` / `courses_list_screen.dart`
  card fields to match the "COURSE LIST UI" spec (institute logo, category,
  location, distance, rating+verified badge, mode label, starting fee,
  duration, View Details / Register Demo / Enroll Now buttons) — checking
  first which of these fields (distance, rating) actually exist on the
  current models versus need a genuine new gap flagged.
- **Batch 3** — owner dashboard: convert `owner_courses_screen.dart` into the
  large-action-card dashboard shape requested, still against existing
  repository methods only.
- **Batch 4+** — the admin CMS sidebar expansion (the big one) — I'd want to
  scope this into its own sub-plan once batches 1-3 are verified, since it's
  the least-built part and most likely to need the target_type/target_id
  schema decision resolved first.
- **Tests** — added incrementally alongside each batch's screens, not as one
  final pass, so each batch is independently verifiable the same way the RLS
  suite was.

I have not written any code yet. Confirm batch 1's scope (or adjust it) and
I'll implement just that slice, then hand you the exact `dart format`/
`flutter analyze`/`flutter test` commands to run for just the changed files.
