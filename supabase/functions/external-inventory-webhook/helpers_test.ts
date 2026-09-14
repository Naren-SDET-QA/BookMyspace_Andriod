import { createHmac } from "node:crypto";

import {
  finiteNumber,
  isNonEmptyEventType,
  nonEmptyString,
  verifyInternalWebhookSignature,
} from "./helpers.ts";

Deno.test("verifies the raw external-inventory webhook body signature", () => {
  const body = '{"event_type":"reservation.created"}';
  const secret = "webhook-test-secret";
  const signature = createHmac("sha256", secret).update(body).digest("hex");

  if (!verifyInternalWebhookSignature(body, signature, secret)) {
    throw new Error("A valid webhook signature was rejected");
  }
  if (verifyInternalWebhookSignature(body, "invalid", secret)) {
    throw new Error("An invalid webhook signature was accepted");
  }
});

Deno.test("a missing secret never verifies, even against a matching signature", () => {
  const body = '{"event_type":"reservation.created"}';
  const signature = createHmac("sha256", "").update(body).digest("hex");

  if (verifyInternalWebhookSignature(body, signature, "")) {
    throw new Error("An empty secret was treated as a valid configuration");
  }
});

Deno.test("signature verification does not require a global Buffer", () => {
  const globalObject = globalThis as Record<string, unknown>;
  const previousBuffer = globalObject.Buffer;
  const body = '{"event_type":"reservation.created"}';
  const secret = "webhook-test-secret";
  const signature = createHmac("sha256", secret).update(body).digest("hex");

  try {
    delete globalObject.Buffer;
    if (!verifyInternalWebhookSignature(body, signature, secret)) {
      throw new Error(
        "A valid webhook signature required a global Buffer implementation",
      );
    }
  } finally {
    if (previousBuffer === undefined) {
      delete globalObject.Buffer;
    } else {
      globalObject.Buffer = previousBuffer;
    }
  }
});

Deno.test("nonEmptyString trims and rejects blank/non-string values", () => {
  if (nonEmptyString("  ext-1  ") !== "ext-1") {
    throw new Error("A padded string identity was not trimmed");
  }
  if (nonEmptyString("   ") !== undefined) {
    throw new Error("A blank string was treated as a valid identity");
  }
  if (nonEmptyString(42) !== undefined) {
    throw new Error("A non-string value was treated as a valid identity");
  }
});

Deno.test("finiteNumber rejects NaN, Infinity, and non-numbers", () => {
  if (finiteNumber(3) !== 3) {
    throw new Error("A finite number was rejected");
  }
  if (finiteNumber(Number.NaN) !== undefined) {
    throw new Error("NaN was treated as a valid provider_version");
  }
  if (finiteNumber(Number.POSITIVE_INFINITY) !== undefined) {
    throw new Error("Infinity was treated as a valid provider_version");
  }
  if (finiteNumber("3") !== undefined) {
    throw new Error("A numeric string was treated as a valid provider_version");
  }
});

Deno.test("isNonEmptyEventType only accepts a non-empty string", () => {
  if (!isNonEmptyEventType("reservation.created")) {
    throw new Error("A legitimate event_type was rejected");
  }
  if (isNonEmptyEventType("")) {
    throw new Error("An empty event_type was accepted");
  }
  if (isNonEmptyEventType(undefined)) {
    throw new Error("A missing event_type was accepted");
  }
});
