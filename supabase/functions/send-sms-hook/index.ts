import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { createTextBeeClient, TextBeeError } from "./textbee.ts";

interface SendSmsEvent {
  user?: {
    phone?: string;
  };
  sms?: {
    otp?: string;
  };
}

const hookSecrets = (Deno.env.get("SEND_SMS_HOOK_SECRET") || "")
  .split("|")
  .map((secret) => secret.trim().replace(/^v\d+,whsec_/, ""))
  .filter(Boolean);

const textBeeApiKey = Deno.env.get("TEXTBEE_API_KEY") || "";
const textBeeBaseUrl = Deno.env.get("TEXTBEE_BASE_URL") || undefined;
const textBeeDeviceId = Deno.env.get("TEXTBEE_DEVICE_ID") || undefined;
const textBeeSimSubscriptionId = Number(
  Deno.env.get("TEXTBEE_SIM_SUBSCRIPTION_ID") || "",
);

const jsonHeaders = { "Content-Type": "application/json" };

function jsonResponse(status: number, body: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function verifyEvent(
  payload: string,
  headers: Record<string, string>,
): SendSmsEvent {
  for (const secret of hookSecrets) {
    try {
      return new Webhook(secret).verify(payload, headers) as SendSmsEvent;
    } catch (_) {
      // Try the next secret during a configured key rotation. Never log the
      // payload, OTP, or signing secret.
    }
  }
  throw new Error("invalid_hook_signature");
}

function validPhone(phone: unknown): phone is string {
  return typeof phone === "string" && /^\+[1-9]\d{7,14}$/.test(phone.trim());
}

function validOtp(otp: unknown): otp is string {
  return typeof otp === "string" && /^\d{4,10}$/.test(otp.trim());
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  if (hookSecrets.length === 0) {
    console.error("Send SMS hook secret is not configured");
    return jsonResponse(500, { error: "hook_not_configured" });
  }

  let event: SendSmsEvent;
  try {
    const payload = await request.text();
    event = verifyEvent(payload, Object.fromEntries(request.headers.entries()));
  } catch (_) {
    return jsonResponse(401, { error: "invalid_hook_signature" });
  }

  const phone = event.user?.phone;
  const otp = event.sms?.otp;
  if (!validPhone(phone) || !validOtp(otp)) {
    return jsonResponse(400, { error: "invalid_hook_payload" });
  }

  if (!textBeeApiKey.trim()) {
    console.error("TextBee API key is not configured");
    return jsonResponse(500, { error: "sms_provider_not_configured" });
  }

  try {
    const client = createTextBeeClient({
      apiKey: textBeeApiKey,
      baseUrl: textBeeBaseUrl,
      deviceId: textBeeDeviceId,
      simSubscriptionId: Number.isInteger(textBeeSimSubscriptionId)
        ? textBeeSimSubscriptionId
        : undefined,
    });
    await client.sendOtp(phone, otp);
  } catch (error) {
    if (error instanceof TextBeeError) {
      console.error("TextBee SMS delivery failed", {
        kind: error.kind,
        status: error.status,
      });
    } else {
      console.error("TextBee SMS delivery failed");
    }
    return jsonResponse(502, { error: "sms_delivery_failed" });
  }

  // Supabase Auth treats an empty 2xx JSON response as a successful hook call.
  return new Response("{}", { status: 200, headers: jsonHeaders });
});
