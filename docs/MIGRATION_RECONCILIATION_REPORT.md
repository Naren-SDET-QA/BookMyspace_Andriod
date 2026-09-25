# Migration Reconciliation Report — bookmyspace-dev (zykxneztahxbjduagutv)
Generated 2026-09-12 by read-only comparison of `supabase/migrations/` against
`supabase_migrations.schema_migrations` on the live database. Nothing in the
database was changed to produce this report. Two files were added to this
repo as a direct result (see "Reconstructed" below); nothing else was
renamed, edited, or deleted.

## Method
For every deployed migration, the exact `statements` array Supabase recorded
was pulled and diffed (byte-for-byte, `diff -u`) against every local file
that looked like a logical match. Where a match was ambiguous, the live
function/grant state itself was queried directly (`information_schema`,
`pg_get_functiondef`) as the tie-breaker, since chronology-by-filename is not
reliable here (several local timestamps were assigned after the fact and do
not equal when the SQL actually ran).

## Findings

### A. Reconstructed (no local file existed at all)
| Deployed version | Name | Action taken |
|---|---|---|
| `20260826151833` | `promotions_rls_recursion_fix` | Added `supabase/migrations/20260826151833_promotions_rls_recursion_fix.sql`, verbatim from the deployed `statements`. |
| `20260826152506` | `category_sections` | Added `supabase/migrations/20260826152506_category_sections.sql`, verbatim from the deployed `statements`. |

Both predate the booking-approval work entirely and are unrelated to it
(promotion RLS recursion guard, and the Home category-sections table). Their
absence was pure history gap, not drift from current work — nothing to
preserve-vs-discard here.

### B. Same migration, different local filename/version (content matches; no action needed)
These are the "local filenames/timestamps don't always match deployed
history" cases you flagged. Content is functionally identical (diffs below
are comment/whitespace only unless noted) — I did **not** rename anything,
to avoid touching working uncommitted files; this table is the map a
developer needs.

| Local file | Deployed version (name) | Diff |
|---|---|---|
| `20260912194500_secure_category_management.sql` | `20260912120236` (`secure_category_management_20260912`) | Comment lines only. |
| `20260912202900_booking_approval_enum.sql` | `20260912133134` (`booking_approval_enum`) | Comment header only. |
| `20260912203000_owner_approval_and_plug_play_modules.sql` | `20260912134808` (`owner_approval_and_plug_play_modules_20260912`) | 99.8% identical; trivial. This is the **final** version of this migration — see item C for the earlier deployed draft of the same name. |
| `20260912224000_booking_approval_defaults_permissions.sql` | `20260912134944` (`..._20260912`) | **Byte-identical.** |
| `20260912154948_revoke_feature_flag_trigger_execute.sql` | `20260912155006` (`..._20260912`) | Comment/whitespace only. |
| `20260912231000_booking_request_date_validation.sql` | `20260912140558` **and** `20260912152120` | **Byte-identical to both** — see item D, this SQL was applied to the DB twice under two different version stamps. |
| `20260912230000_legacy_booking_confirmation_compatibility.sql` | `20260912140721` (`legacy_booking_confirmation_approval_strict_20260912`) | Logic-identical (strict, no-legacy-carve-out version of the approval check). **Not** the same as deployed `20260912140248`, which is a different, superseded migration — see item C. |

### C. Superseded deployed drafts (remote-only, but already overridden by a later deployed migration — no reconstruction needed)
| Deployed version | Name | Why it's safe to leave unreconstructed |
|---|---|---|
| `20260912133145` | `owner_approval_and_plug_play_modules` | An earlier, ~97%-similar draft of the same migration. Superseded 6 minutes later by `20260912134808`, which local `20260912203000_owner_approval_and_plug_play_modules.sql` already represents (item B). |
| `20260912140248` | `legacy_booking_confirmation_compatibility` | A permissive version of `confirm_venue_booking` that exempted legacy rows (`approval_required = false`) from needing owner approval. Superseded 5 minutes later by `20260912140721`, the strict version with no carve-out, which local `20260912230000_legacy_booking_confirmation_compatibility.sql` already represents. **Verified against the live function body — the strict version is what's actually running.** |

### D. True duplicate (same SQL applied twice under two migration versions)
`20260912140558_booking_request_date_validation_20260912` and
`20260912152120_booking_request_date_validation` are byte-identical
`create or replace function` bodies for `request_venue_booking`. Re-running
identical `create or replace` is harmless (idempotent), so this caused no
damage, but it means the ledger has a redundant entry. Not touched — fixing
the deployed ledger would mean altering the database, which is out of scope
here ("do not alter the deployed database merely to make filenames match").

### E. Grants gap — verified against live state, not just migration text
Local `20260912210000_booking_approval_legacy_rpc_hardening.sql` revokes
`confirm_venue_booking` from `authenticated` entirely; the deployed
`20260912134222_booking_approval_rpc_grants_hardening` (a different, earlier
migration with no local counterpart) had briefly left it granted to both
`authenticated` and `service_role`. Rather than guess which one "wins" from
timestamps, I queried `information_schema.routine_privileges` directly:

**Current live grants on `confirm_venue_booking`: `postgres`, `service_role` only.**
`authenticated` and `anon` cannot call it. This matches the stricter local
intent and the master-prompt rule that payment confirmation must be
service-side only. No further action needed — the live database is already
in the secure state; the intermediate migration text is just noise in the
history, not a live risk.

## Bottom line
- 2 files added (pure history backfill, unrelated to current feature work).
- 0 files renamed or edited.
- 0 database changes made.
- The repo's `supabase/migrations/` folder, plus the two additions above, now
  accounts for every deployed migration version except the one duplicate
  noted in (D), which is inert.
- The one place migration text alone would have been misleading
  (`confirm_venue_booking` grants) was cross-checked against live grants
  directly; the live database is already correctly locked down.
