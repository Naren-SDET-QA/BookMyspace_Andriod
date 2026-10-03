# whatsapp-send

Authenticated Supabase Edge Function that proxies WhatsApp requests to the separate BookMySpace Baileys service.

Required Supabase secrets:

- WHATSAPP_SERVICE_URL — private HTTPS URL of the Node service.
- WHATSAPP_API_KEY — same secret configured on the Node service.

Neither secret belongs in Flutter or Web.

Deploy:

supabase functions deploy whatsapp-send
supabase secrets set WHATSAPP_SERVICE_URL=https://your-private-whatsapp-host.example
supabase secrets set WHATSAPP_API_KEY=your-long-random-secret

The Flutter application needs no new dependency for this integration.
