# BookMySpace — Admin Console Spec (from approved design)

Visual reference: `docs/assets/admin-console-categories.png`

This spec turns the approved admin design into buildable requirements. It is written to be
read alongside `BOOKMYSPACE_MASTER_PROMPT.md` (authoritative) and executed via
`docs/MASTER_IMPLEMENTATION_CODEX_PROMPT.md`.

Scope rule for this work: **keep every existing admin capability working, add what the
design shows that does not exist yet.** Nothing currently working may be replaced by a
demo/placeholder version of itself.

---

## 0. THREE BLOCKING DECISIONS — resolve before implementation

These are not style questions. Each one changes what gets built, and two of them conflict
with rules already written into the master prompt.

### BLOCKER 1 — The design requires editing a frozen file

The design's core promise is "Changes appear instantly in the app": an admin edits a
category, and the customer Home reflects it. That is impossible with the current code,
because categories are **hardcoded in Dart**, not backend-driven.

`lib/features/home/presentation/home_category_catalog.dart` (401 lines) hardcodes, per
category: `title`, `displayTitle`, `subtitle`, `emoji`, `iconData`, `accentColor`,
`accentColorDark`, `imageUrl`, the full subsection list, and the 3x3 matrix arrangement.
Live `venue_categories` rows are used only to resolve counts and links at render time —
not for any of the presentation.

That exact file is on the DO-NOT-MODIFY list (master prompt rule 5/6; Codex prompt Phase 2
names it explicitly alongside `category_glass_matrix.dart`).

So one of these must be chosen:

- **(a) Unfreeze the catalog, keep the matrix frozen.** `home_category_catalog.dart`
  becomes a backend-driven data source; `category_glass_matrix.dart` (the visual widget)
  stays untouched and simply renders whatever data it is handed. This is the option that
  makes the design work while preserving the frozen *look*. Recommended.
- **(b) Keep both frozen.** Then admin category management can only affect
  search/filters/listings, and the Home matrix stays static. The "instantly in the app"
  badge in the design would be false for Home and must be reworded.
- **(c) Unfreeze both.** Fastest to build, but abandons the design freeze you put in place
  deliberately. Not recommended.

**The freeze was written to protect the visual design. Option (a) preserves that intent —
the widget's appearance is untouched, only its data source changes.** But this must be
stated explicitly in the prompt, or Codex will either refuse the task or silently edit a
file it was told not to touch.

### BLOCKER 2 — Admin category CRUD will crash Home as currently written

`MainHomeSection.matrixCells` builds the 3x3 Function Halls grid with:

```dart
HomeSubSection bySlug(String slug) =>
    items.firstWhere((item) => item.slug == slug);
```

`firstWhere` has **no `orElse`**. The grid hardcodes eight slugs: `engagement_hall`,
`marriage_hall`, `reception_hall`, `banquet_hall`, `convention_center`, `premium_hall`,
`party_hall`, `outdoor_venue`.

The moment an admin deletes, deactivates, or re-slugs any one of those eight, `firstWhere`
throws `StateError` and the Home screen breaks. Shipping admin category CRUD without
fixing this ships a crash reachable from the admin UI.

Required regardless of which option is chosen in Blocker 1: give the matrix a defined
behavior for a missing cell (empty cell, or fall back to the master card), and cover it
with a test that deletes each of the eight slugs in turn.

### BLOCKER 3 — Is this Flutter Web, or a separate web app?

The design is a ~1536px desktop console: fixed left sidebar, three-column working area,
data-dense tables. The current admin is mobile-shaped Flutter (`admin_dashboard_screen.dart`
is a column of `ListTile` cards).

The master prompt requires one shared codebase across iOS/Android/Web, which points to
**Flutter Web with a responsive desktop layout** for this console, with the existing mobile
admin screens kept as the narrow-width layout. Confirm this, because "build a separate
React admin" is a materially different project and would fork the authorization logic.

---

## 1. Information architecture

Sidebar (collapsible, per the hamburger control):

| Group | Items |
|---|---|
| Dashboard | — |
| Content Management | Categories, Banners, Home Sections, Text & Labels, Media Library, App Theme |
| Venues | — |
| Users & Owners | (expandable) |
| Bookings | — |
| Payments | (expandable) |
| Events | (expandable) |
| Courses | — |
| Reports & Analytics | (expandable) |
| Feature Hub | — |
| Live Editor | — |
| App Settings | (expandable) |

Sidebar footer: product name + version + build string (`BookMySpace v1.0.0`).
Sidebar callout card: "Your changes are live — Updates reflect immediately in the app."
This callout must reflect real publish state, not be decorative.

Top bar: global search ("Search anything..."), **View App** button, language selector
(English), notification bell with unread count, profile menu showing name + role
("Admin / Super Administrator"). Role label must come from the backend role, never a
client-side assumption.

Breadcrumb: `Home / Content Management / Categories`.

## 2. Categories screen (the screen shown)

Page header: title, one-line description, and three actions — **Manage Icons**,
**Reorder**, **Add Category**.

**Stat row (4 cards).** Main category count, subsection count, live-update status,
multi-language summary (EN · తెలుగు · हिंदी · ಕನ್ನಡ · தமிழ்). All counts must be live
queries — not constants.

**Column 1 — Categories list.** Searchable. Each row: icon chip, name, subsection count,
active toggle, overflow menu. Selected row is highlighted. Rows are drag-reorderable
(see Reorder action).

**Column 2 — Edit Category.** Fields:

| Field | Type | Notes |
|---|---|---|
| Category Name | text, required | |
| Description | textarea | character counter, max 200 |
| Icon | icon picker | "Change Icon" + inline swatch grid |
| Category Image | image | upload/replace/remove, thumbnail preview |
| Status | toggle | "Inactive categories will be hidden from the app" |
| Display Order | number | |
| SEO Slug | text | link affordance; uniqueness enforced |
| Supported Languages | checkbox set | EN, TE, HI, KN, TA |

Footer: Cancel / Save Changes. Destructive **Delete Category** sits in the panel header and
must follow the master prompt's safe-delete rule (dependency check → archive if referenced,
with "used by X listings" messaging).

**Column 3 — Subsections (count).** "Add Subsection" action. Each row: drag handle,
thumbnail, name, active toggle, edit, delete. Ordering is persisted.

**Live Preview (App View).** Renders the real customer Home category strip
("Explore Verified Spaces" + category cards) from the same data the app reads, with a
Refresh control. This must render actual app components against draft data — a hand-drawn
imitation of the app would drift from reality and defeat the purpose.

## 3. Current state — what exists today

Accurate as of the migrations dated 2026-09-12.

**Backend, exists:**
- `venue_categories` — but only `id, slug, name, icon` plus a `metadata jsonb` column
  (added in `0019_categories_management.sql`). RLS enabled.
- `cms_banners` — `title, subtitle, image_url, cta_text, cta_route, sort_order, is_active,
  starts_at, ends_at, timestamps`. Already the right shape for the Banners screen.
- `feature_flags` — backs the Feature Hub.
- Dev/test role grants (`20260912180000_grant_dev_test_roles.sql`).
- Secure category management (`20260912194500_secure_category_management.sql`).

**Flutter admin, exists:**
- `admin_dashboard_screen.dart` — console index, 10 entries.
- `admin_directory_screens.dart` — read-only list screens for Users, Owners, Venues,
  Events, Courses, Support; plus `AdminBookingsBlockedScreen` and
  `AdminPaymentsBlockedScreen`, which are literal "not granted by RLS" placeholders.
- `admin_audit_screen.dart`.
- Routes for all of the above.

## 4. Gap — what the design needs that does not exist

**Schema.** `venue_categories` is missing `description`, `image_url`, `display_order`,
`seo_slug`, and a real `is_active` column (currently inferred from `metadata`). Subsections
are not first-class rows at all — they exist only as hardcoded Dart. Per-language
translation storage does not exist.

**Scale.** Design shows 12 main categories / 48 subsections. Code has **5** master sections
and **24** subsections, hardcoded. This is not a data-entry difference; it is the same
freeze/hardcoding problem in Blocker 1.

**Screens with no counterpart:** Home Sections, Text & Labels, Media Library, App Theme,
Live Editor, Feature Hub UI, Reports & Analytics (current analytics is a 97-line flat event
list), App Settings, global search, notification centre, and the desktop shell itself
(sidebar + top bar + breadcrumbs).

**Admin write capability generally.** Today's admin is read-only directories. The design is
an editing console. Every new mutation needs a server-side authorization path and an audit
log entry per master prompt §17 and §55.

**Bookings / Payments.** Currently blocked placeholders. The design shows them as real nav
destinations, which requires resolving the underlying RLS policy question — decide whether
platform-wide read is intended for admin, and implement it in policy, not by client-side
workaround.

**Category images.** The hardcoded catalog currently points at Unsplash URLs. Once images
are admin-managed they must move to Supabase Storage; remote stock URLs as production
content conflict with the master prompt's "no fake production data" and "never use broken
URLs as production content" rules.

## 5. Build order (suggested)

1. Resolve the three blockers above.
2. Schema + RLS + audit for categories/subsections, including the missing columns.
3. Make the category catalog backend-driven; fix the `firstWhere` crash; add tests.
4. Desktop shell (sidebar, top bar, breadcrumbs, responsive fallback to existing mobile).
5. Categories screen end-to-end, including Live Preview against real components.
6. Banners and Feature Hub (backends already exist — cheapest real wins).
7. Remaining CMS screens: Home Sections, Text & Labels, Media Library, App Theme.
8. Reports & Analytics, App Settings, global search, notifications.

Each step follows the master prompt's verification gate: no feature is PASS until it has
been built, installed, launched and visually confirmed on the target platform.
