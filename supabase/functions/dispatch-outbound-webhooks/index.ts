import { createClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const admin = createClient(url, serviceKey);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

async function signature(payload: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const bytes = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(payload),
  );
  return `sha256=${btoa(String.fromCharCode(...new Uint8Array(bytes)))}`;
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const authorization = request.headers.get('authorization') ?? '';
  if (!serviceKey || authorization !== `Bearer ${serviceKey}`) {
    return json({ error: 'unauthorized' }, 401);
  }

  const { data: deliveries, error } = await admin.rpc(
    'claim_outbound_webhook_batch',
    { p_limit: 20 },
  );
  if (error) return json({ error: 'claim_failed' }, 500);

  let delivered = 0;
  for (const delivery of deliveries ?? []) {
    const { data: endpoint } = await admin
      .from('outbound_webhook_endpoints')
      .select('id, endpoint_url, secret_reference')
      .eq('id', delivery.endpoint_id)
      .maybeSingle();
    const secret = endpoint?.secret_reference
      ? Deno.env.get(endpoint.secret_reference) ?? ''
      : '';
    if (!endpoint || !secret) {
      await admin.rpc('record_outbound_webhook_result', {
        p_delivery_id: delivery.id,
        p_success: false,
        p_error_code: 'webhook_secret_not_configured',
      });
      continue;
    }

    const payload = JSON.stringify(delivery.payload ?? {});
    try {
      const response = await fetch(endpoint.endpoint_url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'BookMySpace-Webhooks/1.0',
          'X-BookMySpace-Event': delivery.event_type,
          'X-BookMySpace-Delivery': delivery.id,
          'X-BookMySpace-Signature': await signature(payload, secret),
        },
        body: payload,
        signal: AbortSignal.timeout(10000),
      });
      await admin.rpc('record_outbound_webhook_result', {
        p_delivery_id: delivery.id,
        p_success: response.ok,
        p_response_status: response.status,
        p_error_code: response.ok ? null : 'endpoint_rejected',
      });
      if (response.ok) delivered++;
    } catch (_) {
      await admin.rpc('record_outbound_webhook_result', {
        p_delivery_id: delivery.id,
        p_success: false,
        p_error_code: 'endpoint_unreachable',
      });
    }
  }
  return json({ claimed: deliveries?.length ?? 0, delivered });
});
