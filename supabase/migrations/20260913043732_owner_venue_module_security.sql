-- Owner venue module hardening.
--
-- The deployed project already owns module_feature_configs as the shared
-- module-configuration table. This migration adds the missing backend guard
-- for owner-scoped presentation metadata; it does not create a second flag
-- or configuration system.

create or replace function public.validate_owner_venue_module_config()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := (select auth.uid());
  v_is_admin boolean := public.is_platform_admin(v_uid);
begin
  if v_is_admin then
    return new;
  end if;

  if v_uid is null
     or new.venue_id is null
     or not public.owns_venue(v_uid, new.venue_id) then
    raise exception 'venue module configuration requires venue ownership'
      using errcode = '42501';
  end if;

  -- Owners may configure only presentation modules that are already
  -- implemented for venue surfaces. Core security modules remain admin and
  -- server controlled even if a caller bypasses the Flutter UI.
  if new.module_key not in ('offers', 'events', 'courses', 'reviews') then
    raise exception 'unsupported_owner_venue_module'
      using errcode = '22023';
  end if;

  if jsonb_typeof(coalesce(new.metadata, '{}'::jsonb)) <> 'object' then
    raise exception 'venue module metadata must be an object'
      using errcode = '22023';
  end if;
  if length(coalesce(new.metadata->>'title', '')) > 80
     or length(coalesce(new.metadata->>'description', '')) > 400
     or length(coalesce(new.metadata->>'content', '')) > 5000
     or length(coalesce(new.metadata->>'icon', '')) > 32
     or length(coalesce(new.metadata->>'image_url', '')) > 2048 then
    raise exception 'venue module metadata exceeds the supported length'
      using errcode = '22023';
  end if;
  if new.metadata ? 'published'
     and jsonb_typeof(new.metadata->'published') <> 'boolean' then
    raise exception 'venue module published must be boolean'
      using errcode = '22023';
  end if;
  if new.metadata ? 'display_order' then
    if jsonb_typeof(new.metadata->'display_order') <> 'number'
       or (new.metadata->>'display_order')::numeric < 0
       or (new.metadata->>'display_order')::numeric <>
          trunc((new.metadata->>'display_order')::numeric) then
      raise exception 'venue module display_order is invalid'
        using errcode = '22023';
    end if;
  end if;
  if new.metadata ? 'title_i18n'
     and jsonb_typeof(new.metadata->'title_i18n') <> 'object' then
    raise exception 'venue module title_i18n must be an object'
      using errcode = '22023';
  end if;
  if new.metadata ? 'description_i18n'
     and jsonb_typeof(new.metadata->'description_i18n') <> 'object' then
    raise exception 'venue module description_i18n must be an object'
      using errcode = '22023';
  end if;
  if new.metadata ? 'content_i18n'
     and jsonb_typeof(new.metadata->'content_i18n') <> 'object' then
    raise exception 'venue module content_i18n must be an object'
      using errcode = '22023';
  end if;

  -- Only the venue toggle and presentation metadata are owner-editable. All
  -- payment, approval, notification, form, and security columns remain at
  -- their server/admin-controlled values.
  if tg_op = 'UPDATE' then
    if new.module_key is distinct from old.module_key
       or new.venue_id is distinct from old.venue_id
       or new.registration_enabled is distinct from old.registration_enabled
       or new.custom_fields_enabled is distinct from old.custom_fields_enabled
       or new.document_upload_enabled is distinct from old.document_upload_enabled
       or new.payment_enabled is distinct from old.payment_enabled
       or new.advance_payment_enabled is distinct from old.advance_payment_enabled
       or new.deposit_enabled is distinct from old.deposit_enabled
       or new.installment_payment_enabled is distinct from old.installment_payment_enabled
       or new.invoice_enabled is distinct from old.invoice_enabled
       or new.email_enabled is distinct from old.email_enabled
       or new.notifications_enabled is distinct from old.notifications_enabled
       or new.reviews_enabled is distinct from old.reviews_enabled
       or new.owner_response_enabled is distinct from old.owner_response_enabled
       or new.ai_assistant_enabled is distinct from old.ai_assistant_enabled
       or new.voice_booking_enabled is distinct from old.voice_booking_enabled
       or new.registration_fee_minor is distinct from old.registration_fee_minor
       or new.advance_amount_minor is distinct from old.advance_amount_minor
       or new.deposit_amount_minor is distinct from old.deposit_amount_minor
       or new.currency is distinct from old.currency
       or new.tax_rate is distinct from old.tax_rate
       or new.refund_policy is distinct from old.refund_policy
       or new.approval_required is distinct from old.approval_required
       or new.location_required is distinct from old.location_required
       or new.availability_required is distinct from old.availability_required
       or new.documents_enabled is distinct from old.documents_enabled
       or new.payment_required_before_approval is distinct from old.payment_required_before_approval
       or new.payment_required_before_confirmation is distinct from old.payment_required_before_confirmation
       or new.payment_refundable is distinct from old.payment_refundable
       or new.map_enabled is distinct from old.map_enabled
       or new.voice_enabled is distinct from old.voice_enabled
       or new.ai_help_enabled is distinct from old.ai_help_enabled
       or new.multilingual_enabled is distinct from old.multilingual_enabled
       or new.review_enabled is distinct from old.review_enabled
       or new.payment_timing is distinct from old.payment_timing then
      raise exception 'owner cannot change protected venue module settings'
        using errcode = '42501';
    end if;
  else
    if coalesce(new.registration_enabled, false)
       or coalesce(new.custom_fields_enabled, false)
       or coalesce(new.document_upload_enabled, false)
       or coalesce(new.payment_enabled, false)
       or coalesce(new.advance_payment_enabled, false)
       or coalesce(new.deposit_enabled, false)
       or coalesce(new.installment_payment_enabled, false)
       or not coalesce(new.invoice_enabled, true)
       or not coalesce(new.email_enabled, true)
       or not coalesce(new.notifications_enabled, true)
       or not coalesce(new.reviews_enabled, true)
       or coalesce(new.owner_response_enabled, false)
       or coalesce(new.ai_assistant_enabled, false)
       or coalesce(new.voice_booking_enabled, false)
       or new.registration_fee_minor is not null
       or new.advance_amount_minor is not null
       or new.deposit_amount_minor is not null
       or coalesce(new.currency, 'INR') <> 'INR'
       or coalesce(new.tax_rate, 0) <> 0
       or coalesce(new.refund_policy, '{}'::jsonb) <> '{}'::jsonb
       or coalesce(new.approval_required, false)
       or coalesce(new.location_required, false)
       or coalesce(new.availability_required, false)
       or coalesce(new.documents_enabled, false)
       or coalesce(new.payment_required_before_approval, false)
       or coalesce(new.payment_required_before_confirmation, false)
       or not coalesce(new.payment_refundable, true)
       or not coalesce(new.map_enabled, true)
       or coalesce(new.voice_enabled, false)
       or coalesce(new.ai_help_enabled, false)
       or not coalesce(new.multilingual_enabled, true)
       or not coalesce(new.review_enabled, true)
       or coalesce(new.payment_timing, 'payment_not_required') <> 'payment_not_required' then
      raise exception 'owner cannot create protected venue module settings'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

do $$
begin
  if to_regclass('public.module_feature_configs') is not null then
    drop trigger if exists owner_venue_module_config_guard
      on public.module_feature_configs;
    create trigger owner_venue_module_config_guard
      before insert or update on public.module_feature_configs
      for each row execute function public.validate_owner_venue_module_config();
  end if;
end;
$$;
