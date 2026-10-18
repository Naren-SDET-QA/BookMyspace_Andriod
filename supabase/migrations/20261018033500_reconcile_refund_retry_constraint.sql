-- The 20260828110000 development hardening migration added a full unique
-- constraint on refunds.payment_id. The later cancellation lifecycle
-- (20260914170000) deliberately replaced that policy with a partial unique
-- index so a failed refund can be retried. Keeping both makes that retry
-- impossible, despite the partial index's intended semantics.
--
-- Forward-only reconciliation: retain the active-refund uniqueness guard,
-- and remove only the superseded full constraint. This does not delete or
-- rewrite refund rows, and is safe to apply to existing installations.
do $migration$
begin
  if not exists (
    select 1
    from pg_index i
    join pg_class idx on idx.oid = i.indexrelid
    join pg_class tbl on tbl.oid = i.indrelid
    join pg_namespace n on n.oid = tbl.relnamespace
    where n.nspname = 'public'
      and tbl.relname = 'refunds'
      and idx.relname = 'refunds_payment_id_active_uq'
      and i.indisunique
      and i.indisvalid
      and i.indpred is not null
      and pg_get_expr(i.indpred, i.indrelid) ~* 'status\s*<>\s*''failed'''
  ) then
    raise exception 'Expected active-refund partial unique index is missing or has an unexpected predicate';
  end if;
end;
$migration$;

alter table public.refunds
  drop constraint if exists refunds_payment_id_unique;
