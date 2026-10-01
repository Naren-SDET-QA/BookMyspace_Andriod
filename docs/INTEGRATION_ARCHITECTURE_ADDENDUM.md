> SUPERSEDED: the user has since provided a complete, self-contained master prompt (BOOKMYSPACE_MASTER_PROMPT.md at the repo root), which folds this integration-hub content into its own sections 65-70 in a revised form. Use BOOKMYSPACE_MASTER_PROMPT.md as the canonical document going forward; this file is kept only for history.

# BookMySpace — Master Prompt Addendum: External Sites / MCP / API Integration Hub (Sections 65–99)

> Note: I could not locate the actual "master prompt" document (the one already containing sections 1–64) anywhere reachable from this session — it isn't in this repo (`~/BookMyspace_Andriod` on this Mac) and is most likely on the Windows machine (`bookmyspace-grok` project) referenced in earlier work, which this session has no access to. This file holds the new sections exactly as drafted so nothing is lost; paste it into the real master prompt at the right spot, or tell me where that file actually lives if it's reachable some other way.

## Key architecture point (apply throughout all sections below)

For "other sites + MCP API + iOS + Android + Web", the coding agent must not put API calls directly into Flutter widgets. Every external integration must flow:

```
Flutter → Repository → Supabase Edge Function → External API/MCP
```

This matters especially for this app given it already has Razorpay secrets, Supabase service-role credentials, OAuth, webhooks, and Owner/Admin permissions, with more integrations likely coming. Keeping the connector layer server-side prevents iOS/Android/Web from becoming three divergent implementations.

Hard rule for the agent: **if an external website has no official API/MCP/SDK, do not scrape it or invent an endpoint.** Use an official deep link/website handoff, or mark the integration "Not configured." This is what keeps the plug-and-play architecture maintainable instead of turning into a pile of fragile integrations.

=============================================================
65. EXTERNAL SITES / MCP / API INTEGRATION HUB
=============================================================

BookMySpace MUST be architected to integrate with external websites,
third-party APIs, MCP services, SaaS platforms and partner systems.

The integration architecture MUST work consistently on:

- iOS
- Android
- Web

Do NOT implement integrations separately inside individual Flutter screens.

Use a centralized integration layer:

Flutter UI
   ↓
Feature/Domain layer
   ↓
Integration Repository
   ↓
Supabase Edge Function / secure backend API
   ↓
External API / Website / MCP
   ↓
Normalized BookMySpace response
   ↓
Flutter state
   ↓
iOS / Android / Web UI

=============================================================
66. MCP INTEGRATION
=============================================================

Create a modular MCP integration architecture.

The app must be able to connect to legitimate MCP-compatible services
where the service/API actually supports MCP.

Examples of possible integrations:

- venue discovery
- maps/location
- travel
- accommodation
- events
- education
- messaging
- analytics
- AI assistants
- business services
- external marketplace/partner systems

Do NOT assume an external site supports MCP.

First detect/verify its actual API/MCP capability.

If MCP is unavailable:

Use the provider's official API if available.

If neither is available:

mark the integration:

"Not configured"

instead of creating fake functionality.

=============================================================
67. EXTERNAL API CONNECTOR FRAMEWORK
=============================================================

Create a reusable connector architecture.

Example conceptual structure:

ExternalIntegration
IntegrationProvider
IntegrationConfig
IntegrationRepository
IntegrationHealth
IntegrationResult
IntegrationError

Each provider should support:

connect
disconnect
healthCheck
authenticate
refreshToken
fetch
create
update
delete
sync

Only implement operations supported by the external provider.

=============================================================
68. ADMIN INTEGRATION MANAGEMENT
=============================================================

Add:

Admin
→ Integrations

Each integration should display:

Provider
Status
Connection
Last successful sync
Last error
API availability
Enabled platforms
Configuration
Health
Actions

Statuses:

Connected
Disconnected
Configuration Required
Authentication Required
Rate Limited
Unavailable
Maintenance

Admin should be able to:

Enable
Disable
Reconnect
Test Connection
View Health
Configure non-secret settings

Secrets MUST NOT be displayed.

=============================================================
69. SECRET MANAGEMENT
=============================================================

External API credentials MUST NEVER be stored in:

- Flutter source
- Dart constants
- Git
- Android source
- iOS source
- Web JavaScript
- localStorage
- SharedPreferences

Use secure server-side environment/secret storage.

Examples:

Supabase Edge Function secrets
server environment variables
secure secret manager

Flutter receives only safe configuration.

=============================================================
70. OAUTH / API AUTHENTICATION
=============================================================

Where an external provider supports OAuth:

Flutter:

Start OAuth
→ provider
→ callback
→ secure backend
→ encrypted/secure token storage

Never expose:

client secret
refresh token
private API key

Implement token refresh.

Handle:

expired token
revoked token
permission denied
provider unavailable

=============================================================
71. EXTERNAL WEBSITE INTEGRATION
=============================================================

For external websites, distinguish between:

A. Official API available
B. Official SDK available
C. OAuth integration available
D. Deep-link/web URL only
E. No supported integration

NEVER scrape or automate a website in a way that violates its
terms or security controls.

When only a website URL is supported:

open it using:

iOS → universal/deep link or browser
Android → app/deep link/browser
Web → browser/web navigation

The UI must clearly indicate:

"Continue on partner website"

instead of pretending the transaction occurs inside BookMySpace.

=============================================================
72. MULTI-PLATFORM INTEGRATION CONTRACT
=============================================================

Every integration must expose one platform-neutral Dart contract.

Example:

abstract class ExternalProvider {
  Future<IntegrationHealth> healthCheck();
  Future<IntegrationResult> execute(...);
}

Platform-specific code is allowed ONLY for:

- native authentication
- native SDK
- camera
- GPS
- notifications
- payments
- deep links
- OS sharing
- other genuine platform requirements

Business logic must remain shared.

=============================================================
73. MCP/API DATA NORMALIZATION
=============================================================

External provider data must NOT leak provider-specific models throughout
the application.

Convert:

ExternalVenue
ExternalEvent
ExternalCourse
ExternalLocation
ExternalBooking

into BookMySpace domain models.

Example:

External Provider
      ↓
Provider Adapter
      ↓
BookMySpace Venue
      ↓
Existing Venue UI

This allows providers to be replaced without rewriting the app.

=============================================================
74. SYNC ENGINE
=============================================================

Where appropriate, support:

Initial sync
Incremental sync
Manual sync
Scheduled sync
Retry
Conflict handling
Last sync timestamp

Never duplicate records.

Use provider IDs:

provider
provider_record_id

with unique constraints where appropriate.

Use idempotency keys for mutations.

=============================================================
75. EXTERNAL DATA CACHE
=============================================================

Cache safe read-only external data.

Store:

provider
record ID
normalized payload
last fetched
expires_at

Use:

cache-first where appropriate
network-first for critical current data

Never cache payment authorization as truth.

Never cache booking confirmation as truth.

=============================================================
76. RATE LIMITING / BACKOFF
=============================================================

External APIs may rate-limit.

Handle:

429
5xx
timeouts
connection failures

Use bounded exponential backoff.

Do not retry indefinitely.

Do not retry unsafe mutations unless idempotency is guaranteed.

Show friendly UI:

"Service temporarily unavailable."

Retry.

=============================================================
77. INTEGRATION FAILURE ISOLATION
=============================================================

If an external provider fails:

BookMySpace core functionality MUST continue working.

Example:

Maps provider unavailable

→ manual location still works.

External event provider unavailable

→ BookMySpace events still work.

AI/MCP unavailable

→ normal search still works.

External partner unavailable

→ BookMySpace must not crash.

Use circuit-breaker style behavior where appropriate.

=============================================================
78. INTEGRATION HEALTH MONITORING
=============================================================

Admin:

Integrations
→ Provider
→ Health

Show:

Last successful request
Latency
Failure rate
HTTP/API status
Authentication status
Rate-limit status
Last error

Do not expose credentials.

=============================================================
79. WEB COMPATIBILITY
=============================================================

External integrations must work in browsers.

Check:

CORS
OAuth redirect
popup restrictions
deep links
HTTPS
browser storage security

If an SDK is native-only:

use official Web API/JavaScript SDK if available.

Do not import native-only packages into Web execution paths.

=============================================================
80. IOS COMPATIBILITY
=============================================================

For every integration verify:

- iOS URL schemes
- universal links
- OAuth callback
- App Transport Security requirements
- permission descriptions
- native SDK initialization
- lifecycle handling
- background/foreground recovery

No integration may work only because Android behavior was copied.

=============================================================
81. ANDROID COMPATIBILITY
=============================================================

Verify:

- intent filters
- app links
- OAuth callback
- permissions
- native SDK
- lifecycle
- activity recreation

=============================================================
82. MCP / API FEATURE FLAGS
=============================================================

Each integration must have:

enabled
disabled
maintenance
platform availability

Example:

Integration:
Google Maps

iOS: enabled
Android: enabled
Web: enabled

Integration:
Native Provider SDK

iOS: enabled
Android: enabled
Web: official web fallback

Do not enable an integration on a platform where it cannot work.

=============================================================
83. ADMIN "ADD INTEGRATION"
=============================================================

Admin should be able to add an integration through a generic form.

Fields:

Name
Provider
Type
Base URL
Authentication type
Capabilities
Enabled
Platforms
Sync interval
Timeout
Retry policy
Display name
Icon
Documentation URL

Secrets are entered into secure backend secret storage.

Admin UI should show:

Configured ✓

not the actual secret.

=============================================================
84. PLUG-AND-PLAY CONNECTOR REGISTRY
=============================================================

Create a provider registry.

Conceptually:

IntegrationRegistry

Providers can register:

MapsProvider
PaymentProvider
MessagingProvider
EventProvider
CourseProvider
VenueProvider
AnalyticsProvider
McpProvider
NotificationProvider

The rest of BookMySpace should depend on interfaces, not concrete
providers.

This makes providers replaceable.

=============================================================
85. EXTERNAL PROVIDER FALLBACKS
=============================================================

Where multiple providers are configured:

Primary
Secondary
Fallback

Example:

Primary Maps API
→ failure
→ Secondary Maps API
→ manual location

Never silently switch providers for financial transactions.

Payments must use the explicitly configured payment provider.

=============================================================
86. MCP TOOL SAFETY
=============================================================

MCP tools must be explicitly allowlisted.

For each tool:

name
description
read/write
required permissions
allowed roles
rate limit
confirmation requirement

Dangerous mutations require explicit confirmation.

Examples:

Read venue:
safe read

Create venue:
Owner confirmation

Delete venue:
Owner/Admin confirmation

Payment:
never execute automatically through an uncontrolled MCP tool.

=============================================================
87. ADMIN MCP MANAGEMENT
=============================================================

Admin:

Integrations
→ MCP

Display:

Server
Status
Tools
Permissions
Last health check
Last error

Admin can:

Enable
Disable
Test
Configure
View tool list

Do NOT allow arbitrary remote MCP servers to execute privileged
BookMySpace database operations without authorization.

=============================================================
88. EXTERNAL BOOKING PARTNERS
=============================================================

If external booking providers are integrated:

Show clearly:

Book on BookMySpace

OR

Continue with partner

Do not mix external booking state with BookMySpace booking state.

External booking IDs must be stored separately.

=============================================================
89. EXTERNAL SITE DEEP LINKS
=============================================================

Implement platform-neutral deep-link service.

Examples:

Call
WhatsApp
Maps
Email
Website
Partner booking
Social sharing

iOS:
URL schemes/universal links

Android:
intent/app links

Web:
browser navigation

Gracefully fall back if the app is not installed.

=============================================================
90. INTEGRATION TESTING
=============================================================

For every provider test:

1. configured
2. not configured
3. valid credentials
4. invalid credentials
5. expired credentials
6. timeout
7. 4xx
8. 5xx
9. rate limit
10. empty response
11. malformed response
12. duplicate response
13. retry
14. disable integration

Never use production secrets in tests.

Use provider sandbox/test environments where available.

=============================================================
91. IOS / ANDROID / WEB ACCEPTANCE
=============================================================

For EVERY external integration:

iOS:
real interaction where possible

Android:
real interaction where possible

Web:
real browser interaction

Build success alone is NOT acceptance.

Acceptance requires:

Flutter UI
→ backend
→ provider
→ response
→ visible UI

=============================================================
92. EXTERNAL API DOCUMENTATION
=============================================================

For each integration document:

Provider
Official API/MCP URL
Capabilities
Authentication
Required permissions
Environment variables
Webhook
Rate limits
Supported platforms
Fallback
Failure behavior

Never put secret values in documentation.

=============================================================
93. WEBHOOK INTEGRATIONS
=============================================================

Where providers support webhooks:

Provider
→ secure webhook endpoint
→ signature verification
→ idempotency
→ normalized event
→ database update
→ Flutter refresh

Never trust client callbacks as authoritative.

Verify webhook signatures.

Store event IDs.

Prevent duplicate processing.

=============================================================
94. MCP + ADMIN + OWNER PERMISSIONS
=============================================================

Customer:
read-only tools only where appropriate.

Owner:
tools limited to owned resources.

Admin:
platform management tools.

Super Admin:
highest administrative operations.

Backend must enforce permissions.

Flutter hiding a button is NOT authorization.

=============================================================
95. "OTHER SITES" REQUIREMENT
=============================================================

Do not hardcode one external site into the entire app.

Build a reusable connector system so additional providers can be added
later without redesigning Flutter.

Example:

Provider A
Provider B
Provider C

all implement:

ExternalProvider

Then BookMySpace can add/remove providers without changing:

Home
Search
Venue
Booking
Admin
Owner

screens.

=============================================================
96. FINAL INTEGRATION VERIFICATION
=============================================================

Before declaring complete:

List every external integration.

For each:

Provider:
Type:
Official API/MCP:
Authentication:
Backend:
iOS:
Android:
Web:
Webhook:
Error handling:
Fallback:
Admin configuration:
Owner/customer permissions:
Tests:

Status:

PASS
PARTIAL
BLOCKED

Never call an integration PASS without actual evidence.

=============================================================
97. IMPORTANT — DO NOT INVENT MCP/API SUPPORT
=============================================================

If I say:

"Integrate with X"

you MUST first inspect whether X provides:

- official API
- official SDK
- MCP server
- OAuth
- webhook
- deep links

If none exists:

do not invent an API endpoint.

Report:

"Provider does not expose a supported integration path."

Then implement the closest legitimate option.

=============================================================
98. ARCHITECTURE GOAL
=============================================================

The final architecture should look conceptually like:

                   BOOKMYSPACE
                        │
             ┌──────────┴──────────┐
             │                     │
          Flutter               Backend
       iOS/Android/Web        Supabase/Edge
             │                     │
             └──────────┬──────────┘
                        │
              Integration Layer
                        │
       ┌────────┬───────┼────────┬────────┐
       │        │       │        │        │
      API      MCP    OAuth    Webhook   SDK
       │        │       │        │        │
       └────────┴───────┴────────┴────────┘
                        │
                 External Providers

Core BookMySpace functionality MUST remain operational even if
external integrations are unavailable.

=============================================================
99. FINAL PUSH REQUIREMENT
=============================================================

After all integrations are implemented and verified:

1. flutter analyze
2. flutter test
3. iOS simulator build
4. Android build
5. Web build
6. iOS runtime verification
7. Android runtime verification if device exists
8. Web runtime verification
9. Integration health checks
10. git diff --check
11. git status

Then, ONLY if I explicitly asked for push:

commit the verified implementation
and push the current branch.

The pushed commit MUST contain exactly the implementation that was
verified.

Do not push an unverified or partially implemented integration.
