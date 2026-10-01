-- B2: credit the referrer exactly once when the referred user's first
-- booking reaches the server-authoritative confirmed state.

create or replace function public.credit_referral_on_first_confirmed_booking()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_attribution public.referral_attributions;
  v_config public.reward_configs;
  v_reward_id uuid;
  v_amount numeric(12,2);
begin
  if new.status <> 'confirmed'::public.booking_status
     or old.status = 'confirmed'::public.booking_status then
    return new;
  end if;

  if exists (
    select 1 from public.bookings prior
     where prior.user_id = new.user_id
       and prior.id <> new.id
       and prior.status in ('confirmed', 'completed')
  ) then
    return new;
  end if;

  select * into v_attribution
    from public.referral_attributions
   where referred_user_id = new.user_id
     and status in ('pending', 'qualified')
   for update;
  if not found then return new; end if;

  select * into v_config
    from public.reward_configs
   where is_active = true
   order by created_at desc
   limit 1;

  -- The product contract is ₹500 for the referrer. An active admin reward
  -- configuration may override it, but an unset/zero referrer amount must
  -- never silently remove the promised first-booking credit.
  v_amount := case
    when found and coalesce(v_config.referrer_amount, 0) > 0
      then v_config.referrer_amount
    else 500
  end;

  insert into public.referral_rewards(
    attribution_id, beneficiary_user_id, reward_type, amount, currency, status, posted_at
  ) values (
    v_attribution.id, v_attribution.referrer_user_id, 'referrer', v_amount,
    coalesce(v_config.currency, 'INR'), 'posted', now()
  ) on conflict (attribution_id, beneficiary_user_id, reward_type) do nothing;

  select id into v_reward_id
    from public.referral_rewards
   where attribution_id = v_attribution.id
     and beneficiary_user_id = v_attribution.referrer_user_id
     and reward_type = 'referrer';

  insert into public.wallet_ledger(
    user_id, direction, amount, currency, status, source_type, source_id, description
  ) values (
    v_attribution.referrer_user_id, 'credit', v_amount,
    coalesce(v_config.currency, 'INR'), 'referral_reward', v_reward_id,
    'Referral reward for first confirmed booking'
  ) on conflict (user_id, source_type, source_id, direction) do nothing;

  update public.referral_attributions
     set status = 'rewarded', qualified_at = coalesce(qualified_at, now()),
         rewarded_at = coalesce(rewarded_at, now())
   where id = v_attribution.id;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, details)
  values (
    new.user_id, 'referral_first_booking_rewarded', 'booking', new.id,
    jsonb_build_object('attribution_id', v_attribution.id, 'amount', v_amount,
      'currency', coalesce(v_config.currency, 'INR'))
  );
  return new;
end;
$$;

drop trigger if exists trg_credit_referral_on_first_confirmed_booking
  on public.bookings;
create trigger trg_credit_referral_on_first_confirmed_booking
after update of status on public.bookings
for each row execute function public.credit_referral_on_first_confirmed_booking();

revoke all on function public.credit_referral_on_first_confirmed_booking() from public, anon, authenticated;
grant execute on function public.credit_referral_on_first_confirmed_booking() to service_role;
