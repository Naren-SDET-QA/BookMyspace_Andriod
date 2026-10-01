# BookMySpace CMS — Architecture Map (Phase 1 Audit)

Status: **audit only — no code changed.**
Date: 2026-09-14

---

## 1. Headline finding

BookMySpace does not need a CMS built. It has **three separate
content-management mechanisms already in production**, plus one large body of
content that is still hardcoded in Dart. The work is unification, not
construction.

| # | Mechanism | Storage | Admin surface | Content it owns |
|---|-----------|---------|---------------|-----------------|
| A | Feature-flag JSON config | `public.feature_flags.config` (jsonb, keyed by `key`) | Modules / Home layout / Bottom nav | Home composition, bottom bar, module enablement |
| B | Dedicated domain tables | `venue_categories`, `venue_subsections`, `cms_banners`, `venue_sections` | Categories, Home banners | Taxonomy, banners, per-venue sections |
| C | Hardcoded Dart | `home_category_catalog.dart` | *(none)* | 5 master sections, ~28 subsections, titles, emoji, icons, colors, Unsplash image URLs |

Mechanism **A is already a generic keyed content store.** That is the single
most important fact in this audit: `feature_flags` is `(key text primary key,
enabled bool, platforms text[], config jsonb)` with public read and
admin-only write. `home_appearance` and `nav_tabs` are not feature flags in
any meaningful sense — they are CMS documents that happen to live in the flag
table. The generic Content Object layer should extend this, not replace it.

---

## 2. Authoritative backend per area (Phase 13)

**Supabase is authoritative for everything. Firebase is dead code.**

Evidence:

- `pubspec.yaml` declares **no** `firebase_*` or `cloud_firestore` dependency.
- `lib/core/firebase/error_logger.dart` and `performance_service.dart` are
  local no-op stand-ins, explicitly documented as "usable without optional
  Firebase packages".
- No Dart file imports Firestore. The only other mentions are comments in
  `push_notification_service.dart` saying push stays local until a Firebase
  project file is added.
- `firestore.rules`, `firestore.test.js`, `firebase-blueprint.json` and
  `firebase.json` are orphaned artifacts at repo root.

| Area | Authoritative source |
|------|----------------------|
| CMS banners | Supabase `public.cms_banners` |
| Categories / subsections | Supabase `public.venue_categories`, `public.venue_subsections` |
| Modules / feature flags | Supabase `public.feature_flags` |
| Bottom navigation | Supabase `feature_flags` key `nav_tabs` |
| Home appearance | Supabase `feature_flags` key `home_appearance` |
| Venue sections | Supabase `public.venue_sections` |
| Media | Supabase Storage buckets `category-media`, `venue-images` |

**Nothing should be migrated between backends.** Recommend a short note in
`docs/ARCHITECTURE.md` marking the Firebase files as unused, so the next
reader does not repeat this investigation.

---

## 3. Audit answers

**1. What content objects already exist?**
Home blocks (7 kinds), nav tabs (7 destinations), optional modules (12
manifests), CMS banners, venue categories, venue subsections, venue sections,
plus the hardcoded `MainHomeSection` catalog.

**2. What admin screens already edit them?**

| Screen | Route | Lines | Edits |
|--------|-------|-------|-------|
| `owner_categories_screen.dart` | `/admin/categories` | 3376 | Categories + subsections |
| `admin_home_appearance_screen.dart` | `/admin/home-layout` | 787 | Home blocks |
| `admin_nav_tabs_screen.dart` | `/admin/nav-tabs` | 244 | Bottom bar |
| `admin_modules_screen.dart` | `/admin/modules` | 194 | Module flags |
| `admin_cms_screen.dart` | `/admin/cms` | 170 | Banners |

**3. Dedicated tables?** Categories, subsections, banners, venue sections.

**4. Feature flags?** Home appearance, nav tabs, module enablement, AI booking.

**5. JSON/configuration?** `feature_flags.config` jsonb. Home appearance and
nav tabs serialize their whole document into it.

**6. Hardcoded Flutter values?** `home_category_catalog.dart` — the largest
remaining gap. Master section titles, display titles, subtitles, emoji,
`IconData`, accent colors (light + dark), **remote Unsplash image URLs**, and
28 subsection definitions. None of it is admin-editable today.

**7. Supabase Storage?** `category-media` (public read; writes gated by
`private.is_category_manager()`). Home artwork is deliberately namespaced
under `home/` in the same bucket rather than adding a second bucket — see the
rationale comment in `home_media_repository.dart`, which is sound and should
be preserved.

**8. Localization?** Three different mechanisms:
- `app_localizations.dart` — hand-rolled, 5 locales (en/te/hi/kn/ta), 160
  getters, `static const Map<String, Map<String, String>>` tables. No ARB, no
  codegen.
- `HomeBlockConfig.titles` / `.subtitles` — `{lang: text}` maps in flag JSON.
- `venue_categories.name_i18n` / `description_i18n` — jsonb columns.

**9. Separate repositories/providers?** Yes — `SupabaseCmsRepository`,
`SupabaseFeatureFlagRepository`, `HomeMediaRepository`,
`SupabaseAuditRepository`, plus category access through `venue_providers`.
Each admin screen wires its own.

**10. Duplication across admin screens?** Yes, four patterns repeated
independently in each screen: enable/disable toggle, integer-order reordering,
`{lang: text}` localized-text editing, and image upload + preview. Categories
implements all four at high quality; the others implement subsets. This is the
duplication the registry should absorb.

---

## 4. Defects found during audit

### 4.1 BLOCKER — three admin screens cannot save

`public.validate_feature_flag_config()`
(`20260912203000_owner_approval_and_plug_play_modules.sql:948`) validates every
write to `feature_flags` against a hardcoded key allowlist:

```
'gps', 'pin_search', 'offers', 'events', 'courses', 'reviews', 'favorites',
'payments', 'notifications', 'support', 'analytics', 'integrations', 'referrals'
```

`home_appearance`, `nav_tabs` and `ai_booking` are **absent**, yet all three
are live manifest ids in `module_manifests.dart` and two are the storage keys
for entire admin screens:

- `home_appearance_providers.dart` → `homeAppearanceFlagKey = 'home_appearance'`
- `nav_tabs_providers.dart` → `navTabsFlagKey = 'nav_tabs'`

Any save from Home layout, Bottom navigation, or the AI-booking toggle in
Optional modules raises `unsupported_module` and is rejected.

No migration after `20260912203000` redefines the function — confirmed by
grep across all 41 migrations.

Why the test suite misses it: `home_appearance_test.dart`,
`nav_tabs_test.dart` and `feature_flag_test.dart` exercise Dart-side
serialization only. No database participates, so the trigger never runs.

**Confirmed live**, not inferred. Against the `bookmyspace-dev` project
(`zykxneztahxbjduagutv`):

- `select ... from public.feature_flags` returns exactly the 13 allowlist keys.
  `home_appearance`, `nav_tabs` and `ai_booking` have **no rows at all** — no
  admin has ever successfully saved a Home layout or bottom-bar change.
- Every surviving row has `config = '{}'` (length 2), i.e. no composition
  document has ever been persisted.
- `position('home_appearance' in pg_get_functiondef(...))` on the deployed
  `validate_feature_flag_config` returns `0`, and likewise for the other two
  keys.

This must be fixed before any claim that existing CMS features work.

### 4.2 Migration ordering — fresh-database install fails

`20260912154948_revoke_feature_flag_trigger_execute.sql` runs
`revoke all on function public.validate_feature_flag_config()` unguarded, but
that function is not created until `20260912203000`. On an existing project
the revoke succeeded against an out-of-band definition; on a clean
`supabase db reset` it aborts with `function does not exist`.

Fix is additive: wrap in a `do $$ ... if to_regprocedure(...) is not null`
guard, or reorder. Does not affect deployed environments.

---

## 5. Existing precedents worth reusing

**Draft/publish already exists** — `public.venue_sections` has
`published_config`, `published_at`, `published_by` and a
`publish_venue_sections()` RPC. Its `validate_venue_section()` trigger uses a
transaction-local GUC that only the security-definer publish function can set,
so a client cannot forge a publish. The header comment documents a live bug
that was found and fixed in exactly this mechanism. **Phase 10 should extend
this pattern rather than invent a second one.**

**Audit logging already exists** — `public.audit_logs` with
`actor_id / action / entity_type / entity_id / details / ip_address`, read via
`SupabaseAuditRepository`, plus `audit_feature_flag_change()` already firing on
flag writes. `AuditLogEntry.fromJson` already tolerates both `actor_id`/`user_id`
and `details`/`metadata` shapes. **Phase 11 should extend, not duplicate.**

**Safe-action allowlisting partly exists** — `NavTab.branch` maps config to
fixed router branches; the route tree is built at compile time and config only
chooses reachability. `cms_banners.cta_route` is the exception: a free-text
column with no validation. That is where the Phase 7 action enum belongs.

**Fallback-to-default is already the house pattern** — `HomeAppearance.fromJson`,
`NavTabsConfig.fromJson` and `moduleFlagProvider` all return shipped defaults on
missing/malformed config, and both configs re-add any block or tab the admin
never mentioned. Phase 16's CMS-override-else-default rule is already idiomatic
here.

---

## 6. Proposed design

### 6.1 Do not create one giant table

Three storage classes stay where they are:

- **Domain tables** — categories, subsections, banners, venue sections. These
  have real constraints, foreign keys and slugs. They stay.
- **Config documents** — `feature_flags.config` for home appearance and nav
  tabs. Stays.
- **New:** `public.content_objects` for the currently-hardcoded material —
  master sections, subsection presentation, loose text and labels. This is the
  only genuinely new table, and it exists to replace `home_category_catalog.dart`.

### 6.2 Registry as an adapter layer

A `CmsObjectType` descriptor declares, per type, which capabilities it
supports:

```
capabilities: { editText, editImage, editIcon, reorder, toggle,
                localize, preview, publish, create, delete }
```

Each type supplies an adapter that reads and writes through its **existing**
repository. The registry never owns storage. That satisfies "do not force
unsupported capabilities onto an object" — the admin UI renders from the
declared capability set, so banners get no icon editor and modules get no
image editor, without any per-screen branching.

### 6.3 Admin structure

`/admin/content` becomes one hub grouping the **existing** routes:

```
Content Management
├── Categories      → /admin/categories   (existing, unchanged)
├── Banners         → /admin/cms          (existing)
├── Home Sections   → /admin/home-layout  (existing)
├── Navigation      → /admin/nav-tabs     (existing)
├── Modules         → /admin/modules      (existing)
├── Text & Labels   → new
├── Media Library   → new
└── Custom Content  → new
```

No existing screen is replaced or removed. The dashboard's flat 16-link list
gets its five content entries grouped behind one entry; the individual routes
keep working for deep links and bookmarks.

### 6.4 Localization bridge

`app_localizations.dart` stays authoritative for shipped UI strings. A CMS
override layer resolves `l10n key → content_objects lookup → fall back to the
Dart table`. Translations are never deleted from Dart, so an empty database
renders exactly today's app. Category `name_i18n` and `HomeBlockConfig.titles`
keep their existing shapes; the bridge reads all three.

---

## 7. Toolchain constraint — read before approving implementation

`flutter` is **not installed** in either execution environment, and the egress
policy blocks `storage.googleapis.com` and `pub.dev` (HTTP 403 at the proxy) in
both, so it cannot be installed.

Consequences:

- `flutter analyze` — cannot run
- `flutter test` — cannot run
- Android build — cannot run
- Web build — cannot run
- iOS — cannot run (also needs macOS/Xcode, which was already understood)

Any Dart written in this session would be **unverified**: not compiled, not
analyzed, not tested. Given the explicit instruction not to break categories,
banners, flags, modules, navigation, home appearance, booking, payments or
auth, shipping unverified code into this project is not a safe default.

Phase 18 cannot be satisfied here. SQL is the exception — the two defects in
§4 are small, reviewable, additive migrations whose correctness does not depend
on a compiler.

---

## 8. Recommended sequence

1. **Fix §4.1** — extend the flag allowlist so Home layout, Bottom navigation
   and AI booking can save. Small additive migration. Highest value per risk.
2. **Fix §4.2** — guard the premature revoke.
3. **Content object table + registry + adapters** — needs a working Flutter
   toolchain.
4. **Text & Labels, Media Library, unified hub.**
5. **Migrate `home_category_catalog.dart` into the CMS** behind
   override-else-default, one section at a time.

Steps 1–2 are safe to do now. Steps 3–5 need either a local `flutter analyze`
run by you, or network access to the Flutter SDK from this session.

---

## 9. Verification performed

`flutter` is unavailable (§7), so nothing Dart-side was changed. The two SQL
fixes were written **and executed** against a throwaway PostgreSQL 16.13
cluster with a scaffold of `auth.uid()`, `public.audit_logs`,
`public.feature_flags` and the Supabase roles.

| Case | Expected | Result |
|------|----------|--------|
| Original unguarded revoke on fresh DB | aborts | `function ... does not exist` — pre-fix bug reproduced |
| Guarded `20260912154948` on fresh DB | no abort | pass |
| `20260914160000` applies cleanly | applies | pass |
| Save real `HomeAppearance.toJson()` payload | accepted | pass (was `unsupported_module`) |
| Save real `NavTabsConfig.toJson()` payload | accepted | pass (was `unsupported_module`) |
| Save `ai_booking` `{"show_on_home": false}` | accepted | pass (was `unsupported_module`) |
| Unknown key `totally_made_up` | rejected | `unsupported_module` |
| `payments` → `enabled = false` | rejected | `core_module_cannot_be_disabled` |
| `platforms = {blackberry}` | rejected | `unsupported_module_platform` |
| `platforms = {}` | rejected | `module_requires_platform` |
| `config.blocks = "not-an-array"` | rejected | `invalid_home_blocks` |

Telugu text in `titles` round-tripped intact. No existing guard was weakened:
every pre-existing rejection still rejects.

**Not applied to any real database.** Both files are on disk only. Applying
them to `bookmyspace-dev` / `BookMySpace` is your call.

---

## 10. Batch 1 — delivered 2026-09-14

### SQL, applied to `bookmyspace-dev` (`zykxneztahxbjduagutv`)

| Version | File | Effect |
|---------|------|--------|
| `20260914155335` | `..._feature_flag_cms_document_keys.sql` | Allowlists `home_appearance`, `nav_tabs`, `ai_booking`; seeds the three rows |
| `20260914160438` | `..._feature_flag_category_catalog_key.sql` | Allowlists `category_catalog`; adds an `invalid_facility_types` structural check |
| *(edited in place)* | `20260912154948_...` | Guards the premature revoke so a clean reset no longer aborts |

Local filenames were renamed to match the versions the remote history
recorded, so `supabase db push` sees them as already applied.

Verified on live dev — the three previously-rejected saves now succeed with
real client payloads (Telugu text intact), and every pre-existing guard still
rejects: `unsupported_module`, `core_module_cannot_be_disabled`,
`unsupported_module_platform`, `invalid_home_blocks`, `invalid_facility_types`.
RLS policies on `feature_flags` are unchanged, and
`has_function_privilege('anon'|'authenticated', ..., 'execute')` is still
`false` for the validator.

Dev was left neutral afterwards: 16 rows, every config `{}` (or
`{"show_on_home": true}`), **no `category_catalog` row** — so the catalogue
resolves to the shipped defaults and nothing customer-visible changed.

### Dart — model and read path only

| File | Purpose |
|------|---------|
| `lib/features/cms/domain/cms_icon.dart` | Stable icon **id** registry. Never serializes `IconData` |
| `lib/features/cms/domain/cms_localized_text.dart` | base + `{lang: text}` with the fallback chain |
| `lib/features/cms/domain/cms_media_ref.dart` | `url` + storage `path`, http(s) only |
| `lib/features/cms/domain/catalog_content.dart` | Facility Type → Section → Subsection |
| `lib/features/cms/presentation/catalog_content_providers.dart` | Read path over `feature_flags` |
| `test/features/cms/cms_primitives_test.dart` | Icon / text / media unit tests |
| `test/features/cms/catalog_content_test.dart` | Serialization + fallback tests |

Why icon **ids** and not `IconData`: a code point pins content to Flutter's
private glyph numbering, and `--tree-shake-icons` only keeps glyphs it can
prove are used by finding *const* `IconData` constructions. Building an icon
from a backend integer either fails the build or ships the whole font. A const
lookup table keeps tree-shaking working. Ids are semantic (`hall`, `turf`) so
the glyph behind one can change without rewriting stored content.

`CatalogContent.defaults` is **generated from** `MainHomeSection` rather than
retyped, so the fallback cannot drift from the hardcoded catalogue. A test
asserts every default section's icon id resolves to the exact `IconData`
`MainHomeSection.iconData` returns today.

Nothing reads `catalogContentProvider` yet and
`home_category_catalog.dart` is untouched. No entry was added to
`optionalModuleManifests`, deliberately — that list drives the
`/admin/modules` UI, and Batch 1 adds no admin surface. Without a manifest
`moduleFlagProvider` yields `enabled: false`, which lands on the defaults,
which is the correct Batch 1 behaviour for loading, absent and unregistered
alike.

### Two bugs caught during review, before any run

- `CatalogFacilityType.toJson` emitted `facility_sections` while `fromJson`
  read `sections` — a round trip would have silently dropped every section.
- `return const []` inside `_readNodeList<T>` referenced a type parameter from
  a constant expression.

### Verification status — read this before merging

`flutter analyze` and `flutter test` **were not run**, and no claim is made
that they pass. The toolchain is still unavailable (§7). The Dart above has
been reviewed by reading and passes a brace/string balance check only, which
is not a substitute for the analyzer.

The SQL, by contrast, was executed and behaviourally tested — first against a
throwaway PostgreSQL 16.13 cluster, then against live dev.

**Next:** run `flutter analyze && flutter test test/features/cms/` locally and
send back any output. Batch 2 (admin editor, module manifest entry, migrating
render sites behind override-else-default) should not start until Batch 1
analyzes clean.
