// Deno edge function: External Inventory webhook receiver.
//
// Receives external-channel reservation events (a booking or cancellation
// made on an external provider — an OTA or a PMS/channel manager) and
// applies them to BookMySpace's own availability via the already-tested
// apply_external_reservation_event() database function, which owns all
// idempotency, event-ordering, mapping-validation, and conflict-recovery
// logic (see supabase/tests/external_channel_correctness.sql and
// supabase/migrations/20260914125455_external_channel_functions.sql /
// 20260914131541_external_channel_correctness_hardening.sql).
//
// SECURITY:
// - Requests are authenticated with an internal HMAC-SHA256 signature over
//   the raw body (EXTERNAL_INVENTORY_WEBHOOK_SECRET), verified in constant
//   time (see helpers.ts for why this is an internal scheme, not any given
//   provider's own signature). This endpoint intentionally does not accept
//   a Supabase user JWT — a provider webhook has no end-user identity.
// - No seeded provider (agoda, booking_com, makemytrip, generic_pms) has
//   real credentials configured; all are `blocked_external`. This function
//   independently refuses to apply any event whose connection's provider
//   is not `available`, returning `provider_blocked_external` rather than
//   silently accepting or faking a successful integration. This check is
//   defense-in-depth: apply_external_reservation_event() does not itself
//   gate on provider status, so this endpoint is what keeps a
//   not-yet-real integration from mutating live booking state.
// - apply_external_reservation_event is SECURITY DEFINER with EXECUTE
//   restricted to service_role (anon/authenticated cannot call it — see
//   supabase/tests/external_channel_production_security_contract.sql), so
//   this function uses the service-role client, never a caller JWT.
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  finiteNumber,
  isNonEmptyEventType,
  nonEmptyString,
  verifyInternalWebhookSignature,
  type ExternalInventoryWebhookPayload,
} from "./helpers.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const EXTERNAL_INVENTORY_WEBHOOK_SECRET =
  Deno.env.get("EXTERNAL_INVENTORY_WEBHOOK_SECRET") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-external-webhook-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  // A missing secret is a deployment/configuration gap. It must never be
  // treated as "no verification required" — fail closed instead.
  if (!EXTERNAL_INVENTORY_WEBHOOK_SECRET) {
    return jsonResponse({ error: "webhook_secret_not_configured" }, 500);
  }

  const rawBody = await req.text();
  const signature = req.headers.get("x-external-webhook-signature") ?? "";
  if (
    !verifyInternalWebhookSignature(
      rawBody,
      signature,
      EXTERNAL_INVENTORY_WEBHOOK_SECRET,
    )
  ) {
    return jsonResponse({ error: "invalid_signature" }, 401);
  }

  let event: ExternalInventoryWebhookPayload;
  try {
    event = JSON.parse(rawBody) as ExternalInventoryWebhookPayload;
  } catch (_) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const connectionId = nonEmptyString(event.connection_id);
  const externalEventId = nonEmptyString(event.external_event_id);
  const externalReservationId = nonEmptyString(
    event.external_reservation_id,
  );
  const bookDate = nonEmptyString(event.book_date);
  const eventType = event.event_type;

  if (
    !connectionId || !externalEventId || !isNonEmptyEventType(eventType) ||
    !externalReservationId || !bookDate
  ) {
    return jsonResponse({ error: "missing_or_invalid_fields" }, 400);
  }

  const venueId = nonEmptyString(event.venue_id) ?? null;
  const slotId = nonEmptyString(event.slot_id) ?? null;
  const guestRef = nonEmptyString(event.guest_ref) ?? null;
  const providerVersion = finiteNumber(event.provider_version) ?? null;
  const providerUpdatedAt = nonEmptyString(event.provider_updated_at) ?? null;
  const rawPayload =
    (event.raw_payload && typeof event.raw_payload === "object")
      ? event.raw_payload
      : {};

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  );

  // Independently confirm the connection's provider is genuinely
  // configured before ever calling into the RPC layer.
  const { data: connection, error: connectionError } = await supabase
    .from("external_channel_connections")
    .select(
      "id, external_channel_providers(code, status)",
    )
    .eq("id", connectionId)
    .maybeSingle();

  if (connectionError) {
    return jsonResponse({ error: "connection_lookup_failed" }, 500);
  }
  if (!connection) {
    return jsonResponse({ error: "unknown_connection" }, 404);
  }

  const providerRow = (connection as Record<string, unknown>)
    .external_channel_providers as { code?: string; status?: string } | null;

  if (!providerRow || providerRow.status !== "available") {
    await supabase.from("inventory_sync_errors").insert({
      connection_id: connectionId,
      error_code: "PROVIDER_BLOCKED_EXTERNAL",
      error_message:
        `Provider '${providerRow?.code ?? "unknown"}' is ${
          providerRow?.status ?? "unknown"
        }, not 'available'; webhook event rejected rather than faked.`,
      context: { external_event_id: externalEventId, event_type: eventType },
    });
    return jsonResponse(
      {
        error: "provider_blocked_external",
        provider_code: providerRow?.code ?? null,
      },
      409,
    );
  }

  const { data: result, error: rpcError } = await supabase.rpc(
    "apply_external_reservation_event",
    {
      p_connection_id: connectionId,
      p_external_event_id: externalEventId,
      p_event_type: eventType,
      p_external_reservation_id: externalReservationId,
      p_venue_id: venueId,
      p_slot_id: slotId,
      p_book_date: bookDate,
      p_provider_version: providerVersion,
      p_provider_updated_at: providerUpdatedAt,
      p_guest_ref: guestRef,
      p_raw_payload: rawPayload,
    },
  );

  if (rpcError) {
    return jsonResponse(
      { error: "rpc_failed", detail: rpcError.message },
      500,
    );
  }
  if (!result || typeof result !== "object") {
    return jsonResponse({ error: "empty_rpc_response" }, 502);
  }

  const outcome = result as Record<string, unknown>;
  if (outcome.success !== true) {
    const errorCode = typeof outcome.error_code === "string"
      ? outcome.error_code
      : "rejected";
    const status = errorCode === "UNKNOWN_CONNECTION" ? 404 : 409;
    return jsonResponse({ error: errorCode.toLowerCase() }, status);
  }

  return jsonResponse(outcome, 200);
});
