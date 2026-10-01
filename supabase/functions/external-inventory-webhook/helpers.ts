import { Buffer } from "node:buffer";
import { createHmac, timingSafeEqual } from "node:crypto";

// Internal signature scheme — NOT any specific provider's own webhook
// signature. BookMySpace has no real, credentialed integration with any
// external channel provider yet (every seeded provider — agoda,
// booking_com, makemytrip, generic_pms — is `blocked_external`). This
// HMAC-SHA256-over-raw-body check authenticates that a request reaching
// this endpoint came from a trusted internal caller (an authorized manual
// test, an internal relay, or — once a specific provider is genuinely
// onboarded with real credentials — that provider's own verifier running
// upstream of this function). When a real provider integration is added,
// that provider's own signature scheme MUST be verified in addition to
// (never instead of) this check, and only then should that provider's
// status move out of `blocked_external`.
export function verifyInternalWebhookSignature(
  body: string,
  signature: string,
  secret: string,
): boolean {
  if (!secret || !signature) return false;
  const expected = createHmac("sha256", secret).update(body).digest("hex");
  const actualBytes = Buffer.from(signature);
  const expectedBytes = Buffer.from(expected);
  return (
    actualBytes.length === expectedBytes.length &&
    timingSafeEqual(actualBytes, expectedBytes)
  );
}

export type ExternalInventoryWebhookPayload = {
  connection_id?: unknown;
  external_event_id?: unknown;
  event_type?: unknown;
  external_reservation_id?: unknown;
  venue_id?: unknown;
  slot_id?: unknown;
  book_date?: unknown;
  provider_version?: unknown;
  provider_updated_at?: unknown;
  guest_ref?: unknown;
  raw_payload?: unknown;
};

export function nonEmptyString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : undefined;
}

export function finiteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? value
    : undefined;
}

// apply_external_reservation_event() itself owns the meaning of event_type
// (only 'reservation.cancelled' is special-cased; everything else is
// treated as a booking/update) — this function does not second-guess that
// contract with its own allow-list, only requires a non-empty identity.
export function isNonEmptyEventType(value: unknown): value is string {
  return nonEmptyString(value) !== undefined;
}
