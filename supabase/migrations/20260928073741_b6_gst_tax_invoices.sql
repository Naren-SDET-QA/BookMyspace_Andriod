-- B6: server-authoritative GST invoice data.
-- Tax classification and the invoice snapshot are calculated once on the
-- server; clients never choose the tax split or rewrite an issued invoice.

alter table public.venues
  add column if not exists gstin text,
  add column if not exists pan text;

alter table public.profiles
  add column if not exists billing_state text,
  add column if not exists billing_gstin text,
  add column if not exists billing_pan text;

create table if not exists public.invoice_tax_defaults (
  id boolean primary key default true check (id),
  invoice_prefix text not null default 'BMS'
    check (invoice_prefix ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,15}$'),
  sac_code text not null default '997212'
    check (sac_code ~ '^[0-9]{6}$'),
  default_gstin text,
  default_pan text,
  default_state text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

insert into public.invoice_tax_defaults (id)
values (true)
on conflict (id) do nothing;

alter table public.invoice_documents
  add column if not exists tax_mode text not null default 'unregistered'
    check (tax_mode in ('cgst_sgst', 'igst', 'unregistered')),
  add column if not exists sac_code text,
  add column if not exists seller_gstin text,
  add column if not exists seller_pan text,
  add column if not exists buyer_gstin text,
  add column if not exists buyer_pan text,
  add column if not exists taxable_amount numeric(12,2),
  add column if not exists cgst_amount numeric(12,2) not null default 0,
  add column if not exists sgst_amount numeric(12,2) not null default 0,
  add column if not exists igst_amount numeric(12,2) not null default 0,
  add column if not exists amount_in_words text,
  add column if not exists tax_snapshot jsonb not null default '{}'::jsonb;

alter table public.invoice_tax_defaults enable row level security;
revoke all on public.invoice_tax_defaults from anon, authenticated;

create or replace function public.get_invoice_tax_defaults()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin((select auth.uid())) then
    raise exception 'admin_required';
  end if;
  return coalesce(
    (select to_jsonb(d) from public.invoice_tax_defaults d where d.id = true),
    jsonb_build_object(
      'invoice_prefix', 'BMS',
      'sac_code', '997212',
      'default_gstin', null,
      'default_pan', null,
      'default_state', null));
end;
$$;

create or replace function public.save_invoice_tax_defaults(p_config jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.invoice_tax_defaults;
  v_prefix text := coalesce(nullif(trim(p_config->>'invoice_prefix'), ''), 'BMS');
  v_sac text := coalesce(nullif(trim(p_config->>'sac_code'), ''), '997212');
begin
  if not public.is_platform_admin((select auth.uid())) then
    raise exception 'admin_required';
  end if;
  if v_prefix !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,15}$' then
    raise exception 'invalid_invoice_prefix';
  end if;
  if v_sac !~ '^[0-9]{6}$' then
    raise exception 'invalid_sac_code';
  end if;

  insert into public.invoice_tax_defaults
    (id, invoice_prefix, sac_code, default_gstin, default_pan,
     default_state, updated_by, updated_at)
  values
    (true, upper(v_prefix), v_sac,
     nullif(trim(p_config->>'default_gstin'), ''),
     nullif(trim(p_config->>'default_pan'), ''),
     nullif(trim(p_config->>'default_state'), ''),
     (select auth.uid()), now())
  on conflict (id) do update set
    invoice_prefix = excluded.invoice_prefix,
    sac_code = excluded.sac_code,
    default_gstin = excluded.default_gstin,
    default_pan = excluded.default_pan,
    default_state = excluded.default_state,
    updated_by = excluded.updated_by,
    updated_at = now()
  returning * into v_row;
  return to_jsonb(v_row);
end;
$$;

-- The booking owner/customer may inspect the classification; service_role uses
-- the same function from generate-invoice after the payment is authoritative.
create or replace function public.calculate_invoice_tax(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking record;
  v_defaults public.invoice_tax_defaults;
  v_seller_gstin text;
  v_seller_pan text;
  v_seller_state text;
  v_buyer_state text;
  v_tax numeric(12,2);
  v_taxable numeric(12,2);
  v_mode text;
begin
  if auth.uid() is null and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'unauthenticated';
  end if;

  select b.user_id, b.amount, b.tax_amount, b.total_amount,
         v.gstin as venue_gstin, v.pan as venue_pan, v.state as venue_state,
         o.owner_user_id, o.gstin as organization_gstin, o.pan as organization_pan,
         o.state as organization_state,
         p.billing_state, p.billing_gstin, p.billing_pan
    into v_booking
    from public.bookings b
    join public.venues v on v.id = b.venue_id
    left join public.organizations o on o.id = v.org_id
    left join public.profiles p on p.id = b.user_id
   where b.id = p_booking_id;
  if not found then raise exception 'booking_not_found'; end if;
  if coalesce(auth.role(), '') <> 'service_role'
     and v_booking.user_id is distinct from (select auth.uid())
     and v_booking.owner_user_id is distinct from (select auth.uid())
     and not public.is_platform_admin((select auth.uid())) then
    raise exception 'not_authorized';
  end if;

  select * into v_defaults from public.invoice_tax_defaults where id = true;
  v_seller_gstin := coalesce(v_booking.venue_gstin,
    v_booking.organization_gstin, v_defaults.default_gstin);
  v_seller_pan := coalesce(v_booking.venue_pan,
    v_booking.organization_pan, v_defaults.default_pan);
  v_seller_state := nullif(trim(coalesce(v_booking.venue_state,
    v_booking.organization_state, v_defaults.default_state, '')), '');
  v_buyer_state := nullif(trim(coalesce(v_booking.billing_state, '')), '');
  v_taxable := round(coalesce(v_booking.amount, 0), 2);
  v_tax := round(coalesce(v_booking.tax_amount, 0), 2);
  v_mode := case
    when nullif(trim(coalesce(v_seller_gstin, '')), '') is null then 'unregistered'
    when v_seller_state is not null and v_buyer_state is not null
      and lower(v_seller_state) <> lower(v_buyer_state) then 'igst'
    else 'cgst_sgst'
  end;

  return jsonb_build_object(
    'tax_mode', v_mode,
    'sac_code', coalesce(v_defaults.sac_code, '997212'),
    'seller_gstin', v_seller_gstin,
    'seller_pan', v_seller_pan,
    'buyer_gstin', v_booking.billing_gstin,
    'buyer_pan', v_booking.billing_pan,
    'seller_state', v_seller_state,
    'buyer_state', v_buyer_state,
    'taxable_amount', v_taxable,
    'tax_amount', v_tax,
    'cgst_amount', case when v_mode = 'cgst_sgst' then round(v_tax / 2, 2) else 0 end,
    'sgst_amount', case when v_mode = 'cgst_sgst' then round(v_tax - round(v_tax / 2, 2), 2) else 0 end,
    'igst_amount', case when v_mode = 'igst' then v_tax else 0 end,
    'invoice_prefix', coalesce(v_defaults.invoice_prefix, 'BMS'));
end;
$$;

revoke all on function public.get_invoice_tax_defaults() from public, anon, authenticated;
revoke all on function public.save_invoice_tax_defaults(jsonb) from public, anon, authenticated;
revoke all on function public.calculate_invoice_tax(uuid) from public, anon;
grant execute on function public.get_invoice_tax_defaults() to authenticated;
grant execute on function public.save_invoice_tax_defaults(jsonb) to authenticated;
grant execute on function public.calculate_invoice_tax(uuid) to authenticated, service_role;
