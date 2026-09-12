import { createTextBeeClient, type Fetcher, TextBeeError } from "./textbee.ts";

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.test("sends the Supabase OTP using the TextBee API contract", async () => {
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  const fetcher: Fetcher = async (input, init) => {
    capturedUrl = input.toString();
    capturedInit = init;
    return response({ data: { success: true, smsBatchId: "batch-test" } });
  };

  const client = createTextBeeClient(
    {
      apiKey: "unit-test-api-key",
      baseUrl: "https://textbee.test",
      deviceId: "device-test",
      simSubscriptionId: 2,
    },
    fetcher,
  );
  const result = await client.sendOtp("+919876543210", "654321");

  if (capturedUrl !== "https://textbee.test/api/v1/gateway/send-sms") {
    throw new Error(`Unexpected TextBee endpoint: ${capturedUrl}`);
  }
  const headers = new Headers(capturedInit?.headers);
  if (headers.get("x-api-key") !== "unit-test-api-key") {
    throw new Error("TextBee API key was not sent in the expected header");
  }
  const requestBody = JSON.parse(String(capturedInit?.body)) as {
    recipients: string[];
    message: string;
    deviceId: string;
    simSubscriptionId: number;
  };
  if (requestBody.recipients[0] !== "+919876543210") {
    throw new Error("The phone recipient was not forwarded");
  }
  if (!requestBody.message.includes("654321")) {
    throw new Error("The Supabase OTP was not included in the SMS body");
  }
  if (
    requestBody.deviceId !== "device-test" ||
    requestBody.simSubscriptionId !== 2
  ) {
    throw new Error("Optional TextBee device routing was not forwarded");
  }
  if (result.smsBatchId !== "batch-test") {
    throw new Error("TextBee batch id was not returned");
  }
});

Deno.test("treats provider HTTP failures as delivery failures", async () => {
  const fetcher: Fetcher = async () => response({ error: "redacted" }, 401);
  const client = createTextBeeClient(
    { apiKey: "unit-test-api-key" },
    fetcher,
  );

  try {
    await client.sendOtp("+919876543210", "654321");
    throw new Error("Expected TextBeeError");
  } catch (error) {
    if (
      !(error instanceof TextBeeError) ||
      error.kind !== "http" ||
      error.status !== 401
    ) {
      throw new Error("Unexpected TextBee error classification");
    }
  }
});

Deno.test(
  "does not accept a successful HTTP response with a failed send result",
  async () => {
    const fetcher: Fetcher = async () =>
      response({ data: { successCount: 0, failureCount: 1 } });
    const client = createTextBeeClient(
      { apiKey: "unit-test-api-key" },
      fetcher,
    );

    try {
      await client.sendOtp("+919876543210", "654321");
      throw new Error("Expected TextBeeError");
    } catch (error) {
      if (!(error instanceof TextBeeError) || error.kind !== "rejected") {
        throw new Error("Unexpected TextBee rejection classification");
      }
    }
  },
);

Deno.test("rejects non-international phone numbers before making a request", async () => {
  let called = false;
  const fetcher: Fetcher = async () => {
    called = true;
    return response({ data: { success: true } });
  };
  const client = createTextBeeClient(
    { apiKey: "unit-test-api-key" },
    fetcher,
  );

  try {
    await client.sendOtp("9876543210", "654321");
    throw new Error("Expected TextBeeError");
  } catch (error) {
    if (!(error instanceof TextBeeError) || error.kind !== "invalid_request") {
      throw new Error("Unexpected invalid-request classification");
    }
  }
  if (called) throw new Error("Invalid phone number reached TextBee");
});
