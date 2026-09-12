# Free OTP development

This runbook describes the development-only SMS delivery path for BookMySpace.
It uses Supabase Auth as the only authentication authority and TextBee only as
the SMS delivery transport. The carrier/SIM may still charge for messages.

## A. Architecture

```text
Flutter
  -> Supabase Auth (generates and verifies the OTP/session)
  -> Send SMS Hook (signed Standard Webhooks request)
  -> send-sms-hook Edge Function
  -> TextBee API
  -> Android phone + SIM
  -> SMS
  -> Flutter verifyOTP()
  -> Supabase session
```

The Flutter app never calls TextBee. It continues to call:

```dart
supabase.auth.signInWithOtp(phone: phoneNumber);
supabase.auth.verifyOTP(
  phone: phoneNumber,
  token: otp,
  type: OtpType.sms,
);
```

The existing email path remains Supabase Auth plus the configured SMTP provider.
Google/Apple sign-in, session handling, and sign-out are unchanged.

## B. TextBee setup

The current TextBee API uses:

- API root: `https://api.textbee.dev/api/v1`
- Send endpoint: `POST /gateway/send-sms`
- Authentication: `x-api-key` header
- Required JSON: `recipients: string[]` and `message: string`
- Optional routing: `deviceId` and `simSubscriptionId`

Create a TextBee account, verify its email, install the Android app, grant SMS
permissions, register the phone from the TextBee dashboard, and confirm that
the device is online. Disable battery optimization for TextBee. The app must
have an SMS-capable SIM and internet access.

TextBee can be cloud-hosted or self-hosted. For self-hosting, use the current
instructions in the official repository and set `TEXTBEE_BASE_URL` to the
self-hosted API root including `/api/v1`.

## C. Android phone setup

1. Install TextBee from the current [TextBee setup guide](https://textbee.dev/docs/getting-started/setting-up-textbee).
2. Grant SMS permissions and keep the app unrestricted by battery optimization.
3. Register the phone in the TextBee dashboard.
4. Confirm the device heartbeat is online and the SIM can send a normal SMS.
5. Keep the phone powered and connected during the manual test.

## D. Supabase Send SMS Hook setup

The repository contains `supabase/functions/send-sms-hook/index.ts`. It verifies
Supabase's Standard Webhooks signature, extracts the phone and Supabase-generated
OTP, sends that OTP through TextBee, and returns an empty 200 response only when
TextBee accepts the send. It never generates or verifies OTPs.

The function is configured with `verify_jwt = false` in `supabase/config.toml`
because Auth Hooks authenticate with the webhook signature, not a user JWT. The
function itself performs the signature check.

In the Supabase Dashboard for the development project:

1. Open **Authentication > Hooks**.
2. Add or edit **Send SMS** as an **HTTP Hook**.
3. Use the deployed function URL:
   `https://<project-ref>.supabase.co/functions/v1/send-sms-hook`.
4. Generate one signing secret locally and enter the same value in the hook
   configuration and the `SEND_SMS_HOOK_SECRET` Edge Function secret.
5. Keep Phone Auth enabled and automatic phone confirmation disabled so Auth
   generates an OTP and invokes the hook.

The hook is available on Supabase's Free and Pro plans according to the current
[Supabase Auth Hooks documentation](https://supabase.com/docs/guides/auth/auth-hooks).

Email remains a separate Supabase Auth path through Resend SMTP. Configure it in
**Authentication > SMTP Settings** with `smtp.resend.com`, port `465`, username
`resend`, a Resend API key, and a sender address from a verified Resend domain.
Keep the API key in Supabase's SMTP configuration only; it must not enter this
repository or the Flutter build.

## E. Supabase secrets

Do not add these values to Flutter, `--dart-define`, source files, or chat:

- `SEND_SMS_HOOK_SECRET`
- `TEXTBEE_API_KEY`
- `TEXTBEE_DEVICE_ID`
- `TEXTBEE_SIM_SUBSCRIPTION_ID` (optional)

`TEXTBEE_BASE_URL` is not secret, but it is kept server-side with the other
configuration. The default is `https://api.textbee.dev/api/v1`.

After installing the Supabase CLI and authenticating it, run these commands from
the project root. Keep the values in your local shell or an ignored secret file;
do not paste them into source control:

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref <project-ref>

hook_secret="v1,whsec_$(openssl rand -base64 32)"
supabase secrets set \
  --project-ref <project-ref> \
  SEND_SMS_HOOK_SECRET="$hook_secret" \
  TEXTBEE_API_KEY="$TEXTBEE_API_KEY" \
  TEXTBEE_DEVICE_ID="$TEXTBEE_DEVICE_ID" \
  TEXTBEE_BASE_URL="https://api.textbee.dev/api/v1"

supabase functions deploy send-sms-hook \
  --project-ref <project-ref> \
  --no-verify-jwt
```

If the SIM has multiple subscriptions, add
`TEXTBEE_SIM_SUBSCRIPTION_ID="$TEXTBEE_SIM_SUBSCRIPTION_ID"` to the secrets
command. The repository `.gitignore` ignores `.env.*`; no secret environment
file is created by this change.

The current Supabase CLI also supports `supabase secrets set --env-file
<ignored-file>`. Never use `supabase secrets list` output in logs or screenshots.

## F. Local development

The machine currently has no global `supabase` CLI command. Install it with the
Homebrew command above, or use the project-scoped CLI form documented by
Supabase (`npx supabase ...`) after adding it as a development dependency.

For local Edge Function development, provide the secrets through
`supabase/functions/.env` or `supabase functions serve --env-file <ignored-file>`.
Do not enable the local Auth hook unless a local TextBee endpoint and signing
secret are configured; otherwise local Auth will correctly fail closed.

## G. Flutter phone OTP flow

`SupabaseAuthRepository` remains responsible for `signInWithOtp(phone: ...)` and
`verifyOTP(..., type: OtpType.sms)`. Supabase owns OTP generation, expiry,
verification, user creation, refresh tokens, and the authenticated session.

The temporary development provider remains available only for no-Supabase local
unit-test scenarios. It cannot be selected by the application when Supabase is
configured, and profile/release builds cannot enable it.

Enter phone numbers in E.164 form, for example `+919876543210`, because TextBee
requires international recipients.

## H. Manual end-to-end test

Record each boundary separately; an API-accepted request is not proof of SMS
delivery or authentication.

1. Start the Android phone and TextBee.
2. Confirm the SIM can send SMS and the device is online.
3. Deploy `send-sms-hook` and configure the Supabase Send SMS Hook.
4. Launch BookMySpace on the iPhone simulator.
5. Select Phone Login and enter a real E.164 number.
6. Request an OTP.
7. Confirm the Edge Function log reports only a successful delivery outcome,
   without an OTP or phone number.
8. Confirm TextBee accepted the request and the Android phone queued/sent it.
9. Confirm the SMS was delivered to the phone.
10. Enter the actual OTP in BookMySpace.
11. Confirm Supabase `verifyOTP()` succeeds and an authenticated session exists.
12. Confirm the app reaches the authenticated state and sign-out still works.

Do not use `123456` for this test and do not mark the integration working from a
TextBee HTTP 200 alone.

## I. Troubleshooting

- `401 invalid_hook_signature`: the Dashboard hook secret and
  `SEND_SMS_HOOK_SECRET` do not match, or the `v1,whsec_` value was altered.
- `500 hook_not_configured`: deploy the function secret before enabling the
  hook.
- `500 sms_provider_not_configured`: set `TEXTBEE_API_KEY` as an Edge Function
  secret.
- `502 sms_delivery_failed`: inspect the TextBee dashboard for device status,
  SIM availability, account verification, API-key validity, or plan limits.
- Hook never runs: ensure Phone Auth is enabled, automatic phone confirmation is
  off, and the app is calling Supabase Auth rather than a mock provider.
- SMS not delivered after acceptance: distinguish TextBee queue acceptance from
  Android device send status, carrier delivery, and the destination phone.
- OTP rejected: use the newest code, check expiry/rate limits, and verify the
  same E.164 phone number that requested it.

## J. Security notes

The Edge Function never logs the request body, phone number, OTP, API key, or
hook secret. TextBee credentials and the signing secret are server-side only.
The mobile app contains only the Supabase public URL/client key already required
by the existing architecture.

## K. Future provider swap

Keep Flutter and Supabase Auth unchanged. Replace only the adapter behind the
Send SMS Hook with a later provider implementation (for example MSG91 or
Twilio) after evaluating its cost, regional requirements, and credentials. Do
not add provider SDKs, keys, OTP storage, or session logic to Flutter.
