import { createClient } from 'npm:@supabase/supabase-js@2.57.4'

type SendRequest = {
  to: string
  text?: string
  mediaBase64?: string
  mimetype?: string
  fileName?: string
  caption?: string
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export default {
  async fetch(req: Request) {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    if (req.method !== 'POST') {
      return Response.json({ ok: false, error: 'Method not allowed' }, { status: 405, headers: corsHeaders })
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return Response.json({ ok: false, error: 'Authentication required' }, { status: 401, headers: corsHeaders })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const publishableKeys = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')
    const whatsappUrl = Deno.env.get('WHATSAPP_SERVICE_URL')
    const whatsappKey = Deno.env.get('WHATSAPP_API_KEY')

    if (!supabaseUrl || !publishableKeys || !whatsappUrl || !whatsappKey) {
      return Response.json({ ok: false, error: 'WhatsApp service is not configured' }, { status: 503, headers: corsHeaders })
    }

    const keys = JSON.parse(publishableKeys)
    const supabase = createClient(supabaseUrl, keys.default, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return Response.json({ ok: false, error: 'Invalid session' }, { status: 401, headers: corsHeaders })
    }

    const payload = (await req.json()) as SendRequest
    const to = String(payload.to ?? '').replace(/[^0-9]/g, '')
    const text = typeof payload.text === 'string' ? payload.text.trim() : ''

    if (!to || (!text && !payload.mediaBase64)) {
      return Response.json({ ok: false, error: 'to and text/media are required' }, { status: 400, headers: corsHeaders })
    }

    const endpoint = payload.mediaBase64 ? '/send-media' : '/send-text'
    const servicePayload = payload.mediaBase64
      ? {
          to,
          base64: payload.mediaBase64,
          mimetype: payload.mimetype ?? 'application/octet-stream',
          fileName: payload.fileName,
          caption: payload.caption ?? text,
        }
      : { to, text }

    const response = await fetch(new URL(endpoint, whatsappUrl), {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': whatsappKey,
      },
      body: JSON.stringify(servicePayload),
    })

    const result = await response.json().catch(() => ({ ok: false, error: 'Invalid WhatsApp service response' }))
    return Response.json(
      { ...result, requestedBy: user.id },
      { status: response.status, headers: corsHeaders },
    )
  },
}
