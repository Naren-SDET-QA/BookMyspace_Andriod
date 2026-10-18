# Migration ordering — read this before adding or filtering migrations

Every file in this directory is applied, in filename order, to every
environment that runs these migrations — including a fresh dev database,
CI, and production. There is no "dev-only" migration in the sense of
"safe to skip": files named `*_dev.sql`, `*_dev_verify*.sql`, or
`dev_reconciled_*.sql` describe *when they were authored/tested*, not
*where they're allowed to run*. Several of them contain schema
corrections (added columns, dropped columns, renamed constraints) that a
later migration depends on being present — for example
`20260820090200_dev_reconciled_0015_engagement.sql` is what makes
`public.notifications` end up with the `read`/`read_at`/`updated_at`
columns the Flutter client actually uses, correcting a column set
(`is_read`) that an earlier migration (`0006`) created first. Skipping a
"dev" file by name will leave the schema in the state before that
correction — go read the migration content, not the filename, before
deciding a file is optional.

If you're auditing for duplicate `create table`/`create policy`
declarations across files: most duplicates in this directory are
deliberately idempotent (`create table if not exists`, `drop policy if
exists` + `create policy`) and are safe to re-run. A small number are
NOT idempotent (a plain `create table` followed later by a
differently-shaped `create table if not exists` for the same name) —
those are exactly the drift-then-patch pairs described above, and the
patch file is load-bearing, not optional cleanup.

## Duplicate version reconciliation

The two historical files `20260928071656_b4_advance_payment.sql` and
`20260928071656_b5_venue_payment_rules.sql` shared a version that Supabase
cannot record twice. Preserve B4 at its original version. B5's SQL content is
byte-for-byte preserved under the unique forward version
`20261018100000_b5_venue_payment_rules_reconciled.sql`; do not recreate the
duplicate version or edit either migration's SQL in place.

Before applying this reconciliation to any shared environment, compare the
remote migration ledger and schema effects of both migrations. Apply B4 if its
effects are absent; if the effects already exist but the ledger row is absent,
record that legacy state with the environment's approved forward-only
`supabase migration repair --status applied 20260928071656` procedure. Apply
B5 normally when its effects are absent. If B5's effects already exist, record
the new version as applied only after verifying all B5 columns, constraint,
function definitions and grants. Never reset a shared database to resolve
this collision. The connected development database has B4's effects but no
ledger row for its version, and does not yet have B5's effects; no hosted
database was changed by this reconciliation.

The clean-chain reset also revealed that the older
`20260929140000_admin_content_write_guards.sql` expects
`course_faculty.updated_at`, which its table creation migration omitted. The
additive prerequisite migration
`20260929130000_course_faculty_updated_at_prerequisite.sql` now supplies that
column before the guard migration on fresh databases. In an already migrated
environment, verify the column's type, default, nullability and RLS before
repairing the new prerequisite version in the ledger. If it is absent, apply
only this additive statement and then repair that version; do not use
`--include-all` to replay unrelated gaps in an out-of-sync environment.

The forward-only migration
`20261018030126_allow_course_trial_upgrade.sql` corrects the active-enrollment
guard in `enroll_in_course_details`: a learner may upgrade an existing `trial`
row to `enrolled`, while duplicate trials, already-enrolled rows and pending
approval rows remain rejected. Capacity and waitlist checks still run before
the paid-seat transition. The migration replaces the function without editing
the historical waitlist migration; the full-chain SQL regression suite covers
trial-to-paid transition and duplicate enrollment. Apply through normal
migration ordering; do not manually replace the function in a shared database.
