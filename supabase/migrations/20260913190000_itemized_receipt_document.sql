-- Itemized digital receipts.
--
-- `booking_receipts` and its `receipt_number` have existed since the owner
-- approval work, and the confirmation RPC already issues a row. What was never
-- built is the *document*: the row stores a single `amount` (the booking total)
-- and a one-key `metadata` stub, so there is nothing to itemize and nothing to
-- print. `BOOKMYSPACE_BUSINESS_RULES.md` §22 requires a receipt carrying Base
-- Amount, Taxes, Platform Fees, Discounts and Total Paid.
--
-- This migration adds a single idempotent entry point that returns a complete,
-- self-checking receipt document and freezes it into
-- `booking_receipts.metadata`.
--
-- Two deliberate omissions, both because the data does not exist:
--
--   * **Platform Fees are not shown.** §22 lists them, but
--     `public.platform_commissions` is created in 0006 and has an admin-read
--     policy and *no writer anywhere in the schema*. There is no fee to print,
--     and printing a plausible-looking one on a financial document is worse
--     than printing none. The document therefore reports
--     `line_items.platform_fee` as null and sets `omissions`.
--   * **No tax rate is asserted.** `venues.tax_rate` is returned for reference
--     only. The receipt states the tax *amount* that was actually charged; it
--     does not re-derive a rate, because re-deriving would change a historical
--     document whenever a venue edits its pricing.
--
-- The document carries a `reconciles` flag. `bookings.total_amount` is the
-- authoritative figure — it is what was charged — so the function checks
-- whether the components sum to it and says so, instead of letting a client
-- render a breakdown that silently does not add up.

-- ---------------------------------------------------------------------------
-- Snapshot support
-- ---------------------------------------------------------------------------

comment on column public.booking_receipts.metadata is
  'Immutable snapshot of the issued receipt, written once under the "snapshot" '
  'key. Clients must render from this, never by re-reading live booking rows, '
  'so a receipt cannot change after it is issued.';

-- ---------------------------------------------------------------------------
-- issue_booking_receipt
-- ---------------------------------------------------------------------------

create or replace function public.issue_booking_receipt(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_venue record;
  v_slot_label text;
  v_payment record;
  v_guest record;
  v_receipt record;
  v_is_guest boolean := false;
  v_is_host boolean := false;
  v_document jsonb;
  v_base numeric(12,2);
  v_tax numeric(12,2);
  v_discount numeric(12,2);
  v_total numeric(12,2);
  v_sum numeric(12,2);
  v_receipt_number text;
begin
  if auth.uid() is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHENTICATED',
      'message', 'Sign in to view a receipt.');
  end if;

  if p_booking_id is null then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_BOOKING',
      'message', 'A booking id is required.');
  end if;

  select b.*, v.org_id, o.owner_user_id
  into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  left join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id;

  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND',
      'message', 'No booking matches this id.');
  end if;

  v_is_guest := v_booking.user_id = auth.uid();
  v_is_host := v_booking.owner_user_id is not null
    and v_booking.owner_user_id = auth.uid();

  if not (v_is_guest or v_is_host or public.is_platform_admin(auth.uid())) then
    return jsonb_build_object('success', false, 'error_code', 'NOT_AUTHORIZED',
      'message', 'This receipt does not belong to your account or your venue.');
  end if;

  -- A receipt is evidence of payment. Pending and held bookings have none yet.
  if v_booking.status not in ('confirmed', 'completed', 'refunded') then
    return jsonb_build_object('success', false, 'error_code', 'RECEIPT_NOT_AVAILABLE',
      'message', 'A receipt is issued once payment is confirmed.');
  end if;

  select name, address_line1, address_line2, city, state, postal_code, country, tax_rate
  into v_venue
  from public.venues where id = v_booking.venue_id;

  select label into v_slot_label
  from public.time_slots where id = v_booking.slot_id;

  select full_name, email, phone
  into v_guest
  from public.profiles where id = v_booking.user_id;

  -- Most recent captured payment for this booking, if any.
  select id, provider, provider_payment_id, provider_order_id, method, status::text as status
  into v_payment
  from public.payments
  where booking_id = v_booking.id
  order by created_at desc
  limit 1;

  v_base := coalesce(v_booking.amount, 0);
  v_tax := coalesce(v_booking.tax_amount, 0);
  v_discount := coalesce(v_booking.discount_amount, 0);
  v_total := coalesce(v_booking.total_amount, 0);

  -- Does the itemization actually add up to what was charged? Round to paise
  -- before comparing so a numeric(12,2) artefact cannot flag a false mismatch.
  v_sum := round(v_base + v_tax - v_discount, 2);

  select id, receipt_number, issued_at, metadata
  into v_receipt
  from public.booking_receipts
  where booking_id = v_booking.id;

  -- An already-issued receipt is returned verbatim. Re-deriving it would let a
  -- later price or address edit rewrite a document that has already been given
  -- to a customer.
  if found and v_receipt.metadata ? 'snapshot' then
    return jsonb_build_object(
      'success', true,
      'receipt_issued', true,
      'document', v_receipt.metadata -> 'snapshot');
  end if;

  v_document := jsonb_build_object(
    'snapshot_version', 1,
    'booking_id', v_booking.id,
    'booking_ref', v_booking.booking_ref,
    'status', v_booking.status::text,
    'currency', coalesce(v_booking.currency, 'INR'),
    'payment_ref', coalesce(v_payment.provider_payment_id, v_payment.provider_order_id),
    'payment_provider', v_payment.provider,
    'payment_method', v_payment.method,
    'venue', jsonb_build_object(
      'name', v_venue.name,
      'address_line1', v_venue.address_line1,
      'address_line2', v_venue.address_line2,
      'city', v_venue.city,
      'state', v_venue.state,
      'postal_code', v_venue.postal_code,
      'country', v_venue.country),
    'slot', jsonb_build_object(
      'label', v_slot_label,
      'book_date', v_booking.book_date,
      'start_time', v_booking.start_time,
      'end_time', v_booking.end_time,
      'quantity', v_booking.quantity),
    'guest', jsonb_build_object(
      'name', v_guest.full_name,
      'email', v_guest.email,
      'phone', v_guest.phone),
    'line_items', jsonb_build_object(
      'base_amount', v_base,
      'tax_amount', v_tax,
      'tax_rate_reference', v_venue.tax_rate,
      'discount_amount', v_discount,
      'platform_fee', null),
    'total_paid', v_total,
    'computed_subtotal', v_sum,
    'reconciles', (v_sum = v_total),
    'omissions', case
      when v_payment.id is null
        then jsonb_build_array('platform_fee', 'no_payment_recorded')
      else jsonb_build_array('platform_fee')
    end,
    -- The receipt's own issue time, not the time this snapshot happened to be
    -- written. A row issued before snapshots existed already carries the real
    -- `issued_at`; stamping now() would make a June receipt claim September.
    'issued_at', coalesce(v_receipt.issued_at, now()));

  if v_receipt.id is not null then
    -- Legacy row issued before snapshots existed: freeze it now, exactly once.
    -- `metadata` is nullable, and `NULL ? 'snapshot'` is NULL rather than false,
    -- so the null case has to be spelled out or the row would never be frozen.
    update public.booking_receipts
    set metadata = coalesce(metadata, '{}'::jsonb)
        || jsonb_build_object('snapshot', v_document)
    where id = v_receipt.id
      and (metadata is null or not (metadata ? 'snapshot'));

    return jsonb_build_object(
      'success', true,
      'receipt_issued', true,
      'receipt_number', v_receipt.receipt_number,
      'document', v_document);
  end if;

  -- No payment row means no receipt row can exist: booking_receipts.payment_id
  -- is NOT NULL. Return the breakdown so the client can still show a statement,
  -- explicitly labelled as not an issued receipt.
  if v_payment.id is null then
    return jsonb_build_object(
      'success', true,
      'receipt_issued', false,
      'document', v_document,
      'message', 'No captured payment is recorded for this booking, so no '
                 'receipt number has been issued.');
  end if;

  -- Same format as the confirmation RPC, so numbers from either path are
  -- indistinguishable in shape.
  v_receipt_number := 'BMS-R-'
    || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 12));

  insert into public.booking_receipts
    (booking_id, payment_id, receipt_number, amount, currency, metadata)
  values (v_booking.id, v_payment.id, v_receipt_number, v_total,
    coalesce(v_booking.currency, 'INR'),
    jsonb_build_object('snapshot', v_document))
  on conflict (booking_id) do nothing;

  select id, receipt_number, issued_at, metadata
  into v_receipt
  from public.booking_receipts
  where booking_id = v_booking.id;

  -- Lost a race: another caller inserted first, so theirs is the receipt.
  if found and (v_receipt.metadata ? 'snapshot') then
    return jsonb_build_object(
      'success', true,
      'receipt_issued', true,
      'receipt_number', v_receipt.receipt_number,
      'document', v_receipt.metadata -> 'snapshot');
  end if;

  return jsonb_build_object(
    'success', true,
    'receipt_issued', true,
    'receipt_number', v_receipt.receipt_number,
    'document', v_document);
end;
$$;

comment on function public.issue_booking_receipt(uuid) is
  'Returns the itemized receipt document for a booking, issuing and freezing it '
  'on first call. Idempotent: an issued receipt is never recomputed.';

revoke all on function public.issue_booking_receipt(uuid) from public, anon;
grant execute on function public.issue_booking_receipt(uuid) to authenticated;
