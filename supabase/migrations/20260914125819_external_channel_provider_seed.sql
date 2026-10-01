-- ============================================================
-- BookMySpace — External Channel Providers: catalog seed
--
-- All providers are seeded as status='blocked_external': no live
-- credentials or partner/channel-manager agreements exist in this
-- environment. Capabilities reflect each provider's documented
-- integration model, NOT a fabricated live connection.
-- ============================================================

insert into public.external_channel_providers (code, name, auth_model, capabilities, requires_partner_agreement, status, docs_url)
values
  (
    'booking_com', 'Booking.com', 'oauth2',
    jsonb_build_object(
      'pull_availability', true, 'webhooks', true, 'push_inventory', true,
      'create_reservation', false, 'cancel_reservation', true,
      'note', 'Booking.com Connectivity API (XML/Push) requires a certified Connectivity Partner agreement; no self-serve API key exists for individual properties.'
    ),
    true, 'blocked_external', 'https://connect.booking.com/'
  ),
  (
    'makemytrip', 'MakeMyTrip', 'partner_agreement',
    jsonb_build_object(
      'pull_availability', true, 'webhooks', false, 'push_inventory', true,
      'create_reservation', false, 'cancel_reservation', false,
      'note', 'MakeMyTrip does not publish a self-serve public channel-manager API; integration is via approved channel-manager/extranet partners only.'
    ),
    true, 'blocked_external', null
  ),
  (
    'agoda', 'Agoda', 'partner_agreement',
    jsonb_build_object(
      'pull_availability', true, 'webhooks', false, 'push_inventory', true,
      'create_reservation', false, 'cancel_reservation', false,
      'note', 'Agoda YCS/API access requires a Yield Control System partner or certified connectivity provider relationship.'
    ),
    true, 'blocked_external', 'https://ycs.agoda.com/'
  ),
  (
    'generic_pms', 'Generic PMS / Channel Manager (OTA-neutral)', 'api_key',
    jsonb_build_object(
      'pull_availability', true, 'webhooks', true, 'push_inventory', true,
      'create_reservation', true, 'cancel_reservation', true,
      'note', 'Reference adapter for a channel manager exposing a REST + webhook contract. Also used for phone/walk-in bookings entered directly by the property.'
    ),
    false, 'blocked_external', null
  )
on conflict (code) do update set
  capabilities = excluded.capabilities,
  auth_model = excluded.auth_model,
  requires_partner_agreement = excluded.requires_partner_agreement,
  status = excluded.status,
  docs_url = excluded.docs_url,
  updated_at = now();
