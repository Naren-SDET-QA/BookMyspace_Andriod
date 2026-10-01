-- B3: wallet/referral credit at checkout. Wallet rows are ledger entries;
-- clients never write a debit directly and the server caps the amount.

alter table public.venues
  add column if not exists allow_wallet_credit boolean not null default false;

alter table public.bookings
  add column if not exists wallet_credit_amount numeric(12,2) not null default 0;

alter table public.bookings
  drop constraint if exists bookings_wallet_credit_amount_check;
alter table public.bookings
  add constraint bookings_wallet_credit_amount_check
  check (wallet_credit_amount >= 0 and wallet_credit_amount <= total_amount);

create or replace function public.wallet_available_balance(p_user_id uuid default auth.uid())
returns numeric
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select coalesce(sum(
    case when direction = 'credit' then amount else -amount end
  ) filter (where status = 'posted'), 0)::numeric(12,2)
    from public.wallet_ledger
   where user_id = p_user_id
     and p_user_id = auth.uid();
$$;

revoke all on function public.wallet_available_balance(uuid) from public, anon;
grant execute on function public.wallet_available_balance(uuid) to authenticated;

create or replace function public.apply_booking_wallet_credit(
  p_booking_id uuid,
  p_requested_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b public.bookings;
  v public.venues;
  v_balance numeric(12,2);
  v_credit numeric(12,2);
  v_lock_key bigint;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found' using errcode = 'P0002'; end if;
  if b.user_id is distinct from auth.uid() then
    raise exception 'not_booking_owner' using errcode = '42501';
  end if;
  select * into v from public.venues where id = b.venue_id;
  if not found or not v.allow_wallet_credit then
    return jsonb_build_object('applied_amount', 0, 'wallet_enabled', false);
  end if;

  v_lock_key := hashtextextended('wallet:' || auth.uid()::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  select coalesce(sum(case when direction = 'credit' then amount else -amount end)
    filter (where status = 'posted'), 0)
    into v_balance
    from public.wallet_ledger
   where user_id = auth.uid();

  select coalesce(amount, 0) into v_credit
    from public.wallet_ledger
   where user_id = auth.uid()
     and source_type = 'booking_wallet_credit'
     and source_id = b.id
     and direction = 'debit'
   limit 1;
  if found then
    return jsonb_build_object('applied_amount', v_credit, 'wallet_enabled', true, 'idempotent', true);
  end if;

  v_credit := least(
    greatest(0, coalesce(p_requested_amount, 0)),
    greatest(0, coalesce(v_balance, 0)),
    greatest(0, b.total_amount)
  );
  v_credit := round(v_credit, 2);
  if v_credit > 0 then
    insert into public.wallet_ledger(
      user_id, direction, amount, currency, status, source_type, source_id, description
    ) values (
      auth.uid(), 'debit', v_credit, b.currency, 'posted',
      'booking_wallet_credit', b.id, 'Wallet credit used for booking'
    );
    update public.bookings
       set wallet_credit_amount = v_credit, updated_at = now()
     where id = b.id;
  end if;

  return jsonb_build_object(
    'applied_amount', v_credit,
    'wallet_enabled', true,
    'remaining_balance', greatest(0, coalesce(v_balance, 0) - v_credit)
  );
end;
$$;

revoke all on function public.apply_booking_wallet_credit(uuid, numeric) from public, anon;
grant execute on function public.apply_booking_wallet_credit(uuid, numeric) to authenticated;

-- Atomically resolve the server quote and reserve the wallet debit before a
-- provider order is created. This prevents a client from changing the amount
-- between quote and checkout.
create or replace function public.prepare_booking_payment(
  p_booking_id uuid,
  p_payment_plan text default 'full',
  p_wallet_credit numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b public.bookings;
  h public.booking_holds;
  v_quote jsonb;
  v_wallet jsonb;
  v_advance numeric(12,2);
  v_credit numeric(12,2);
  v_payable numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  select * into b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found' using errcode = 'P0002'; end if;
  if b.user_id is distinct from auth.uid() then
    raise exception 'not_booking_owner' using errcode = '42501';
  end if;
  if b.status <> 'pending' or b.approved_at is null then
    raise exception 'owner_approval_required' using errcode = '55000';
  end if;
  if b.payment_expires_at is not null and b.payment_expires_at <= now() then
    raise exception 'payment_window_expired' using errcode = '55000';
  end if;
  if b.hold_id is null then
    raise exception 'booking_hold_expired' using errcode = '55000';
  end if;
  select * into h from public.booking_holds where id = b.hold_id for update;
  if not found or h.status <> 'active' or h.expires_at <= now() then
    raise exception 'booking_hold_expired' using errcode = '55000';
  end if;

  v_quote := public.calculate_booking_payment_quote(p_booking_id, p_payment_plan);
  v_advance := greatest(0, (v_quote->>'advance_amount')::numeric);
  v_wallet := public.apply_booking_wallet_credit(p_booking_id, p_wallet_credit);
  v_credit := greatest(0, coalesce((v_wallet->>'applied_amount')::numeric, 0));
  v_payable := greatest(0, round(v_advance - v_credit, 2));

  update public.bookings
     set payment_plan = v_quote->>'payment_plan',
         advance_percentage = (v_quote->>'advance_percentage')::numeric,
         advance_amount = v_advance,
         balance_due = greatest(0, round((v_quote->>'balance_due')::numeric, 2)),
         wallet_credit_amount = v_credit,
         updated_at = now()
   where id = b.id;

  return v_quote || jsonb_build_object(
    'wallet_credit_amount', v_credit,
    'payable_amount', v_payable
  );
end;
$$;

revoke all on function public.prepare_booking_payment(uuid, text, numeric) from public, anon;
grant execute on function public.prepare_booking_payment(uuid, text, numeric) to authenticated;

create or replace function public.release_booking_wallet_credit(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b public.bookings;
  d public.wallet_ledger;
begin
  select * into b from public.bookings where id = p_booking_id for update;
  if not found or b.user_id is distinct from auth.uid() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select * into d from public.wallet_ledger
   where user_id = auth.uid() and source_type = 'booking_wallet_credit'
     and source_id = b.id and direction = 'debit'
   order by created_at desc limit 1;
  if not found then return jsonb_build_object('reversed_amount', 0); end if;

  insert into public.wallet_ledger(
    user_id, direction, amount, currency, status, source_type, source_id, description
  ) values (
    auth.uid(), 'credit', d.amount, d.currency, 'posted',
    'booking_wallet_credit_reversal', b.id, 'Wallet credit returned after payment order failure'
  ) on conflict (user_id, source_type, source_id, direction) do nothing;
  update public.bookings set wallet_credit_amount = 0, updated_at = now()
   where id = b.id;
  return jsonb_build_object('reversed_amount', d.amount);
end;
$$;

revoke all on function public.release_booking_wallet_credit(uuid) from public, anon;
grant execute on function public.release_booking_wallet_credit(uuid) to authenticated;

-- Wallet-only checkout is still a server payment: it creates a captured
-- wallet payment and confirms only after approval/hold validation.
create or replace function public.settle_booking_with_wallet(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  quote jsonb;
  b public.bookings;
  p public.payments;
begin
  quote := public.prepare_booking_payment(p_booking_id, 'full',
    coalesce((select total_amount from public.bookings where id = p_booking_id), 0));
  if greatest(0, (quote->>'payable_amount')::numeric) > 0 then
    raise exception 'wallet_balance_insufficient' using errcode = '55000';
  end if;
  select * into b from public.bookings where id = p_booking_id for update;
  insert into public.payments(
    booking_id, user_id, provider, amount, currency, status, method,
    is_refundable, metadata
  ) values (
    b.id, auth.uid(), 'wallet', b.total_amount, b.currency, 'captured', 'wallet',
    false, jsonb_build_object('wallet_only', true)
  ) on conflict (provider, provider_order_id) do nothing
  returning * into p;
  update public.bookings set status = 'confirmed', confirmed_at = coalesce(confirmed_at, now()), updated_at = now()
   where id = b.id and status = 'pending';
  if b.hold_id is not null then
    update public.booking_holds set status = 'confirmed'
     where id = b.hold_id and status = 'active';
  end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, details)
  values (auth.uid(), 'wallet_payment_captured', 'booking', b.id,
    jsonb_build_object('payment_id', p.id, 'amount', b.total_amount));
  return quote || jsonb_build_object('wallet_only', true, 'payment_id', p.id);
end;
$$;

revoke all on function public.settle_booking_with_wallet(uuid) from public, anon;
grant execute on function public.settle_booking_with_wallet(uuid) to authenticated;

-- Extend the quote with the current wallet capability/balance for the
-- presentation layer. The order RPC still recalculates and caps the value.
create or replace function public.calculate_booking_payment_quote(
  p_booking_id uuid,
  p_payment_plan text default 'full'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  b public.bookings;
  v public.venues;
  v_plan text := lower(coalesce(trim(p_payment_plan), 'full'));
  v_advance numeric(12,2);
  v_total numeric(12,2);
  v_wallet numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if v_plan not in ('full', 'advance') then
    raise exception 'invalid_payment_plan' using errcode = '22023';
  end if;
  select * into b from public.bookings where id = p_booking_id;
  if not found then raise exception 'booking_not_found' using errcode = 'P0002'; end if;
  select * into v from public.venues where id = b.venue_id;
  if not found then raise exception 'venue_not_found' using errcode = 'P0002'; end if;
  if b.user_id is distinct from auth.uid() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  v_total := round(greatest(0, b.total_amount), 2);
  if v_plan = 'advance' then
    if not v.advance_payment_enabled then
      raise exception 'advance_payment_disabled' using errcode = '55000';
    end if;
    v_advance := least(v_total, greatest(
      round(v_total * v.advance_percentage / 100, 2),
      v.minimum_advance_amount
    ));
  else
    v_advance := v_total;
  end if;
  select coalesce(sum(case when direction = 'credit' then amount else -amount end)
    filter (where status = 'posted'), 0)
    into v_wallet
    from public.wallet_ledger where user_id = auth.uid();
  return jsonb_build_object(
    'booking_id', b.id, 'currency', b.currency, 'payment_plan', v_plan,
    'full_amount', v_total, 'advance_percentage',
      case when v_plan = 'advance' then v.advance_percentage else 100 end,
    'advance_amount', v_advance,
    'balance_due', greatest(0, round(v_total - v_advance, 2)),
    'advance_enabled', v.advance_payment_enabled,
    'minimum_advance_amount', v.minimum_advance_amount,
    'wallet_enabled', v.allow_wallet_credit,
    'wallet_balance', greatest(0, coalesce(v_wallet, 0))
  );
end;
$$;

revoke all on function public.calculate_booking_payment_quote(uuid, text) from public, anon;
grant execute on function public.calculate_booking_payment_quote(uuid, text) to authenticated;
