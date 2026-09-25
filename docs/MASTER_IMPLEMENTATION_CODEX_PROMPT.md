# BookMySpace — Master Implementation Prompt for Codex

This is the execution prompt to hand to Codex. It treats `BOOKMYSPACE_MASTER_PROMPT.md`
(repo root) as the authoritative specification. Copy the fenced block below into Codex.

## TWO CRITICAL CLARIFICATIONS — these override any looser reading of the phases below

**1. Owner/Admin/Support test mode (Phase 8) must use legitimate development role
provisioning — NOT a hidden Flutter switch.** A client-side flag such as
`isAdmin = true`, a debug toggle, a local override, or trusting app metadata will
produce a UI that *looks* like Admin and then fails the moment it hits real Supabase
RLS. Roles must come from the backend in test mode exactly as they do in production;
only the *provisioning* of the test accounts may differ.

**2. Do not commit or push on your own, and `git push` is NOT the finish line
(Phase 23).** Stop after showing the diff and the verification results. Wait for explicit
authorization to commit, and then a *separate* explicit authorization to push. When a
push is eventually authorized it still does not end the task: the pushed code must be
rebuilt and reinstalled, and the resulting iOS app must *visibly contain the changes*. A
green push with a stale Simulator build running the previous binary is a FAIL, not a
PASS.

---

```text
BOOKMYSPACE — MASTER IMPLEMENTATION + CROSS-PLATFORM + ADMIN/OWNER CMS + MCP/API + E2E VERIFICATION

PROJECT:
 /Users/aa/BookMyspace_Andriod

AUTHORITATIVE SPEC:
 /Users/aa/BookMyspace_Andriod/BOOKMYSPACE_MASTER_PROMPT.md

IMPORTANT:
The BOOKMYSPACE_MASTER_PROMPT.md file is the authoritative specification.
It contains sections/rules 0–99 and supersedes older planning prompts.

Read the ENTIRE file before changing anything.

DO NOT:
- invent requirements that contradict BOOKMYSPACE_MASTER_PROMPT.md
- duplicate existing functionality
- replace working implementations with fake/demo implementations
- create fake backend data
- hardcode admin IDs
- bypass Supabase RLS
- bypass authentication
- create client-side payment confirmation
- put secrets/API keys in Flutter source
- create platform-specific behavior that makes iOS different from Android/Web unless technically required
- modify or remove the existing Explore Verified Spaces / Function Halls matrix design unless the master prompt explicitly requires it
- destroy existing working features
- reset/revert/discard existing user changes
- run git reset
- run git clean
- delete existing files merely because they appear old
- commit or push without separate explicit user authorization (see Phase 23)

PRIMARY OBJECTIVE:

Implement EVERYTHING required by BOOKMYSPACE_MASTER_PROMPT.md, sections 0–99, as a real production-oriented modular system.

The result must behave consistently on:

1. iOS
2. Android
3. Web

The implementation must be modular, maintainable, plug-and-play where appropriate, backend-driven where appropriate, and safe for future scale.

============================================================
PHASE 1 — FULL CURRENT-STATE AUDIT
============================================================

Before editing:

1. Read BOOKMYSPACE_MASTER_PROMPT.md completely.
2. Audit the current Flutter implementation.
3. Audit the native Android implementation in this same monorepo.
4. Audit iOS configuration.
5. Audit Web implementation.
6. Audit Supabase schema, migrations, RLS, RPCs and Edge Functions.
7. Audit routing.
8. Audit authentication.
9. Audit role authorization.
10. Audit existing Home sections.
11. Audit Owner functionality.
12. Audit Admin functionality.
13. Audit Search/Filters.
14. Audit Location/GPS/PIN.
15. Audit bookings.
16. Audit payments/Razorpay.
17. Audit courses.
18. Audit events.
19. Audit reviews.
20. Audit favorites.
21. Audit notifications/alerts.
22. Audit settings.
23. Audit localization.
24. Audit CMS/configuration functionality.
25. Audit integrations/MCP/API connector architecture.

Create an internal feature matrix:

FEATURE
- already implemented
- partially implemented
- missing
- broken
- backend dependency
- iOS status
- Android status
- Web status
- required action

DO NOT rebuild something that already works.

============================================================
PHASE 2 — PRESERVE CURRENT PRODUCT
============================================================

The current local Flutter product remains the primary source of truth.

Preserve:

- BookMySpace branding
- canonical logo
- teal/cyan identity
- glass UI
- current Home architecture
- Explore Verified Spaces
- Function Halls 3D glass matrix
- six-tab navigation:
  Home
  Alerts
  Search
  Bookings
  Courses
  Profile
- existing live Supabase integration
- existing booking architecture
- existing Razorpay architecture
- existing Google/Apple/email/phone authentication architecture
- existing Owner/Admin authorization model
- existing stable GoRouter architecture
- existing Riverpod fixes

Do NOT redesign these unnecessarily.

Especially:

DO NOT MODIFY category_glass_matrix.dart
or home_category_catalog.dart

unless the master prompt explicitly requires a necessary compatibility fix.

============================================================
PHASE 3 — IOS PARITY
============================================================

Every customer-facing feature must be available on iOS.

Do not accept:

"implemented in Flutter"

as proof.

For every feature verify:

Flutter implementation
+
route
+
provider/state
+
backend
+
iOS rendering
+
iOS interaction
+
error state
+
loading state
+
success state
+
empty state

Fix all iOS-only problems.

Pay special attention to:

- SafeArea
- keyboard handling
- scroll behavior
- modal sheets
- navigation/back behavior
- deep links
- OAuth callbacks
- permission dialogs
- GPS
- photo picker
- camera
- file picker
- notifications
- WebViews
- native Razorpay bridge
- external app launching
- URL schemes
- iOS simulator limitations
- physical-device-only functionality

============================================================
PHASE 4 — ANDROID PARITY
============================================================

Everything available on iOS must have Android implementation.

Compare against the native Android source where useful.

Do not simply make Flutter compile.

Verify:

- routes
- buttons
- forms
- backend calls
- permissions
- dialogs
- navigation
- images
- uploads
- authentication
- booking
- payment
- notifications
- owner flows
- admin flows
- localization
- settings

If Android native already contains a real capability missing in Flutter, port the capability into the shared Flutter architecture rather than creating two unrelated systems.

============================================================
PHASE 5 — WEB PARITY
============================================================

Web must load the real Flutter application.

Never allow:

- static demo HTML
- fake three-tab shell
- placeholder pages
- hardcoded demo content

Verify:

- routing
- refresh/deep links
- authentication
- search
- location
- admin
- owner
- CMS
- courses
- events
- bookings
- payment checkout
- MCP/API integrations where browser-compatible

Use platform adapters where native APIs are unavailable.

============================================================
PHASE 6 — ADMIN CMS / LIVE ELEMENT EDITOR
============================================================

Implement the complete Admin editing system required by the master prompt.

Admin must be able to manage UI/content elements through legitimate authorized backend operations.

Admin should be able to:

- add category
- edit category
- delete/archive category
- add subsection
- edit subsection
- delete/archive subsection
- change icon
- change image
- change title
- change subtitle
- change description
- change labels
- change ordering
- enable/disable elements
- configure banners
- configure cards
- configure offers
- configure home sections
- configure navigation-visible content where permitted
- update localized text
- update images
- update metadata
- preview changes
- publish changes
- rollback/recover where required by the master prompt

Do not hardcode CMS content into Flutter when the master prompt requires live configuration.

Use:

Supabase
+
typed domain models
+
repository
+
provider
+
admin UI
+
RLS
+
audit log

Do not create arbitrary client-side admin writes.

Every admin mutation must be authorization protected server-side.

============================================================
PHASE 7 — OWNER CMS
============================================================

Owner must be able to manage their own authorized resources.

Owner capabilities required by the master prompt must include, where applicable:

- venue creation
- venue editing
- venue deletion/archive
- title
- description
- category
- subsection
- icon
- images
- gallery
- pricing
- amenities
- location
- city
- PIN
- GPS
- hours
- time slots
- blocked dates
- availability
- offers
- venue metadata
- bookings
- operational settings

Owner must NEVER be able to modify another owner's venue.

Use:

organizations.owner_user_id
→ venues.org_id

and the existing authorization architecture.

Do not introduce:

venues.owner_id

unless the real schema explicitly requires it.

============================================================
PHASE 8 — TEST MODE OWNER / ADMIN / SUPPORT
============================================================

Create a SAFE DEVELOPMENT/TEST-MODE mechanism for Owner/Admin/Support testing.

IMPORTANT:

This must NOT be a production authorization bypass.

Do not:

- hardcode admin email
- hardcode user UUID
- trust Flutter flags
- trust localStorage
- trust app metadata
- make every user admin
- bypass RLS

Instead implement a legitimate development/test provisioning mechanism using the existing role architecture.

Required test roles:

CUSTOMER
OWNER
ADMIN
SUPPORT_AGENT

Test mode must be clearly separated from production.

Prefer:

development Supabase project
OR
secure server-side provisioning/RPC
OR
explicit test-only role grants

The Flutter client must still receive roles from the backend.

Create deterministic test accounts ONLY if this can be done safely through the existing development environment.

Never modify real production customer permissions.

Document exactly how to enter each test role.

============================================================
PHASE 9 — FILTER SCREEN
============================================================

Fix the previously observed Filters screen.

Requirements:

- proper iOS back button/navigation
- no overflow
- no yellow/black overflow stripes
- keyboard must not cover controls
- Apply must always be reachable
- Clear Filters must work
- sort must work
- category selection must work
- price fields must work
- scrolling must work
- route/query state must persist correctly
- returning from Filters must preserve the correct search state

Do not solve this by hiding content.

Test on iPhone 15 simulator.

============================================================
PHASE 10 — GPS / PIN / LOCATION
============================================================

GPS must NEVER remain stuck on loading.

Implement robust state machine:

idle
→ requestingPermission
→ acquiringLocation
→ reverseGeocoding
→ success

and:

permissionDenied
permissionDeniedForever
locationServiceDisabled
timeout
networkFailure
geocodeFailure

Every failure must provide a useful recovery path.

GPS must:

- work on iOS
- work on Android
- degrade gracefully on Web
- preserve coordinates even if reverse geocoding fails
- merge with Search correctly
- respect selected radius
- not write providers during build
- not start from build/initState/provider construction

PIN:

- exactly six digits
- lookup
- timeout
- India Post integration
- State
- District
- Mandal/Taluk
- City/Area
- PIN
- Apply to discovery
- Search integration

============================================================
PHASE 11 — BEAUTIFUL HOME UI
============================================================

Improve visual quality WITHOUT changing the existing Explore Verified Spaces section.

Keep that section exactly functionally intact.

Add/refine:

- eye-catching animated hero/banner
- elegant teal/cyan/violet gradient system
- subtle 3D depth
- glassmorphism
- smooth shadows
- restrained glow
- premium imagery
- animated particles where performance permits
- 3D-looking cards
- micro-interactions
- smooth transitions
- responsive layouts
- light mode
- dark mode

Do NOT create visual noise.

The design must remain:

premium
simple
fast
readable
modern
professional

Do not use fake offers, fake counts, fake reviews, fake ratings or fake inventory.

All content must be real or clearly generic UI copy.

Use RepaintBoundary and efficient animations.

============================================================
PHASE 12 — MULTI-LANGUAGE
============================================================

Implement the localization architecture specified in the master prompt.

At minimum ensure architecture supports:

English
Hindi
Telugu
Kannada

Do not hardcode user-facing strings.

Every screen should obtain text through localization.

Admin should be able to update CMS-controlled text without requiring an app release where the master prompt requires dynamic content.

Handle:

- pluralization
- fallback language
- missing translation
- dynamic CMS text
- RTL readiness if later needed

============================================================
PHASE 13 — MCP / EXTERNAL API CONNECTOR LAYER
============================================================

Implement the integration architecture from sections 65–99.

IMPORTANT:

Do NOT invent unsupported MCP servers or APIs.

Use an adapter architecture:

Flutter UI
→ domain interface
→ connector/service layer
→ provider/API client
→ external service

Examples only where actually supported:

- maps
- location
- payment
- messaging
- analytics
- external booking sources
- calendars
- CRM
- notification providers
- MCP-compatible services

Every external integration must have:

- timeout
- retry
- exponential backoff where appropriate
- circuit breaker where appropriate
- logging without secrets
- typed response
- error mapping
- fallback
- health state

Secrets must remain server-side.

============================================================
PHASE 14 — PLUG AND PLAY MODULE SYSTEM
============================================================

Create a modular feature architecture so modules can be enabled/disabled without rewriting the app.

Potential modules:

- Home
- Search
- Location
- Bookings
- Payments
- Courses
- Events
- Reviews
- Favorites
- Alerts
- Owner
- Admin
- Support
- CMS
- Analytics
- Localization
- External Integrations
- MCP connectors

Use interfaces/contracts instead of tightly coupled implementations.

Do not over-engineer.

Do not create a plugin framework merely for appearance.

Only modularize where it improves maintainability.

============================================================
PHASE 15 — SELF-HEALING / RESILIENCE
============================================================

Implement practical self-healing behavior.

Examples:

- stale cache recovery
- failed network request retry
- token refresh
- repository retry
- invalid cached state recovery
- failed image retry
- failed location retry
- stale route/query recovery
- reconnect handling
- graceful Supabase outage UI
- payment pending recovery
- webhook confirmation polling
- idempotent backend operations

Never silently fabricate successful results.

Never convert an unknown error into success.

Never hide backend failures.

============================================================
PHASE 16 — 10 CRORE USER SCALE
============================================================

Design for approximately 10 crore users without claiming that the current infrastructure has already been load-tested to that scale.

Focus on architecture:

- pagination
- cursor pagination where useful
- indexed queries
- selective columns
- no N+1 queries
- server-side filtering
- caching
- image optimization
- CDN-compatible assets
- rate limiting
- idempotency
- background processing
- database constraints
- connection efficiency
- retry discipline
- observability
- audit logging
- feature flags
- horizontal scalability

Do not load thousands of rows into Flutter.

Do not use unbounded Supabase queries.

============================================================
PHASE 17 — PAYMENT
============================================================

Razorpay must remain server-authoritative.

Flow:

booking hold
→ pending booking
→ create server-side Razorpay order
→ native/web checkout
→ Razorpay webhook
→ server confirmation
→ confirmed booking

Never:

- confirm booking from client success callback
- trust client payment amount
- expose Razorpay secret
- fabricate payment IDs
- fabricate signatures
- mark booking paid without webhook/server confirmation

Verify:

iOS
Android
Web

where platform/payment environment permits.

Use TEST mode only for test transactions.

============================================================
PHASE 18 — SECURITY
============================================================

Review:

- RLS
- SECURITY DEFINER
- search_path
- function grants
- storage policies
- auth policies
- role checks
- ownership checks
- Edge Function authentication
- webhook signature validation
- API secret handling
- client-side environment variables
- audit logging

Do not weaken security to make tests pass.

============================================================
PHASE 19 — ACTUAL APP VERIFICATION
============================================================

This is mandatory.

Do not report:

"implemented"

until the feature has been tested.

For iOS:

Build with the real development environment:

flutter build ios --simulator --debug --dart-define-from-file=.env.dev

Install on iPhone 15 simulator.

Launch it.

Interact with the actual UI.

Verify every major route.

For Android:

Build the APK.

If an emulator/device exists, install and interact.

If no device exists, clearly report Android runtime as BLOCKED, but still perform all build/static/widget tests.

For Web:

Build and run the real Flutter web application.

Open it in a browser.

Verify the actual UI.

============================================================
PHASE 20 — TEST MATRIX
============================================================

Create/extend tests for:

- authentication
- routing
- role guards
- customer denial
- owner authorization
- admin authorization
- support authorization
- CMS CRUD
- categories
- subsections
- localization
- GPS
- PIN
- filters
- search
- venue details
- favorites
- reviews
- courses
- events
- booking holds
- cancellation
- blocked dates
- time slots
- payments
- webhook idempotency
- error states
- retry states
- offline/degraded states

Run:

flutter analyze

flutter test

flutter build ios --simulator --debug --dart-define-from-file=.env.dev

flutter build apk --debug

flutter build web --debug

Do not stop at compile success.

============================================================
PHASE 21 — FINAL UI QA
============================================================

On iPhone 15 verify:

1. Launch
2. Home
3. Hero/banner
4. Location
5. GPS
6. PIN
7. Explore Verified Spaces
8. Function Halls
9. Other categories
10. Search
11. Filters
12. Venue details
13. Favorites
14. Reviews
15. Courses
16. Events
17. Bookings
18. Alerts
19. Profile
20. Settings
21. Login
22. OTP
23. Google
24. Apple
25. Owner test mode
26. Admin test mode
27. Support test mode
28. CMS
29. Localization
30. Back navigation
31. Keyboard behavior
32. Dark mode

Check for:

- overflow
- clipped text
- broken images
- stuck loaders
- empty states
- red error overlays
- Riverpod build-time mutations
- broken routes
- inaccessible buttons
- keyboard-covered buttons
- inconsistent colors
- missing back controls

============================================================
PHASE 22 — NO FAKE COMPLETION
============================================================

At the end provide a table:

FEATURE | CODE | BACKEND | IOS | ANDROID | WEB | E2E | STATUS

Use only:

PASS
PARTIAL
BLOCKED
FAIL

Never call something PASS if it was only statically inspected.

============================================================
PHASE 23 — GIT SAFETY GATE
============================================================

DO NOT commit or push automatically.

After implementation and verification:

1. Run:
   git status

2. Review all changed files.

3. Review the complete diff.

4. Verify:
   - no secrets
   - no .env.dev contents
   - no API keys
   - no generated artifacts
   - no unrelated modifications
   - BOOKMYSPACE_MASTER_PROMPT.md intact
   - existing user changes preserved

5. Show:
   - branch
   - changed files
   - complete verification results
   - tests
   - builds
   - iOS verification
   - Android verification
   - Web verification

6. STOP.

DO NOT RUN:
   git commit
   git push
   git push --force
   git reset
   git clean
   git revert
   git cherry-pick

Wait for explicit user authorization before creating a commit.

After explicit authorization, create the local commit.

Do NOT push unless the user separately explicitly authorizes the push.

After push authorization:
   - push ONLY the current branch
   - never force-push
   - verify git status
   - verify git log -1 --oneline
   - verify git remote -v
   - rebuild from the pushed working tree
   - reinstall
   - launch
   - visually verify the resulting app contains the changes

============================================================
FINAL REQUIREMENT
============================================================

The most important requirement is:

THE CHANGES MUST ACTUALLY APPEAR AND WORK IN THE INSTALLED APP.

Do not give me a report saying "implemented" merely because files compile.

For every major change:

CODE
→ BUILD
→ INSTALL
→ LAUNCH
→ INTERACT
→ VERIFY
→ FIX
→ REBUILD
→ REINSTALL
→ VERIFY AGAIN

If something cannot be E2E verified because a real dependency/account/device is unavailable, do not fake it. Mark it BLOCKED and explain exactly what is required.

At the end give me:

1. What was implemented
2. What was already working and preserved
3. What was fixed
4. iOS verification
5. Android verification
6. Web verification
7. Backend verification
8. Security verification
9. Tests passed
10. Build results
11. Commit status — the hash if a commit was explicitly authorized, otherwise
    HELD, PENDING EXPLICIT AUTHORIZATION
12. Push status — must read HELD, PENDING EXPLICIT AUTHORIZATION unless the user
    separately authorized the push (Phase 23 git safety gate)
13. Any remaining blockers

DO NOT STOP AFTER READING THE MASTER PROMPT.
EXECUTE THE WORK.
```
