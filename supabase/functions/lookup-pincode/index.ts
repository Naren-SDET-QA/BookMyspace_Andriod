import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const PIN_PATTERN = /^[1-9][0-9]{5}$/;

type PostOffice = {
  Name?: string;
  BranchType?: string;
  DeliveryStatus?: string;
  Circle?: string;
  District?: string;
  Division?: string;
  Region?: string;
  Block?: string;
  State?: string;
  Country?: string;
  Pincode?: string;
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { error: 'method_not_allowed' });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json(401, { error: 'unauthorized' });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return json(401, { error: 'unauthorized' });
  }

  let payload: { pincode?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: 'invalid_json' });
  }

  const pincode = String(payload.pincode ?? '').trim();
  if (!PIN_PATTERN.test(pincode)) {
    return json(400, {
      error: 'invalid_pincode',
      message: 'Enter a valid 6-digit Indian PIN code.',
    });
  }

  try {
    const upstream = await fetch(
      `https://api.postalpincode.in/pincode/${pincode}`,
      { headers: { Accept: 'application/json' } },
    );
    if (!upstream.ok) {
      return json(502, {
        error: 'lookup_failed',
        message: 'PIN code service is unavailable. Retry in a moment.',
      });
    }
    const body = await upstream.json();
    const row = Array.isArray(body) ? body[0] : null;
    const offices = (row?.PostOffice ?? []) as PostOffice[];
    if (!row || row.Status !== 'Success' || offices.length === 0) {
      return json(200, { status: 'empty', pincode, offices: [] });
    }

    return json(200, {
      status: 'success',
      pincode,
      offices: offices.map((office) => ({
        name: office.Name ?? '',
        branchType: office.BranchType ?? '',
        deliveryStatus: office.DeliveryStatus ?? '',
        circle: office.Circle ?? '',
        district: office.District ?? '',
        division: office.Division ?? '',
        region: office.Region ?? '',
        block: office.Block ?? '',
        state: office.State ?? '',
        country: office.Country ?? 'India',
        pincode: office.Pincode ?? pincode,
      })),
    });
  } catch {
    return json(502, {
      error: 'lookup_failed',
      message: 'PIN code service is unavailable. Retry in a moment.',
    });
  }
});
