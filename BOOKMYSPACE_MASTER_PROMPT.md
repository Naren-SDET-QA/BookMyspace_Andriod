# BOOKMYSPACE — MASTER CROSS-PLATFORM PRODUCT COMPLETION PROMPT

```
==============================================================

PROJECT
-------
Local repository:

/Users/aa/BookMyspace_Andriod

IMPORTANT:
This repository contains the current Flutter BookMySpace application and the
native Android implementation/reference code.

PRIMARY SOURCE OF TRUTH:
- Current local Flutter product
- Current Supabase backend/schema
- Existing working Android behavior
- Existing working iOS behavior

SECONDARY REFERENCE:
GitHub:
https://github.com/Naren-SDET-QA/bookmyspace.git

DO NOT blindly copy the old GitHub implementation.

The current Flutter product is newer and must remain the primary product.

==============================================================
0. NON-NEGOTIABLE RULES
==============================================================

1. DO NOT rewrite the application from scratch.

2. DO NOT remove existing working functionality.

3. DO NOT replace the current product design with an old GitHub design.

4. DO NOT break:
   - Home
   - Explore Verified Spaces
   - Function Halls 3D glass matrix
   - six-tab navigation
   - Search
   - GPS
   - PIN lookup
   - India location hierarchy
   - Venues
   - Favorites
   - Reviews
   - Events
   - Courses
   - Authentication
   - Google login
   - Apple login
   - Email/phone OTP
   - Owner functionality
   - Admin functionality
   - Booking
   - Razorpay architecture
   - Notifications
   - Profile
   - Settings
   - dark mode
   - light mode

5. DO NOT MODIFY:
   lib/features/home/presentation/widgets/category_glass_matrix.dart

6. DO NOT MODIFY the current:
   Explore Verified Spaces
   Function Halls matrix
   unless a bug makes it impossible to function.

The current Function Halls visual design is frozen.

7. DO NOT introduce fake production data.

8. DO NOT hardcode:
   - users
   - roles
   - venue IDs
   - admin IDs
   - owner IDs
   - payment IDs
   - booking IDs
   - coordinates
   - prices
   - reviews
   - coupons
   - statistics

9. Every displayed dynamic value must come from:
   - Supabase
   - authenticated backend
   - legitimate API
   - local configuration
   - deterministic UI state

10. Do not bypass RLS.

11. Do not create client-side admin privileges.

12. Do not put service-role secrets in Flutter.

13. Never expose:
   - Razorpay secret
   - Supabase service-role key
   - webhook secret
   - MCP credentials
   - third-party private API credentials

14. Preserve server-authoritative payment confirmation.

15. No fake Razorpay success.

16. No fake booking confirmation.

17. No fake authentication.

18. No fake Owner/Admin role.

19. No fake external integrations.

20. If an external API/MCP does not actually exist or cannot be authenticated,
    implement a clean adapter/interface and show an honest unavailable state.
    NEVER invent an API.

21. Every feature must work on:
   - iOS
   - Android
   - Web

22. Only genuine platform-specific implementation differences are allowed.

23. Shared business logic must remain platform-independent.

24. No provider mutation during widget build/initState.

25. No Future.delayed hacks to hide lifecycle problems.

26. No arbitrary post-frame provider mutation.

27. Preserve stable GoRouter architecture.

28. Preserve the current six customer tabs:

   Home
   Alerts
   Search
   Bookings
   Courses
   Profile

29. Do not add a seventh bottom navigation tab.

30. Owner/Admin screens should use dedicated routes.

31. Do not commit, push, reset, revert, cherry-pick, or create a PR
    unless explicitly instructed.

==============================================================
1. FIRST: COMPLETE AUDIT
==============================================================

Before changing code:

AUDIT:

A. Flutter source
B. Native Android source
C. iOS implementation
D. Web implementation
E. Supabase schema
F. Supabase RLS
G. Edge Functions
H. Storage buckets/policies
I. RPCs
J. authentication
K. routing
L. localization
M. theme
N. integrations
O. Owner console
P. Admin console
Q. payment system
R. booking lifecycle
S. analytics
T. external APIs
U. MCP integration layer
V. tests

Create an internal feature matrix:

FEATURE
ANDROID
IOS
WEB
FLUTTER
BACKEND
RLS
STATUS
MISSING DEPENDENCY
IMPLEMENTATION PLAN

Do not start random rewrites.

==============================================================
2. CROSS-PLATFORM ARCHITECTURE
==============================================================

Architecture must remain:

Flutter UI
    ↓
Feature/domain layer
    ↓
Repository interfaces
    ↓
Platform/service adapters
    ↓
Supabase / Edge Functions / external APIs

Use shared domain models and repository contracts.

Platform-specific code only where required:

iOS:
- native Apple capabilities
- iOS permissions
- Razorpay iOS SDK
- Apple Sign In
- native image picker/camera
- location

Android:
- Android permissions
- Razorpay Android SDK
- camera/gallery
- location
- native integrations

Web:
- browser APIs
- Checkout.js where required
- web-compatible integrations

Business logic must NOT be duplicated across platforms.

==============================================================
3. DESIGN SYSTEM
==============================================================

Create one centralized BookMySpace design system.

Current brand:

Primary:
teal/cyan BookMySpace identity

Secondary:
deep navy

Supporting:
soft white / light glass

Dark mode:
deep navy / charcoal glass

The visual language should be:

- premium
- modern
- simple
- clean
- highly readable
- subtle 3D
- glassmorphism
- soft gradients
- controlled shadows
- rounded cards
- elegant spacing
- excellent typography

DO NOT make the UI childish or overloaded.

Avoid excessive gradients.

Avoid excessive animation.

Avoid flashing effects.

Avoid giant text.

Avoid unnecessary decoration.

==============================================================
4. HERO / HOME EXPERIENCE
==============================================================

Keep the current:

Explore Verified Spaces

section EXACTLY as it currently works.

Do not redesign the Function Halls matrix.

Do not remove:
- master category carousel
- Function Halls matrix
- subcategory navigation
- real counts
- Browse behavior
- query navigation

Improve only unrelated Home sections.

Add/maintain:

A. Eye-catching animated banner

Requirements:

- premium teal → cyan → violet gradient
- subtle moving light
- soft particles
- glass highlights
- gentle 3D depth
- micro animation
- animated CTA
- RepaintBoundary
- GPU-friendly
- no constant expensive rebuilds

The banner must be functional.

Examples of legitimate content:

"Book verified spaces with confidence"

"Find. Compare. Book."

"Spaces that fit your plans."

Do not invent discounts.

If real offers exist in Supabase, show them.

Otherwise show generic product messaging.

==============================================================
5. 3D IMAGE SYSTEM
==============================================================

Create reusable:

GlassImageCard

with:

- rounded corners
- image
- gradient overlay
- subtle perspective
- soft shadow
- glass border
- slight parallax
- press animation
- loading placeholder
- error fallback

Every image must be:
- remote/live
- Supabase Storage
- legitimate external image
- bundled asset

NEVER use broken URLs as production content.

Images must gracefully fail.

Use cached network images where appropriate.

Do not repeatedly download the same image.

==============================================================
6. IMAGE CACHE
==============================================================

Implement a centralized image-loading strategy.

Requirements:

- memory cache
- disk cache where appropriate
- placeholder
- retry
- error state
- lazy loading
- image resizing
- no excessive memory usage

Do not allow image loading to block Home.

Do not allow image failures to crash the screen.

==============================================================
7. GPS / LOCATION
==============================================================

GPS must work end-to-end.

Requirements:

- permission handling
- location service check
- loading state
- timeout
- retry
- permission denied
- permanently denied
- Open Settings
- reverse geocoding
- latitude
- longitude
- city
- state
- district
- PIN when available

IMPORTANT:

Never leave the UI permanently showing:

"Loading..."

GPS state machine:

idle
→ requesting
→ locating
→ geocoding
→ success

or

idle
→ requesting
→ permissionDenied

or

idle
→ requesting
→ timeout

or

idle
→ requesting
→ serviceDisabled

Every failure must have an actionable recovery.

==============================================================
8. PIN / INDIA LOCATION
==============================================================

Implement:

6 digit PIN

Lookup

Return:

- State
- District
- Mandal/Taluk
- City/Area
- PIN

Use the existing India Post adapter/Edge Function.

Add:

- timeout
- retry
- invalid PIN
- no result
- network failure

Apply location must navigate correctly to Search.

Keyboard must never cover:

- Apply
- Lookup
- Back
- navigation controls

==============================================================
9. SEARCH
==============================================================

Search must work consistently on:

iOS
Android
Web

Support:

- text
- category
- subsection
- city
- GPS
- PIN
- radius
- price
- sorting
- rating
- availability

Sort:

- Relevance
- Price Low → High
- Price High → Low
- Top Rated

Filters screen:

MUST HAVE A BACK BUTTON.

Back must return to the correct Search screen.

No:

"GoException: no routes for location: /"

Never navigate to `/` unless `/` is a valid route.

Ensure all modal/sheet/filter routes have safe dismissal.

Fix all keyboard overflow.

==============================================================
10. MULTILINGUAL SYSTEM
==============================================================

Implement centralized localization.

At minimum architecture must support:

English
Telugu
Hindi
Kannada
Tamil
Malayalam
Marathi

Use ARB/localization resources or equivalent maintainable system.

DO NOT hardcode user-facing text throughout widgets.

Create:

LocalizationService

or equivalent.

All new UI strings must be localizable.

Language selector:

Settings
→ Language
→ language selection
→ immediate UI update
→ persisted preference

Do not translate:
- IDs
- database fields
- URLs
- API parameters

unless explicitly required.

==============================================================
11. OWNER MODE
==============================================================

Owner must have complete CRUD.

Owner can:

CREATE
READ
UPDATE
DELETE
ARCHIVE

venues

Owner can edit:

- venue name
- description
- category
- subsection
- images
- pricing
- amenities
- facilities
- address
- city
- state
- district
- PIN
- latitude
- longitude
- contact
- WhatsApp
- website
- hours
- time slots
- blocked dates
- policies
- capacity
- booking rules

Owner must NOT edit another owner's venue.

Use organization ownership:

organizations.owner_user_id
→ venues.org_id

Never use fake owner_id fields.

==============================================================
12. OWNER IMAGE MANAGEMENT
==============================================================

Owner can:

- upload
- preview
- reorder
- replace
- delete
- retry

Images stored in:

Supabase Storage

using secure organization-scoped paths.

No fake image URLs.

Show:

upload progress
success
failure
retry

==============================================================
13. OWNER TIME SLOTS
==============================================================

Owner can:

- create slot
- edit slot
- deactivate slot
- reactivate slot
- delete slot where safe

Prevent:

- overlaps
- invalid times
- duplicate slots

Booking must use actual active slots.

==============================================================
14. OWNER BLOCKED DATES
==============================================================

Owner can:

- choose date
- choose date range
- enter reason
- save
- edit
- remove block

Booking hold must respect blocked dates.

No booking on blocked date.

==============================================================
15. OWNER DASHBOARD
==============================================================

Dashboard must show live:

- venues
- active venues
- bookings
- pending bookings
- confirmed bookings
- cancelled bookings
- revenue where permitted
- analytics

Never show fake statistics.

Use loading/error/empty states.

==============================================================
16. ADMIN MODE
==============================================================

Admin means:

administrator
or
super_administrator

Admin can manage the platform.

Admin must have easy editable management UI.

Admin can manage:

Users
Owners
Venues
Categories
Subsections
Bookings
Payments
Events
Courses
Offers
Support
Analytics
Audit logs
Theme/content
Integrations
Feature flags
Platform configuration

==============================================================
17. ADMIN UNIVERSAL EDITOR
==============================================================

Create a reusable Admin Element Editor.

Admin should be able to edit:

- text
- title
- subtitle
- icon
- image
- banner
- label
- CTA
- ordering
- visibility
- category
- subsection
- theme properties

Provide:

Edit
Save
Cancel
Preview
Publish
Archive
Delete

Where deletion is dangerous:

require confirmation.

Use audit logging.

Every admin mutation must record:

- actor
- timestamp
- entity
- entity ID
- old value where appropriate
- new value
- action

==============================================================
18. ADMIN CATEGORY MANAGEMENT
==============================================================

Admin can easily:

CREATE CATEGORY

Fields:

- name
- slug
- icon
- image
- description
- ordering
- visibility
- metadata

Admin can:

- edit
- reorder
- activate/deactivate
- archive
- delete where safe

Admin can create:

SUBSECTIONS

Example:

Function Halls
→ Marriage Halls
→ Banquet Halls
→ Convention Halls
→ Party Halls & Lawns
→ Engagement Halls
→ Reception Halls
→ Premium / Luxury Halls
→ Outdoor / Garden Venues

Do not hardcode this list into the application.

The admin system must allow new categories/subsections to be created from the backend.

Existing Function Halls visual matrix remains unchanged.

New categories should automatically become available to the customer discovery system.

==============================================================
19. CATEGORY ICON / IMAGE EDITOR
==============================================================

Admin can change:

- icon
- icon type
- emoji if supported
- image
- title
- subtitle
- ordering
- visibility

Preview before publishing.

Use schema-compatible metadata.

Never assume database columns that don't exist.

==============================================================
20. ADMIN CONTENT CMS
==============================================================

Create a maintainable content model for:

- banners
- announcements
- Home sections
- promotional cards
- help content
- empty states
- onboarding
- category content
- feature descriptions

Admin can:

Create
Edit
Preview
Publish
Archive
Delete

Do not hardcode CMS content in Flutter.

==============================================================
21. PLUG-AND-PLAY FEATURE SYSTEM
==============================================================

Create feature registry architecture.

Example:

FeatureModule
{
  id
  name
  version
  enabled
  platformSupport
  configuration
}

Modules can include:

- referrals
- rewards
- coupons
- events
- courses
- reviews
- favorites
- notifications
- analytics
- external integrations
- MCP connectors
- payment providers
- support
- CMS

Feature flags must be backend/config driven where appropriate.

Disabled module must not crash the app.

==============================================================
22. SELF-HEALING / RESILIENCE
==============================================================

Implement graceful recovery.

For every network feature:

loading
success
empty
timeout
network error
server error
permission error
retry

Self-healing means:

- retry transient failures
- refresh stale data
- recover expired sessions
- recover interrupted navigation
- invalidate affected caches
- re-fetch after mutations
- recover image failures
- recover temporary API failures

DO NOT implement infinite retry loops.

Use bounded retry with backoff.

Never hide permanent errors.

==============================================================
23. OFFLINE / NETWORK RESILIENCE
==============================================================

The app must not crash when:

- internet disappears
- DNS fails
- Supabase unavailable
- third-party API unavailable

Display useful UI:

"You're offline"

"Retry"

"Use cached information"

where safe.

Never fabricate live data while offline.

==============================================================
24. AUTHENTICATION
==============================================================

Preserve:

Google
Apple
Email
Phone OTP

Handle:

- loading
- cancellation
- timeout
- invalid OTP
- expired OTP
- network failure
- provider failure
- session expiry

After authentication:

use canonical Supabase auth state.

Never create a fake session.

==============================================================
25. ROLE SYSTEM
==============================================================

Roles MUST come from backend.

customer
venue_owner
administrator
super_administrator
support_agent where deployed

Never:

if email == "admin@example.com"

Never:

if user.id == hardcoded UUID

Never allow Flutter to self-promote a user.

==============================================================
26. REFERRALS
==============================================================

Implement referral module if supported by current backend.

Must support:

- referral code
- referral sharing
- attribution
- referral status
- rewards where backend supports them

No fake rewards.

If backend schema is missing:

create proper migration/RPCs.

==============================================================
27. REWARDS / OFFERS
==============================================================

Implement real backend-backed:

- offers
- coupons
- rewards

Admin can manage them.

Customer can view valid offers.

Server must validate eligibility.

Never trust client-calculated discounts.

==============================================================
28. BOOKING SYSTEM
==============================================================

Booking lifecycle:

availability
→ hold
→ pending booking
→ payment
→ webhook confirmation
→ confirmed

or

hold
→ expiry/cancel
→ released

Prevent:

- double booking
- overlapping bookings
- expired holds
- client-side fake confirmation

==============================================================
29. BOOKING SUCCESS SCREEN
==============================================================

Create dedicated Booking Success screen.

Show:

- booking ID
- venue
- date
- slot
- amount
- payment status
- confirmation status

Actions:

- View Booking
- Add to Calendar
- Navigate to Venue
- Share
- Home

Only show CONFIRMED when backend confirms it.

==============================================================
30. RAZORPAY
==============================================================

Preserve current architecture:

Flutter
→ PaymentRepository
→ create-payment-order Edge Function
→ Razorpay native/web checkout
→ webhook
→ confirm_venue_booking
→ booking confirmed

Android:
Razorpay Android SDK

iOS:
Razorpay iOS SDK

Web:
Razorpay Checkout.js

Never expose:

RAZORPAY_KEY_SECRET

in client.

Test mode:

rzp_test_

Production:

rzp_live_

Never mix them.

==============================================================
31. PAYMENT HEALTH
==============================================================

Admin Payment Health dashboard:

- provider status
- order creation failures
- webhook failures
- pending payments
- confirmed payments
- failed payments
- duplicate events
- reconciliation status

No secrets displayed.

==============================================================
32. PAYMENT TRANSACTIONS
==============================================================

Admin ledger:

- payment ID
- order ID
- booking ID
- user
- amount
- currency
- provider
- status
- created
- captured
- failed
- webhook state

Search/filter/sort.

Never allow admin UI to fabricate transaction status.

==============================================================
33. ANALYTICS
==============================================================

Analytics must support:

Customer:
- searches
- views
- favorites
- bookings

Owner:
- venue views
- searches
- booking conversions
- revenue where authorized

Admin:
- platform-wide analytics

Reports:

Daily
Weekly
Monthly

Use proper aggregation.

Do not simply show a raw event dump.

Respect RLS.

==============================================================
34. SUPPORT
==============================================================

Customer:

Create ticket
View ticket
Reply
Close where permitted

Support/Admin:

View
Assign
Reply
Resolve
Reopen where permitted

Every resolution must be authorized and audited.

==============================================================
35. ADMIN LIVE ELEMENT EDITOR
==============================================================

Create a visual configuration system.

Admin can edit:

Home banner
Home sections
labels
icons
images
CTA
ordering
visibility
theme settings
category cards
promotional content

Provide Preview mode.

Do not require app rebuild for ordinary CMS content changes.

==============================================================
36. THEME CUSTOMIZER
==============================================================

Admin theme configuration should support:

primary color
secondary color
background
surface
text
radius
elevation
banner style
button style

Customer app must continue using safe defaults.

Invalid theme configuration must fall back safely.

Do not allow admin configuration to create unreadable UI.

==============================================================
37. REGISTRATION FIELD CONFIGURATION
==============================================================

Create configurable registration fields.

Admin can define:

- field name
- label
- type
- required
- validation
- visibility
- ordering
- role applicability

Support owner/customer registration requirements.

Do not remove security-critical backend validation.

==============================================================
38. UNIFIED REGISTRATION
==============================================================

Expand registration to support legitimate roles.

Customer
Owner

Owner onboarding should support:

- personal details
- organization details
- verification/KYC fields where legally required
- organization ownership
- venue information

Backend must validate role assignment.

Never allow user to choose administrator.

==============================================================
39. EXTERNAL APPS / INTEGRATIONS
==============================================================

Create an Integration Hub.

Possible adapters:

Maps
Messaging
Email
SMS
Calendar
Payments
Storage
Analytics
CRM
MCP

Architecture:

Integration
→ Adapter
→ Provider
→ Health check
→ Configuration
→ Logs

Each provider must have:

enabled
disabled
configured
error
health status

Never fake provider support.

==============================================================
40. MCP CONNECTOR ARCHITECTURE
==============================================================

Create a safe MCP adapter layer.

DO NOT invent MCP APIs.

Only connect to actual MCP servers/tools when available.

Architecture:

BookMySpace
    ↓
Integration Manager
    ↓
MCP Adapter
    ↓
MCP Server
    ↓
Tool

All MCP operations must be:

authenticated
authorized
audited
timeout protected
rate limited

No arbitrary tool execution from untrusted users.

==============================================================
41. EXTERNAL API CONNECTOR
==============================================================

Create reusable:

ApiConnector

with:

- base URL
- authentication
- timeout
- retry
- rate limit
- health check
- error mapping
- logging
- circuit breaker

Do not expose credentials to Flutter.

Secrets belong in Edge Functions/server infrastructure.

==============================================================
42. EVENTS
==============================================================

Events must support:

list
detail
register
cancel
capacity
pricing
venue
date/time

Admin can manage events.

Owner permissions must be respected.

==============================================================
43. COURSES
==============================================================

Courses:

list
detail
batches
enroll
drop
capacity
institute

Admin CRUD.

Institute ownership where supported.

No fake enrollments.

==============================================================
44. REVIEWS
==============================================================

Customer:

view reviews
write review after eligible booking
edit where allowed

Owner:

view
reply where authorized

Admin:

moderate
hide
restore

Never fabricate ratings.

==============================================================
45. FAVORITES
==============================================================

Customer:

add favorite
remove favorite
view saved venues

Backend-backed.

Handle offline/network errors gracefully.

==============================================================
46. NOTIFICATIONS
==============================================================

Create centralized notification architecture.

Types:

booking
payment
offer
event
course
support
system

iOS:
APNs-compatible architecture

Android:
FCM-compatible architecture

Web:
browser notifications where supported

Do not assume permission.

==============================================================
47. PROFILE
==============================================================

Profile must show live:

- name
- email/phone
- bookings
- favorites
- courses
- events
- settings

No fake wallet balance.

==============================================================
48. SETTINGS
==============================================================

Settings:

Language
Theme
Notifications
Privacy
Terms
Support
About
Delete account

Delete account must:

authenticated request
→ Edge Function
→ delete user securely
→ sign out

Never delete arbitrary users.

==============================================================
49. DELETE ACCOUNT SAFETY
==============================================================

Require confirmation.

Explain consequences.

Use authenticated self-only deletion.

Never expose service role.

==============================================================
50. ACCESSIBILITY
==============================================================

Support:

Dynamic text sizes
screen readers
semantic labels
contrast
large tap targets
keyboard navigation on Web
reduced motion where possible

Do not sacrifice visual design.

==============================================================
51. RESPONSIVE DESIGN
==============================================================

Must work on:

iPhone
iPad
Android phones
Android tablets
Web desktop
Web tablet
Web mobile

No overflow.

No keyboard obstruction.

No bottom-navigation overlap.

No clipped cards.

No hardcoded screen dimensions.

==============================================================
52. PERFORMANCE / SCALE
==============================================================

Target architecture capable of supporting very large scale,
including approximately 10 crore users.

Do not claim that Flutter alone guarantees 10 crore users.

Design for scale:

- pagination
- indexed queries
- server-side filtering
- server-side sorting
- caching
- CDN
- image optimization
- connection pooling
- rate limiting
- queue/background jobs
- idempotency
- observability
- circuit breakers
- database indexes
- efficient RPCs
- minimal payloads

Never load entire venue tables into Flutter.

Never load all users into Admin UI.

Use pagination.

==============================================================
53. DATABASE
==============================================================

Before adding a migration:

inspect existing schema.

Never duplicate:

tables
columns
functions
policies

Every migration must be:

- idempotent where appropriate
- documented
- tested
- compatible with current production schema

==============================================================
54. RLS
==============================================================

RLS must remain authoritative.

Customer:
only customer data

Owner:
only owned organization/venue data

Admin:
authorized platform scope

Support:
authorized support scope

No:

service-role client in Flutter.

==============================================================
55. AUDIT LOGGING
==============================================================

Admin/Owner sensitive mutations should be auditable.

Record:

actor
action
entity
entity ID
timestamp
result

Never log:

passwords
OTP
secrets
payment secrets

==============================================================
56. ERROR SYSTEM
==============================================================

Create standardized errors:

NetworkError
TimeoutError
AuthError
PermissionError
ValidationError
NotFoundError
ConflictError
PaymentError
IntegrationError

UI must convert them into understandable messages.

Never display raw stack traces to customers.

==============================================================
57. ROUTING
==============================================================

Audit every route.

Every route must:

- exist
- have valid navigation
- have correct auth guard
- support back navigation
- survive app restart where appropriate
- preserve query parameters
- not create duplicate router instances

Explicitly test:

/
/home
/search
/filters
/bookings
/courses
/profile
/owner
/admin

No:

GoException: no routes for location: /

==============================================================
58. BACK BUTTON
==============================================================

Every secondary screen must provide correct back behavior.

iOS:

NavigationBar back

Android:

system back

Web:

browser back

Modal:

dismiss

Filters screen MUST have a visible back control.

==============================================================
59. TEST MODE OWNER / ADMIN
==============================================================

Create a SAFE DEVELOPMENT/TEST ROLE mechanism.

IMPORTANT:

Do NOT create universal admin access.

Do NOT hardcode credentials.

Do NOT bypass RLS.

Use legitimate backend role provisioning.

Development test users may be:

Customer Test
Owner Test
Admin Test
Support Test

Only in a clearly isolated development/test environment.

Production role assignment must remain secure.

==============================================================
60. TEST DATA
==============================================================

Use deterministic development fixtures only where appropriate.

Clearly identify:

DEV
TEST

Never leak development fixtures into production.

No fake payment success.

No fake authentication.

==============================================================
61. WEB
==============================================================

Ensure Web loads actual Flutter.

No static demo shell.

Verify:

routing
refresh
browser back
deep links
authentication
responsive UI
payment checkout
filters
search

==============================================================
62. IOS
==============================================================

Verify on iPhone 15 simulator.

Test:

Home
Search
Filters
Back
GPS
PIN
Auth
Profile
Settings
Owner if available
Admin if available
Booking
Payment
Courses
Events
Reviews
Favorites
Notifications UI
Dark mode
Light mode

No Riverpod lifecycle overlay.

==============================================================
63. ANDROID
==============================================================

Verify on Android emulator/device when available.

Test same flows as iOS.

Do not claim runtime verification if only APK build succeeded.

==============================================================
64. FINAL MASTER ACCEPTANCE
==============================================================

The application is complete only when:

flutter analyze
= 0 issues

flutter test
= all pass

iOS build
= pass

Android build
= pass

Web build
= pass

iOS runtime
= verified

Android runtime
= verified

Web runtime
= verified

No critical navigation errors.

No placeholder Supabase host.

No fake production data.

No fake roles.

No fake payments.

No broken back buttons.

No keyboard overflow.

No route "/ not found".

No infinite loading.

No Riverpod provider mutation errors.

==============================================================
65. CROSS-SITE / MCP INTEGRATION HUB
==============================================================

Implement the integration layer as a first-class modular subsystem.

Supported connector categories may include:

- Maps
- Geocoding
- SMS
- Email
- Calendar
- Payments
- Storage
- Analytics
- CRM
- Messaging
- MCP

Every integration must expose:

configure()
connect()
disconnect()
healthCheck()
execute()
handleError()

The Flutter app communicates only with safe backend adapters.

==============================================================
66. INTEGRATION ADMIN UI
==============================================================

Admin can see:

Integration
Status
Provider
Health
Last checked
Configuration state

Actions:

Configure
Enable
Disable
Test Connection
View Logs

Never display secrets.

==============================================================
67. API HEALTH MONITOR
==============================================================

Admin health dashboard:

Supabase
Razorpay
Storage
SMS
Email
Maps
MCP

Statuses:

Healthy
Degraded
Unavailable
Not Configured

Use real health checks.

==============================================================
68. CIRCUIT BREAKER
==============================================================

External integrations must use bounded retries.

If provider repeatedly fails:

open circuit
stop hammering provider
show degraded state
retry after cooldown

Do not create request storms.

==============================================================
69. RATE LIMITING
==============================================================

Protect:

login
OTP
search
booking
payment order creation
MCP
external APIs

Use server-side rate limits where appropriate.

==============================================================
70. IDEMPOTENCY
==============================================================

Use idempotency for:

booking holds
payment orders
webhooks
critical mutations
external side effects

Duplicate request must not create duplicate business records.

==============================================================
71. ADMIN DASHBOARD
==============================================================

Create polished admin dashboard with:

Users
Owners
Venues
Categories
Subsections
Bookings
Payments
Offers
Events
Courses
Support
Analytics
Integrations
Theme
Content
Audit

Use cards/charts/tables.

All values live.

==============================================================
72. OWNER DASHBOARD
==============================================================

Owner dashboard:

Overview
Venues
Bookings
Time Slots
Blocked Dates
Images
Analytics
Profile
Settings

Owner only sees owned data.

==============================================================
73. ADMIN QUICK EDIT
==============================================================

For every editable entity:

View
Edit
Duplicate where safe
Archive
Delete where safe

Admin should not need code changes for normal content updates.

==============================================================
74. PREVIEW MODE
==============================================================

Admin CMS changes must support:

Draft
Preview
Publish

Preview should show how content appears in the customer application.

==============================================================
75. VERSIONING
==============================================================

For important CMS/config entities support:

version
created_at
updated_at
published_at
updated_by

Allow rollback where practical.

==============================================================
76. MODULAR FEATURE REGISTRY
==============================================================

Every major feature should have a module boundary.

Example:

features/
  auth/
  home/
  search/
  location/
  venues/
  bookings/
  payments/
  courses/
  events/
  reviews/
  favorites/
  notifications/
  owner/
  admin/
  analytics/
  integrations/
  cms/
  localization/

Avoid giant screens/controllers.

==============================================================
77. PLUG-IN UI COMPONENTS
==============================================================

Create reusable components:

GlassCard
GlassImageCard
AnimatedBanner
AdminEditor
CategoryEditor
SubsectionEditor
LocationPicker
ErrorState
LoadingState
EmptyState
RetryButton
PaginatedList
SearchFilterChip
RoleGate
PermissionGate

Do not duplicate implementations.

==============================================================
78. IMAGE CONTENT MANAGEMENT
==============================================================

Admin and Owner image upload must support:

upload
replace
delete
preview
compression
progress
retry

Use Storage.

Do not store giant unoptimized images.

==============================================================
79. LIVE CONFIGURATION
==============================================================

Safe customer-facing configuration can be remotely updated without app rebuild:

- banner content
- category metadata
- feature availability
- theme tokens
- CMS text
- promotional cards

Critical application logic remains versioned in the app/backend.

==============================================================
80. MULTI-LANGUAGE CMS
==============================================================

CMS content must optionally support:

English
Telugu
Hindi
Kannada
Tamil
Malayalam
Marathi

Admin should be able to enter translations.

Fallback:

requested language
→ English
→ safe default

Never show null UI text.

==============================================================
81. ADMIN CATEGORY CREATION FLOW
==============================================================

Admin:

Categories
→ Add Category
→ icon
→ image
→ name
→ description
→ ordering
→ save

Then:

Category
→ Add Subsection
→ name
→ icon
→ image
→ ordering
→ save

Then verify:

Customer Home
→ category appears

Search
→ category appears

Filters
→ category appears

Admin
→ category editable

Owner
→ category selectable

No app rebuild required for ordinary category data.

==============================================================
82. SAFE DELETE
==============================================================

For category/subsection/venue deletion:

Check dependencies.

If referenced:

Archive/deactivate instead of destructive deletion.

Show:

"This item is currently used by X listings."

Do not cascade-delete unrelated production data.

==============================================================
83. SEARCH INDEX CONSISTENCY
==============================================================

When Admin changes category/subsection:

invalidate relevant caches
refresh search
refresh Home category data
preserve existing venue references

Do not leave stale category UI.

==============================================================
84. SELF-HEALING CACHE
==============================================================

Caches must have:

TTL
invalidation
fallback
refresh

After admin mutation:

invalidate affected cache.

Do not require force-closing the app.

==============================================================
85. OBSERVABILITY
==============================================================

Add safe structured logging.

Track:

feature
operation
duration
result
error category

Never log:

passwords
OTP
secrets
tokens
payment secrets

==============================================================
86. PERFORMANCE MONITORING
==============================================================

Monitor:

Home load
Search
Venue details
Booking
Payment order creation
External APIs

Avoid expensive work during build.

==============================================================
87. LARGE DATASETS
==============================================================

Use:

cursor pagination where appropriate
limit
offset where suitable
server-side filters
indexes

Never:

SELECT * entire tables into app.

==============================================================
88. SECURITY
==============================================================

Review:

RLS
RPC grants
SECURITY DEFINER functions
search_path
Edge Function auth
Storage policies
webhook signatures
OAuth redirects
role assignment

Fix actual security problems.

Do not make speculative destructive changes.

==============================================================
89. PAYMENT SECURITY
==============================================================

Razorpay webhook:

verify signature
validate event
validate order
validate amount
validate booking
idempotent processing
confirm server-side

Client cannot mark payment successful.

==============================================================
90. FINAL USER EXPERIENCE
==============================================================

The final application should feel:

Premium
Fast
Simple
Modern
Trustworthy
Colorful but controlled
Visual
Interactive
Professional

Use:

teal
cyan
deep navy
soft violet accents

with restrained 3D/glass effects.

Do NOT turn every screen into a flashy animation.

==============================================================
91. iOS VISUAL QUALITY
==============================================================

Specially check:

safe areas
Dynamic Island
keyboard
bottom navigation
sheets
dialogs
scrolling
back navigation
text scaling
dark mode
light mode

No content under:

Dynamic Island
keyboard
home indicator
bottom navigation

==============================================================
92. ANDROID VISUAL QUALITY
==============================================================

Check:

system back
keyboard
status bar
navigation bar
gesture navigation
dark/light mode

==============================================================
93. WEB VISUAL QUALITY
==============================================================

Check:

desktop
tablet
mobile width

Browser back.

Refresh.

Deep links.

No static HTML demo.

==============================================================
94. TEST MATRIX
==============================================================

Create automated tests for:

routing
auth
role gates
categories
subsections
GPS
PIN
search
filters
favorites
reviews
courses
events
booking
payment state machine
webhook idempotency
owner CRUD
admin CRUD
localization
theme
CMS
integration health
cache invalidation

==============================================================
95. DEVICE TEST MATRIX
==============================================================

iOS:

Home
→ category
→ search
→ filters
→ back
→ GPS
→ PIN
→ venue
→ favorite
→ review
→ booking
→ payment
→ confirmation

Android:

same

Web:

same supported flows

==============================================================
96. NO FALSE ACCEPTANCE
==============================================================

The agent MUST distinguish:

IMPLEMENTED

from:

BUILD VERIFIED

from:

RUNTIME VERIFIED

from:

LIVE BACKEND VERIFIED

from:

BLOCKED BY ENVIRONMENT

Never say "100% complete" if a critical flow was not actually tested.

==============================================================
97. FINAL VERIFICATION REPORT
==============================================================

At the end provide:

1. Files changed
2. Database migrations
3. Edge Functions
4. Storage changes
5. APIs/integrations
6. Feature matrix
7. Tests
8. iOS runtime results
9. Android runtime results
10. Web runtime results
11. Remaining blockers

For every feature:

IMPLEMENTED
BACKEND VERIFIED
IOS VERIFIED
ANDROID VERIFIED
WEB VERIFIED

==============================================================
98. CRITICAL FINAL REQUIREMENT
==============================================================

DO NOT STOP AFTER CODE COMPILATION.

You must run:

flutter analyze
flutter test
flutter build ios --simulator --debug
flutter build apk --debug
flutter build web --debug

Then launch the iOS simulator and actually interact with the application.

If Android runtime is available, launch Android and interact.

If Web runtime is available, open the real Flutter application and interact.

Verify that changes actually appear in the application.

A source-code-only implementation is NOT accepted.

==============================================================
99. PUSH / APP VERIFICATION
==============================================================

After implementation and verification:

1. Confirm changed files.
2. Confirm tests.
3. Confirm builds.
4. Confirm runtime.
5. Confirm the changes are visible in the actual application.
6. Confirm no unrelated files were modified.
7. Confirm no secrets were committed.
8. Confirm no generated credentials were committed.

ONLY AFTER ALL OF THE ABOVE:

If the user explicitly requested push:

git status
git diff --stat
git diff --check

Then create an appropriate commit.

Then push to the currently intended branch/remote.

After push:

verify:

git status
git log -1
git remote -v

Then rebuild/relaunch the app from the pushed/current working tree.

IMPORTANT:

The task is NOT complete merely because Git says push succeeded.

The final requirement is:

CODE → BUILD → INSTALL → LAUNCH → INTERACT → VERIFY

The actual iOS/Android/Web application must reflect the implemented changes.

==============================================================
FINAL COMMAND TO THE AGENT
==============================================================

Work systematically.

Do not rewrite working features.

Do not touch the frozen Explore Verified Spaces / Function Halls matrix.

Fix broken functionality before adding cosmetic enhancements.

Implement missing modules using the existing architecture.

Use real backend data.

Use real authentication.

Use real RLS.

Use real Storage.

Use real Edge Functions.

Use real integrations where available.

Never invent APIs.

Never invent MCP capabilities.

Never invent payment success.

Never invent roles.

Never invent production data.

Make every feature cross-platform.

Make the UI premium, simple, colorful, visual and performant.

Make Owner/Admin management genuinely editable.

Make categories/subsections dynamically manageable.

Make integrations modular.

Make the application resilient.

Make the application maintainable.

Make the application scalable.

Most importantly:

DO NOT JUST WRITE CODE.

VERIFY THAT THE CHANGES ACTUALLY APPEAR AND WORK IN THE iOS APP, ANDROID APP, AND WEB APP.

If something cannot be runtime verified, explicitly report it as BLOCKED instead of claiming completion.
```
