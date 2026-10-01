// Deno edge function: External Inventory manual sync trigger.
//
// Lets a venue owner (or platform admin) request an on-demand sync for one
// external-channel connection. Ownership/authorization is enforced by the
// database, not this function: request_external_manual_sync() calls
// can_manage_external_connection(), evaluated against the caller's own
// auth.uid() (see supabase/migrations/20260914125455_external_channel_functions.sql).
//
// IMPORTANT — no fake provider integration:
// No external provider has real credentials configured. Every seeded
// provider (agoda, booking_com, makemytrip, generic_pms) is
// `blocked_external` (status column on external_channel_providers; the
// only non-blocked value is `available`). This function does not call,
// fake, or simulate any provider API. When a connection's provider is not
// `available`, the sync is recorded as failed with
// PROVIDER_BLOCKED_EXTERNAL via record_external_sync_result() — the same
// honest outcome an owner-facing UI is expected to surface. The seam for a
// genuine provider adapter is marked below and is intentionally left
// unimplemented until a real, credentialed integration exists.
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "missing_auth" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const connectionId = typeof body.connection_id === "string"
    ? body.connection_id.trim()
    : "";
  if (!connectionId || !UUID_RE.test(connectionId)) {
    return jsonResponse({ error: "missing_or_invalid_connection_id" }, 400);
  }

  // Caller-scoped client: the service-role key is used only as the API
  // key for transport; the Authorization header carries the caller's own
  // JWT, so PostgREST/Postgres evaluate auth.uid() and RLS as that user —
  // the same pattern create-booking-hold uses for request_venue_booking.
  const callerScoped: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await callerScoped.auth
    .getUser();
  if (userError || !user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const { data: requestResult, error: requestError } = await callerScoped
    .rpc("request_external_manual_sync", { p_connection_id: connectionId });
  if (requestError) {
    return jsonResponse({ error: "sync_request_failed" }, 500);
  }
  if (!requestResult || typeof requestResult !== "object") {
    return jsonResponse({ error: "empty_rpc_response" }, 502);
  }
  const requestOutcome = requestResult as Record<string, unknown>;
  if (requestOutcome.success !== true) {
    const errorCode = typeof requestOutcome.error_code === "string"
      ? requestOutcome.error_code
      : "REQUEST_FAILED";
    const status = errorCode === "FORBIDDEN" ? 403 : 409;
    return jsonResponse({ error: errorCode.toLowerCase() }, status);
  }

  // record_external_sync_result is restricted to service_role by design
  // (see supabase/tests/external_channel_production_security_contract.sql)
  // so the sync outcome cannot be forged by an authenticated client call —
  // a second, service-role-only client is required here.
  const serviceRole: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );

  const { data: connection, error: connectionError } = await serviceRole
    .from("external_channel_connections")
    .select("id, external_channel_providers(code, status)")
    .eq("id", connectionId)
    .maybeSingle();

  if (connectionError || !connection) {
    return jsonResponse({ error: "connection_lookup_failed" }, 500);
  }

  const providerRow = (connection as Record<string, unknown>)
    .external_channel_providers as { code?: string; status?: string } | null;

  if (!providerRow || providerRow.status !== "available") {
    const message =
      `Provider '${providerRow?.code ?? "unknown"}' is ${
        providerRow?.status ?? "unknown"
      }; no real credentials are configured, so no sync was attempted.`;
    await serviceRole.rpc("record_external_sync_result", {
      p_connection_id: connectionId,
      p_success: false,
      p_mismatch_count: 0,
      p_error_code: "PROVIDER_BLOCKED_EXTERNAL",
      p_error_message: message,
      p_context: { provider_code: providerRow?.code ?? null },
    });
    return jsonResponse({
      sync_requested: true,
      sync_status: "error",
      blocked_external: true,
      provider_code: providerRow?.code ?? null,
      message,
    }, 200);
  }

  // Seam for a real provider adapter. Unreachable today (no provider is
  // `available`) and MUST NOT be filled in with a simulated/fake call — a
  // genuine integration (real credentials, real documented-API calls)
  // belongs here, added only once a provider is deliberately unblocked.
  const message =
    `Provider '${providerRow.code}' is available but no live sync adapter has been implemented yet.`;
  await serviceRole.rpc("record_external_sync_result", {
    p_connection_id: connectionId,
    p_success: false,
    p_mismatch_count: 0,
    p_error_code: "PROVIDER_SYNC_NOT_IMPLEMENTED",
    p_error_message: message,
    p_context: { provider_code: providerRow.code },
  });
  return jsonResponse({
    sync_requested: true,
    sync_status: "error",
    blocked_external: false,
    provider_code: providerRow.code,
    message,
  }, 501);
});
