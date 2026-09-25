# Education / Courses — Feature-Coverage Map

Audit of `/Users/aa/BookMyspace_Andriod` against `docs/COURSES_TASK_PROMPT.md`.
Built from the live `lib/` tree and `supabase/migrations/`, not assumptions.
Format: **REUSE** = existing system to extend; **GAP** = genuinely missing, must be added.

## 1. Reused existing systems (do NOT duplicate)

| Capability | Existing system | Path |
|---|---|---|
| Course model + published/detail/enroll/drop | `Course`, `CourseBatch`, `CourseRepository` | `lib/features/courses/domain/{course,course_repository}.dart` |
| Supabase course repo (+ institute join, enrollment RPCs) | `SupabaseCourseRepository` | `lib/features/courses/infrastructure/supabase_course_repository.dart` |
| Course providers + enrollment controller | `publishedCoursesProvider`, `courseDetailProvider`, `courseEnrollmentControllerProvider` | `lib/features/courses/presentation/course_providers.dart` |
| User course list + detail screens | `CoursesListScreen`, `CourseDetailScreen`, `CourseCard` | `lib/features/courses/presentation/screens/*`, `widgets/course_card.dart` |
| Batches / seats / timings | `course_batches` (`capacity`, `enrolled_count`, `timetable jsonb`, `is_active`) | migration `0006_engagement_support_events.sql` |
| Enrollments (capacity-safe, duplicate-safe) | RPCs `enroll_in_course`, `drop_course_enrollment`, `my_enrolled_batches` | `0006`, `0013_events_courses_read.sql` |
| Auth + mobile OTP (+ dev OTP) | `SupabaseAuthRepository`, `SupabasePhoneOtpProvider`, `TemporaryDevelopmentPhoneOtpProvider` | `lib/features/auth/*` |
| Preserve selection across login | `loginLocationFor(Uri)` / `authenticatedLocationFromLogin(Uri)` (`?redirect=`) | `lib/core/router/app_router.dart:115-138` |
| Module enable/disable (plug-and-play) | `feature_flags` + `moduleEnabledProvider` + `AdminModulesScreen` | `lib/features/modules/*` |
| Draft-vs-published pattern | `status` column (`draft|published|archived`) + RLS `status='published'` | `0006` |
| Category system (education attach point) | `venue_categories` + `category_sections` (`parent_section='institutes_classes'`) | `0002`, `20260826152506`, `20260912132545` |
| Admin role gating / owner scoping | `is_platform_admin(uid)`, `get_owner_user_id()` RLS; `AppRole` route guards | `20260912140000`, `0014`, `app_router.dart` |
| Payments (Razorpay, booking-bound) | `PaymentRepository`, `PaymentNotifier`, native/web checkout bridges | `lib/features/payments/*` |
| Reviews (venue-scoped) | `Review`, `SupabaseReviewRepository`, `VenueReviewsSection` | `lib/features/reviews/*` |
| Upload pattern (public buckets, type/size validation) | inline `uploadVenueImage` etc. | `owner_venues`/`venues`/`venue_sections` repos |

## 2. Real gaps (additive work)

1. **Institutes surface**: `Institute` model is minimal (`id,org_id,name,description,logo_image,is_verified`); NO repository, providers, routes, or any screen (user/owner/admin). Needs profile columns (type/govt-level, location, contact, mode, timings, images) + repo/providers/screens.
2. **Institute↔category link**: none. Attach via `venue_categories.parent_section='institutes_classes'` + a new `institutes.category_id` (additive), not a third category table.
3. **Course demo/registration modeling**: none. Needs demo-method set (internal form / external link / phone-WhatsApp / video / brochure / live / recorded / none), demo video+thumbnail, brochure, external link, discount.
4. **Faculty**: none (only `courses.instructor_name`). Needs `course_faculty` entity + UI.
5. **My Courses / my-enrollments screen**: none (profile tile just deep-links to course list). Needs screen backed by `my_enrolled_batches`.
6. **Course feedback/rating**: none (reviews are venue-only). Needs `course_feedback` gated by enrollment.
7. **Invoices**: none in Flutter (legacy Kotlin only). Needs invoice entity + display screen.
8. **Course payment**: `Payment`/`create-payment-order` are hard-bound to `booking_id`. Needs a payable-enrollment path (Edge Function change) — **BLOCKED pending backend**.
9. **Generic field-config engine**: `module_form_versions` / `owner_registration_field_configs` exist only in the deployed DB, NOT in `lib/` or local migrations; owner onboarding is hardcoded. The app's real generic module system is `feature_flags`. Field-level config must be generalized onto `feature_flags.config` jsonb (no parallel table).
10. **Shared storage service**: uploads are inline/public-only, no progress/retry/private signed URLs. Needs a reusable `StorageService`.
11. **External links**: `url_launcher` absent; no safe-open / "leaving the app" helper.
12. **Owner course CRUD + admin education management**: admin courses screen is read-only; no owner create/edit, no batch/faculty/demo management UI.

## 3. Runtime-verification constraint

New columns/tables are added by an **additive migration that is NOT applied to the shared dev
Supabase project** in this session (applying migrations is a shared-state change requiring
explicit approval). Therefore repositories select new columns **defensively** (try extended
select, fall back to base select) so the app runs against the current dev schema now and
lights up new fields after the migration is applied. Anything requiring the new schema or the
payment Edge Function is reported **BLOCKED**, not claimed complete.
