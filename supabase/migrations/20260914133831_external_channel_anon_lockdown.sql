-- ============================================================
-- BookMySpace — External Channel: close anon-role exposure
--
-- AUDIT FINDING (P0, live on bookmyspace-dev before this migration):
-- Every external_channel_*/external_*/inventory_* table and every
-- external-channel RPC still granted privileges to the `anon` role,
-- i.e. any caller holding only the public anon API key with NO
-- Supabase session/JWT at all. This was not written intentionally by
-- 20260914125312/125455/125819/131541 — those migrations run
-- `revoke all ... from public`, but this project's schema has
-- `ALTER DEFAULT PRIVILEGES` granting to `anon` directly (not via the
-- PUBLIC pseudo-role), so `revoke ... from public` never touched it.
--
-- Impact confirmed via pg_proc.proacl / information_schema before this
-- migration was written:
--   - apply_external_reservation_event(...) and
--     record_external_sync_result(...) are SECURITY DEFINER, run with
--     the function owner's privileges (bypassing the tables' RLS
--     policies, which only grant to `authenticated` and therefore
--     block anon at the row level -- but SECURITY DEFINER functions
--     are not restricted by the caller's own RLS), and perform ZERO
--     internal caller-identity check. An anonymous request (no login)
--     to POST /rest/v1/rpc/apply_external_reservation_event with a
--     real connection_id + mapped slot_id could inject a fake
--     "external reservation" that flips a live local booking to
--     external_conflict, or block a venue's availability outright,
--     with no authentication of any kind.
--   - can_manage_external_connection / create_external_channel_connection /
--     disconnect_external_channel_connection / request_external_manual_sync
--     each also grant EXECUTE to anon. These happen to be protected in
--     practice (auth.uid() is null for an anonymous caller, so every
--     one of them returns UNAUTHORIZED/FORBIDDEN internally) but this
--     migration removes the anon grant anyway -- least privilege, and
--     defense-in-depth against a future edit to that internal check.
--   - Every external_channel_*/external_*/inventory_* TABLE grants
--     anon full SELECT/INSERT/UPDATE/DELETE/TRUNCATE. Because every
--     RLS policy on these tables is scoped "to authenticated", a
--     direct PostgREST table request as anon is still blocked at the
--     row level by default-deny RLS -- but the table-level grant is
--     still wrong (least privilege) and is revoked here too, matching
--     the "revoke all ... from public" intent the original migration
--     already stated but did not fully achieve for this role.
--
-- This migration is REVOKE-ONLY. It removes zero privileges from
-- `authenticated` or `service_role`, and changes zero function bodies,
-- zero table columns, zero RLS policies. No legitimate caller (owner
-- via authenticated JWT, or the webhook/sync edge functions via the
-- service_role key) is affected.
-- ============================================================

-- ---- Functions: strip anon EXECUTE ----
revoke execute on function public.apply_external_reservation_event(
  uuid, text, text, text, uuid, uuid, date, bigint, timestamptz, text, jsonb
) from anon;

revoke execute on function public.record_external_sync_result(
  uuid, boolean, integer, text, text, jsonb
) from anon;

revoke execute on function public.can_manage_external_connection(uuid) from anon;
revoke execute on function public.create_external_channel_connection(uuid, text, jsonb) from anon;
revoke execute on function public.disconnect_external_channel_connection(uuid) from anon;
revoke execute on function public.request_external_manual_sync(uuid) from anon;

-- ---- Tables: strip anon's full-privilege grant (RLS already scoped
-- to `authenticated` only, so this is defense-in-depth, not a
-- behavior change for any legitimate caller) ----
revoke all on public.external_channel_providers from anon;
revoke all on public.external_channel_connections from anon;
revoke all on public.external_property_mappings from anon;
revoke all on public.external_room_mappings from anon;
revoke all on public.external_rate_plan_mappings from anon;
revoke all on public.external_reservations from anon;
revoke all on public.external_inventory_events from anon;
revoke all on public.inventory_sync_state from anon;
revoke all on public.inventory_sync_errors from anon;
revoke all on public.inventory_change_log from anon;
