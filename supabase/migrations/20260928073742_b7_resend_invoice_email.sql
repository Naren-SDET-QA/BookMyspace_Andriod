-- B7: resend an already-generated invoice through the server-side email outbox.
-- The client can request a destination, but it cannot write email_outbox or
-- attach an arbitrary document. Authorization and the attachment path are
-- resolved from the invoice/booking on the server.

create or replace function public.resend_invoice_email(
  p_invoice_id uuid,
  p_recipient_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_invoice record;
  v_user_email text;
  v_recipient text;
  v_event_key text;
  v_existing boolean;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  select i.id, i.invoice_number, i.storage_path, i.status, i.booking_id,
         b.user_id, v.org_id, o.owner_user_id
    into v_invoice
    from public.invoice_documents i
    join public.bookings b on b.id = i.booking_id
    join public.venues v on v.id = b.venue_id
    left join public.organizations o on o.id = v.org_id
   where i.id = p_invoice_id;
  if not found then raise exception 'invoice_not_found'; end if;
  if v_invoice.status <> 'generated' or v_invoice.storage_path is null then
    raise exception 'invoice_not_ready';
  end if;

  if v_invoice.user_id is distinct from (select auth.uid())
     and v_invoice.owner_user_id is distinct from (select auth.uid())
     and not public.is_platform_admin((select auth.uid())) then
    raise exception 'not_authorized';
  end if;

  select email into v_user_email from auth.users where id = v_invoice.user_id;
  v_recipient := lower(trim(coalesce(nullif(p_recipient_email, ''), v_user_email, '')));
  if v_recipient = '' or v_recipient !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'invalid_recipient_email';
  end if;

  -- Prevent accidental double-clicks from producing two emails in one minute,
  -- while still allowing a deliberate resend later.
  select exists (
    select 1 from public.email_outbox
     where invoice_id = v_invoice.id
       and lower(recipient_email) = v_recipient
       and created_at > now() - interval '60 seconds'
       and status in ('pending', 'sending', 'sent')
  ) into v_existing;
  if v_existing then
    return jsonb_build_object('queued', false, 'already_queued', true,
      'recipient_email', v_recipient);
  end if;

  v_event_key := 'invoice.resend.' || v_invoice.id::text || '.'
    || md5(v_recipient || ':' || clock_timestamp()::text);
  insert into public.email_outbox
    (event_key, event_type, recipient_email, recipient_name, booking_id,
     invoice_id, template_name, payload, attachment_metadata, status,
     next_attempt_at)
  values
    (v_event_key, 'invoice.resent', v_recipient, null, v_invoice.booking_id,
     v_invoice.id, 'invoice-generated',
     jsonb_build_object('invoice_number', v_invoice.invoice_number,
       'resend', true),
     jsonb_build_array(jsonb_build_object(
       'bucket', 'invoices', 'path', v_invoice.storage_path,
       'filename', v_invoice.invoice_number || '.pdf')),
     'pending', now());

  return jsonb_build_object('queued', true, 'already_queued', false,
    'recipient_email', v_recipient);
end;
$$;

revoke all on function public.resend_invoice_email(uuid, text) from public, anon;
grant execute on function public.resend_invoice_email(uuid, text) to authenticated;
