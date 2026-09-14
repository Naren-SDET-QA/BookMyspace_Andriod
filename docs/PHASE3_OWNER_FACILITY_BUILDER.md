# Phase 3 — Owner Facility Builder

Implemented in `BookMyspace_Andriod`. No commit, push, remote migration, or deployment performed.

## Entry point and behavior

Open **Owner venues → a venue's Sections → Facility builder** (the tree icon in the app bar).

The four-step wizard supports facility types, sections, subsections, and a preview. Each level has name/description editing, an icon selector, an optional image address or selection from the existing CMS catalog, enable/disable controls, and move-up/move-down controls. Keys are generated internally. The layout wraps controls on phones and constrains the content width on desktop.

Draft edits remain in the route's working copy during failures. Saving is confirmed only after the repository acknowledges the complete document update. A lost response to initial container creation is reconciled by re-reading before retrying; the existing non-multiple-section unique index prevents duplicate containers. Navigation warns before discarding unsaved edits, and editing/navigation is blocked during writes. Errors include an explicit retry action.

## Architecture and authorization

- Reuses `CatalogContent`, `CatalogFacilityType`, `CatalogSection`, `CatalogSubsection`, `CmsLocalizedText`, `CmsIcon`, `CmsMediaRef`, and field validation from Batch 1/2.
- Reuses `catalogContentProvider` for existing catalog image choices.
- Reuses `venueSectionRepositoryProvider`, `ownerVenueSectionsProvider`, `publishedVenueSectionsProvider`, and the existing repository for all owner persistence/publication.
- Owner documents deliberately parse only their own facility nodes. The global `CatalogContent.fromJson` fallback adds shipped discovery types, which must not be imported into an owner's draft.
- Saves the complete hierarchy into `venue_sections.config.facility_types` in one container per venue. Existing unknown config keys are preserved.
- Uses existing `owns_venue(auth.uid(), venue_id)` RLS and the new section-scoped `publish_venue_section` RPC. Client IDs select resources; they confer no ownership or publishing permission. No client owner ID or service-role key was introduced.
- The existing published snapshot contains the hierarchy. Enabled names/descriptions are also written to the existing `content` field so the unchanged customer venue page can render them.

## Files changed by this phase

| File | Change |
| --- | --- |
| `lib/features/cms/presentation/owner_facility_controller.dart` | Owner working copy, validation, repository adapter, failure/retry handling and publish flow |
| `lib/features/cms/presentation/screens/owner_facility_builder_screen.dart` | Responsive wizard, node editor, image/icon selection and preview |
| `lib/features/venue_sections/presentation/screens/owner_venue_sections_screen.dart` | Import and app-bar entry point only |
| `supabase/migrations/20260914162854_owner_facility_builder.sql` | Idempotent section-type seed |
| `test/features/cms/owner_facility_controller_test.dart` | Eight focused controller tests and in-memory repository fixture |
| `test/features/cms/owner_facility_builder_screen_test.dart` | Full hierarchy workflow at 375px and 1200px, validation, order, visibility and failed-save recovery |
| `test/features/cms/sql/owner_facility_security_test.sql` | Isolated PostgreSQL authorization/snapshot contract harness |
| `docs/PHASE3_OWNER_FACILITY_BUILDER.md` | This implementation and verification report |

Pre-existing uncommitted work and concurrently edited Batch 2 files were preserved. No changes were made by this phase to Function Hall, booking, payment, auth, categories, banners, navigation configuration, modules, the 3D Glass Matrix, or external inventory.

## Database changes

The new migration adds only the `owner_facilities` entry to **existing** `venue_section_types`, with `allows_multiple = false`. There are no new tables, columns, policies, or RPCs. It must be applied through the normal migration process before using the builder against a deployed database. Until then, the builder shows setup/load failure with retry instead of pretending a save succeeded.

The migration was applied and replayed in an isolated PostgreSQL 18 test cluster, together with the existing venue-section migration. The security harness uses minimal auth/venue dependency fixtures and the same organization ownership predicate; it is not a live Supabase integration test. It asserts:

- An owner can save and publish their own venue's section.
- Another venue ID cannot be used to insert, read, update, or publish another owner's draft.
- Anonymous draft reads and publication are denied.
- Forged insert snapshots are stripped and direct snapshot updates are denied.
- Customer reads remain at the last published content after a subsequent draft edit.
- Duplicate facility containers are rejected and the seed is idempotent.

All assertions passed. The test cluster was stopped afterwards. No live database was changed.

To reproduce, create a disposable database named `phase3_owner_facility_test` on an isolated PostgreSQL cluster, then run:

```text
psql -v ON_ERROR_STOP=1 -d phase3_owner_facility_test -f test/features/cms/sql/owner_facility_security_test.sql
```

The harness refuses a different database name and rolls back its fixture changes.

## Verification results

- **Phase 3 tests: 10 passed** (eight controller tests, two responsive widget workflows).
- **`flutter test test/features/cms/`: 100 passed, 10 failed.** The failures are in untouched Batch 2 files: three existing catalog validation tests and seven admin catalog screen tests. The owner builder tests all passed. Batch 2 files changed concurrently during this session; an initial missing-import compile error was corrected outside this phase before the final run.
- **`flutter analyze`: 10 findings, exit 1.** Five existing unawaited-future warnings and five existing deprecations; no analyzer errors and no findings in the new owner controller or wizard.
- **`flutter test --concurrency=2`: 516 passed, 10 failed.** The same three catalog validation and seven admin screen tests failed. This broader run preceded the final three added controller assertions, which passed in the final CMS run.
- **`git diff --check`: passed.**
- A Flutter web preview compiled and was served locally. The browser remained behind the existing application startup/timeout shell; an isolated host retry did not produce a usable browser view. **Browser end-to-end/visual verification is incomplete.** No web bootstrap files were edited. The temporary preview tab, server, and source harness were cleaned up.

The failed Batch 2 tests cover shipped-default validation, empty/unlinked-section validation, admin title publishing, payload publication, publication rejection, visibility, shipped-item deletion protection, and adding facility types/sections. This phase does not change those global catalog behaviors.

## Limitations and boundaries

- Facility types created here are scoped to this venue; owners cannot modify the global discovery taxonomy.
- The legacy section manager retains its venue-wide publish RPC. The facility builder uses `publish_venue_section`, which snapshots only its authorized facility container.
- The unchanged customer page renders the enabled hierarchy as text. Node icons/images are retained in the published CMS configuration and shown in the builder preview; a richer customer renderer is outside this owner-only phase.
- Unsaved changes survive network failures while the route remains open. They are not persisted through browser refresh, process termination, or device restart. Saved drafts do persist on the server.
- Concurrent editors use the existing repository's last-write-wins behavior; no conflict-resolution system was added.
- Image selection uses existing catalog artwork or an image address. This phase does not add uploads, a media library, or new external API integrations.
- The text summary is limited to the existing 8,000-character venue-section field. Base-language editing preserves existing translation overrides but does not expose a multilingual editor.
- No AI, MCP feature, advanced capabilities, or later-phase work was implemented.

Stopped after Phase 3. No commit. No push.
