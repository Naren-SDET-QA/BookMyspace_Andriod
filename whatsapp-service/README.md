# BookMySpace WhatsApp Service

Small server-side WhatsApp notification service for BookMySpace.

It uses Baileys outside the Flutter application. Baileys communicates over WhatsApp Web without embedding Chromium/Selenium, so this directory has zero impact on the Android APK, iOS app, or Flutter Web bundle.

## Endpoints

All endpoints except /health require x-api-key.

- GET /health
- GET /status
- POST /pairing-code with { "phone": "919876543210" }
- POST /send-text with { "to": "919876543210", "text": "..." }
- POST /send-media with { "to": "...", "base64": "...", "mimetype": "application/pdf", "fileName": "booking.pdf", "caption": "..." }

## Run

cd whatsapp-service
cp .env.example .env
npm install
npm run dev

For production:

npm install
npm run build
npm start

Persist AUTH_DIR across container restarts so the WhatsApp account does not need to be linked again.

## Pairing

Start the service and call:

curl -X POST http://localhost:8787/pairing-code -H "x-api-key: $WHATSAPP_API_KEY" -H "content-type: application/json" -d '{"phone":"919876543210"}'

Enter the returned pairing code in WhatsApp on the phone that owns that number. A QR string is also available from /status during first-time pairing.

## Security

- Put the service behind HTTPS.
- Keep WHATSAPP_API_KEY only on the server.
- Never put the key in Flutter or Web.
- Mount the auth directory on persistent storage.
- Do not expose /send-* publicly without authentication.
- Use this for opted-in transactional/customer-service messaging, not unsolicited bulk messaging.

Baileys is MIT-licensed but is an unofficial WhatsApp Web integration.
