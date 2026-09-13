# Task Prompt — Make Admin → Content Management → Categories functional

Scoped task prompt. Visual reference: `docs/assets/admin-console-categories.png`.
Background and gap analysis: `docs/ADMIN_CONSOLE_SPEC.md`.

## REQUIRED READING BEFORE THE PROMPT BELOW — a conflict you must resolve first

The prompt below asks for two things that cannot both be true as the code stands today:

1. "Do not alter existing UI / Function Halls 3D UI / existing behavior"
2. "If a category/subsection is enabled or disabled by Admin, the customer app should
   immediately reflect that without requiring a new app build"

Master categories are a **Dart enum**, `MainHomeSection`, declared in
`lib/features/home/presentation/home_category_catalog.dart`. An enum's cases are fixed at
compile time. Admin-created or admin-disabled categories therefore cannot be represented at
runtime, and toggling a category in Supabase will change nothing in the app — the app is
rendering a compile-time list. "Without a new app build" is not achievable while that enum
is the model.

`category_glass_matrix.dart` is also typed on that enum. It already receives its data by
constructor injection (`final List<MainHomeSection> sections`, plus live `categories` and
`venues`), which is good — but its parameter *types* are the enum, and line ~115 contains a
hardcoded identity check, `if (selected == MainHomeSection.functionHalls)`. So the enum
cannot be removed without touching this file too.

**The surgical resolution (recommended):** replace the `MainHomeSection` enum with a
`HomeSection` data class carrying the identical fields (title, displayTitle, subtitle,
emoji, iconData, accentColor, accentColorDark, imageUrl, subSections, matrixCells), loaded
from Supabase. In `category_glass_matrix.dart`, change **only** the type signatures and
replace `selected == MainHomeSection.functionHalls` with a model flag such as
`section.usesMatrixLayout`. Every widget, gradient, shadow, tilt, and layout constant stays
byte-identical. The rendered result is unchanged; only the data source changes.

This honours what the freeze was written to protect — the visual design — while making the
feature possible. **Confirm this before running the prompt**, because as literally worded
("do not alter existing UI") an agent will either refuse the task or quietly edit a file it
was told not to touch, and then report success either way.

### Two further items the agent must be explicitly authorised to fix

**The matrix will crash the moment this feature works.** `MainHomeSection.matrixCells`
builds the 3×3 grid with `items.firstWhere((item) => item.slug == slug)` — **no `orElse`** —
over eight hardcoded slugs: `engagement_hall`, `marriage_hall`, `reception_hall`,
`banquet_hall`, `convention_center`, `premium_hall`, `party_hall`, `outdoor_venue`. The
first time an admin disables or deletes any of those eight, `firstWhere` throws
`StateError` and Home breaks. Since the prompt below explicitly enables disable and delete,
this is not a hypothetical. Define the behaviour for a missing cell (empty cell, or fall
back to the master card) and test deleting each of the eight in turn.

**Multilingual fields need new storage.** `venue_categories` currently has only
`id, slug, name, icon` plus a `metadata jsonb` column. There is no `description`,
`image_url`, `display_order`, `seo_slug`, real `is_active`, and no translation storage
anywhere. The "multilingual fields", "SEO slug", "display order" and "supported languages"
controls in the screenshot therefore require new migrations — this is additive and
compatible with "persist through the existing Supabase architecture", but the agent should
not be surprised into inventing a client-side workaround when it finds the columns missing.

---

## THE PROMPT

```text
Implement only the missing functionality in the existing Admin → Content Management →
Categories module shown in the attached screenshot. Do not redesign, remove, or alter
existing UI, Function Halls 3D UI, routing, auth, booking, payment, or existing behavior.
Make every existing control functional: category/subsection CRUD, enable/disable, drag
reorder, icon/image upload/change/remove, multilingual fields, SEO slug, display order,
supported languages, delete confirmation, live preview, search, and instant app refresh.
Persist everything through the existing Supabase architecture with proper Admin RLS, audit
logs, validation, and storage; no fake/local-only data. Ensure the same backend/config
drives Flutter iOS, Android, and Web, test all available platforms, fix only genuine
issues, and do not commit or push.

Also make the Admin configuration plug-and-play: if a category/subsection/module is enabled
or disabled by Admin, the customer app must immediately reflect that without requiring a new
app build.

SCOPE CLARIFICATIONS (these override a literal reading of "do not alter existing UI"):

- The customer-facing VISUAL DESIGN is frozen: no changes to layout, spacing, colours,
  gradients, shadows, tilt, typography or animation of the Function Halls matrix or the
  Explore Verified Spaces section. The rendered pixels must not change.
- The DATA SOURCE is not frozen. Replacing the compile-time MainHomeSection enum with a
  backend-loaded HomeSection model is required and authorised, including the corresponding
  type-signature changes in category_glass_matrix.dart and the removal of the hardcoded
  `selected == MainHomeSection.functionHalls` check in favour of a model flag. Change types
  and data flow only — not visual code.
- You are authorised to fix MainHomeSection.matrixCells' unguarded `firstWhere`, which
  throws StateError when any of its eight hardcoded slugs is disabled or deleted. Define
  and test the missing-cell behaviour.
- You are authorised to add migrations for the missing columns (description, image_url,
  display_order, seo_slug, is_active) and for subsection and translation storage. Inspect
  the existing schema first; do not duplicate existing tables, columns or policies.
- "Immediately reflect" means the running app picks the change up without a rebuild and
  without a force-quit — via realtime subscription or cache invalidation plus refetch.
  State which mechanism you used and demonstrate it.
- Admin writes go through server-side authorised paths with RLS enforced and an audit row
  per mutation. Hiding a control in Flutter is not authorization.
- Deletion follows the safe-delete rule: check dependencies, archive instead of destroying
  when referenced, and tell the admin how many listings are affected.

VERIFICATION — a feature is not done until it is demonstrated end to end:
Admin toggles a category off → customer app (iOS, Android, Web) stops showing it without a
rebuild → admin toggles it back on → it returns. Show this for a category and for a
subsection. Report anything you could not runtime-verify as BLOCKED rather than claiming
completion.
```
