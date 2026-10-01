/**
 * Small delivery adapter for TextBee.
 *
 * This module deliberately knows nothing about Supabase Auth. It only sends
 * the OTP it receives from the signed hook event. Keeping this boundary small
 * makes a later provider swap independent from Flutter and Auth verification.
 */

export type TextBeeErrorKind =
  | "not_configured"
  | "invalid_request"
  | "timeout"
  | "network"
  | "http"
  | "rejected";

export class TextBeeError extends Error {
  constructor(
    public readonly kind: TextBeeErrorKind,
    public readonly status?: number,
  ) {
    super("TextBee SMS delivery failed");
    this.name = "TextBeeError";
  }
}

export interface TextBeeClientConfig {
  apiKey: string;
  baseUrl?: string;
  deviceId?: string;
  simSubscriptionId?: number;
  timeoutMs?: number;
}

export interface TextBeeSendResult {
  smsBatchId?: string;
  successCount?: number;
  failureCount?: number;
}

export type Fetcher = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

const defaultBaseUrl = "https://api.textbee.dev/api/v1";
const defaultTimeoutMs = 10_000;

function apiBaseUrl(value: string | undefined): string {
  const baseUrl = (value || defaultBaseUrl).trim().replace(/\/+$/, "");
  return baseUrl.endsWith("/api/v1") ? baseUrl : `${baseUrl}/api/v1`;
}

function acceptedSend(data: Record<string, unknown>): boolean {
  if (data.success === false) return false;
  if (typeof data.failureCount === "number" && data.failureCount > 0) {
    return false;
  }
  if (data.success === true) return true;

  const successCount = data.successCount;
  return (
    typeof successCount === "number" &&
    successCount > 0 &&
    (typeof data.failureCount !== "number" || data.failureCount === 0)
  );
}

export function createTextBeeClient(
  config: TextBeeClientConfig,
  fetcher: Fetcher = fetch,
) {
  const apiKey = config.apiKey.trim();
  if (!apiKey) {
    throw new TextBeeError("not_configured");
  }

  const endpoint = `${apiBaseUrl(config.baseUrl)}/gateway/send-sms`;
  const timeoutMs = Math.max(1_000, config.timeoutMs ?? defaultTimeoutMs);

  return {
    async sendOtp(phone: string, otp: string): Promise<TextBeeSendResult> {
      const recipient = phone.trim();
      const code = otp.trim();

      if (!/^\+[1-9]\d{7,14}$/.test(recipient) || !/^\d{4,10}$/.test(code)) {
        throw new TextBeeError("invalid_request");
      }

      const body: Record<string, unknown> = {
        recipients: [recipient],
        message:
          `Your BookMySpace verification code is ${code}. It expires soon.`,
      };
      const deviceId = config.deviceId?.trim();
      if (deviceId) body.deviceId = deviceId;
      if (
        typeof config.simSubscriptionId === "number" &&
        Number.isInteger(config.simSubscriptionId) &&
        config.simSubscriptionId > 0
      ) {
        body.simSubscriptionId = config.simSubscriptionId;
      }

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
      let response: Response;
      try {
        response = await fetcher(endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
          },
          body: JSON.stringify(body),
          signal: controller.signal,
        });
      } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
          throw new TextBeeError("timeout");
        }
        throw new TextBeeError("network");
      } finally {
        clearTimeout(timeoutId);
      }

      const responseBody = (await response.json().catch(() => null)) as unknown;
      if (!response.ok) {
        throw new TextBeeError("http", response.status);
      }

      const data = typeof responseBody === "object" &&
          responseBody !== null &&
          "data" in responseBody &&
          typeof responseBody.data === "object" &&
          responseBody.data !== null
        ? (responseBody.data as Record<string, unknown>)
        : null;

      if (!data || !acceptedSend(data)) {
        throw new TextBeeError("rejected", response.status);
      }

      return {
        smsBatchId: typeof data.smsBatchId === "string"
          ? data.smsBatchId
          : undefined,
        successCount: typeof data.successCount === "number"
          ? data.successCount
          : undefined,
        failureCount: typeof data.failureCount === "number"
          ? data.failureCount
          : undefined,
      };
    },
  };
}
