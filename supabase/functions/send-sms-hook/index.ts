import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

interface SendSmsEvent { user?: { phone?: string }; sms?: { otp?: string }; }

const hookSecrets = (Deno.env.get("SEND_SMS_HOOK_SECRET") || "")
  .split("|").map((secret) => secret.trim().replace(/^v\d+,whsec_/, "")).filter(Boolean);
const whatsappServiceUrl = (Deno.env.get("WHATSAPP_SERVICE_URL") || "").replace(/\/$/, "");
const whatsappApiKey = Deno.env.get("WHATSAPP_API_KEY") || "";
const jsonHeaders = { "Content-Type": "application/json" };

function jsonResponse(status: number, body: Record<string, string>) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}
function verifyEvent(payload: string, headers: Record<string, string>): SendSmsEvent {
  for (const secret of hookSecrets) {
    try { return new Webhook(secret).verify(payload, headers) as SendSmsEvent; } catch (_) {}
  }
  throw new Error("invalid_hook_signature");
}
function validPhone(phone: unknown): phone is string {
  return typeof phone === "string" && /^\+[1-9]\d{7,14}$/.test(phone.trim());
}
function validOtp(otp: unknown): otp is string {
  return typeof otp === "string" && /^\d{4,10}$/.test(otp.trim());
}
function otpMessage(otp: string): string {
  return [
    "*BookMySpace verification code*", "",
    `Your OTP is *${otp}*.`,
    "Use this code to complete your verification.", "",
    "Do not share this OTP with anyone.",
    "If you did not request this code, you can ignore this message.",
  ].join("\n");
}
async function sendWhatsAppOtp(phone: string, otp: string): Promise<void> {
  if (!whatsappServiceUrl || !whatsappApiKey) throw new Error("whatsapp_provider_not_configured");
  const response = await fetch(`${whatsappServiceUrl}/send-text`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": whatsappApiKey },
    body: JSON.stringify({ to: phone, text: otpMessage(otp) }),
  });
  if (!response.ok) throw new Error(`whatsapp_delivery_failed_${response.status}`);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return jsonResponse(405, { error: "method_not_allowed" });
  if (hookSecrets.length === 0) return jsonResponse(500, { error: "hook_not_configured" });
  if (!whatsappServiceUrl || !whatsappApiKey) {
    console.error("WhatsApp OTP provider is not configured");
    return jsonResponse(500, { error: "whatsapp_provider_not_configured" });
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
  if (!validPhone(phone) || !validOtp(otp)) return jsonResponse(400, { error: "invalid_hook_payload" });

  try {
    await sendWhatsAppOtp(phone, otp);
  } catch (error) {
    console.error("WhatsApp OTP delivery failed", {
      error: error instanceof Error ? error.message : "unknown_error",
    });
    return jsonResponse(502, { error: "whatsapp_delivery_failed" });
  }

  return new Response("{}", { status: 200, headers: jsonHeaders });
});
