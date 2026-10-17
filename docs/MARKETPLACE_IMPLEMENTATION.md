# Marketplace integration audit and delivery plan

Audit date: 2026-10-18. Base commit: `89c9fc629b612684251b20ecc6a999000faa378f`.
Branch: `codex/flutter-marketplace-integration`.

## Current architecture and reusable functionality

This is the existing Flutter application, with Android, iOS and Web runners.
It also contains a separate native Android application (`app/`); Flutter
changes do not automatically modify that application's Compose screens.
Flutter uses Riverpod 2, GoRouter, Material 3, Dio, secure storage and Supabase.
Features separate domain contracts, infrastructure repositories and presentation.
The repository has 302 Dart test files, 34 SQL test files, migration history,
Edge Functions and GitHub Actions for Android, iOS and web builds.

Reuse authentication and role gates, localization, the configurable Home,
discovery location, venue categories, venue search/details, owner approval,
booking holds, Razorpay platform adapters, webhook verification, cancellation,
refund reconciliation, receipts, QR check-in, saved items, events, courses,
sports and existing administration. No second user/payment/booking database
is introduced for the marketplace section.

## Gaps and risks

- No movies, cinemas, screens, seat layouts or assigned-seat booking module.
- `CommercePaymentScreen` deliberately refuses checkout. Event registration
  and course enrollment must not be represented as verified paid ticketing.
- Existing generic resource holds support hotel room types; they cannot be
  assumed to support arbitrary seats merely because a resource table exists.
- There are duplicate legacy/release UI and payment adapters. Retain them
  until call sites and released API contracts have been tested.
- CI pins Flutter 3.44.0/Dart 3.12.0 and compares analyzer output to a baseline.
  A plain analyzer success is a stronger requirement than the current gate.
- Native device behavior, configured OAuth/OTP, real payment capture and
  notification delivery require configured services and device validation.

## Target architecture

Add `features/marketplace/{domain,infrastructure,presentation}` as one section
of the existing app. A typed catalog projection reads existing published
entities through an RLS-preserving paginated RPC. Search, location, category,
price, date and sort are server-side. Cards navigate to existing feature
routes. Business logic stays outside widgets. English/Telugu strings live in
the localization layer. This initial catalog does not authorize or confirm
bookings; existing booking and payment services retain those responsibilities.

New category adapters can be added without replacing the router, auth shell,
user profiles, payments or existing venue booking flow.

## Database changes required

1. Add a security-invoker catalog search RPC over existing venues/events/courses,
   full-text indexes for events/courses, bounded pagination and stable sorting.
2. Add cinema/movie/screen/layout/show entities. Store immutable show inventory
   separately from reusable layouts. Scope all owner writes to organizations.
3. Add assigned-seat and general-admission hold transactions with canonical lock
   ordering, server prices, ten-minute expiry, unique active inventory claims,
   request-scoped idempotency and tests using independent database connections.
4. Bridge those holds into existing bookings/payment orders/refunds/tickets;
   verify webhook capture and late payments before inventory confirmation.
5. Add restaurant tables/reservations and experience adapters only after the
   inventory contract passes concurrency and RLS tests.

## Verified milestones and gates

| Milestone | Deliverable | Required gate |
| --- | --- | --- |
| 1 | Repository audit, integrated marketplace catalog and responsive UI | domain/widget/repository tests, analyzer, web build |
| 2 | Movies, cinemas and owner seat layout management | SQL/RLS tests, responsive widget tests |
| 3 | Atomic assigned seats and general-admission holds | simultaneous users, expiry, release, deadlock and replay tests |
| 4 | Checkout, coupons, verified Razorpay and refunds | signed webhook/reconciliation/idempotency tests |
| 5 | Digital tickets and staff scanning | QR decoding, duplicate scans, cancelled/refunded cases |
| 6 | Restaurant/experience slots, courses, owner/admin workflows | authorization and inventory integration tests |
| 7 | Notifications, analytics, accessibility and operational hardening | device E2E, Android/Web/iOS builds, staging acceptance |

Immediate milestone: 1. No milestone is marked complete from UI alone.
Production release additionally requires a configured staging environment,
test-mode payment credentials, macOS/Xcode signing setup and real devices.

## Verification reporting

Record exact commands and results in `MARKETPLACE_VERIFICATION.md`. Distinguish
executed checks from configured CI and from unverified service/device flows.
Never mark the complete original marketplace brief as delivered by this first
integration milestone.
