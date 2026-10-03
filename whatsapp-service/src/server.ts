import { createServer } from 'node:http';
import { mkdir } from 'node:fs/promises';
import makeWASocket, {
  DisconnectReason,
  useMultiFileAuthState,
  type WAMessageContent,
} from '@whiskeysockets/baileys';

const PORT = Number(process.env.PORT ?? 8787);
const API_KEY = process.env.WHATSAPP_API_KEY ?? '';
const AUTH_DIR = process.env.AUTH_DIR ?? './data/auth';
const INSTANCE_NAME = process.env.INSTANCE_NAME ?? 'bookmyspace';
const MARK_ONLINE_ON_CONNECT =
  (process.env.MARK_ONLINE_ON_CONNECT ?? 'false').toLowerCase() === 'true';

let socket: ReturnType<typeof makeWASocket> | null = null;
let connected = false;
let latestQr: string | null = null;
let reconnectTimer: NodeJS.Timeout | null = null;

function json(res: any, status: number, value: unknown) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(JSON.stringify(value));
}

async function readBody(req: any): Promise<any> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(Buffer.from(chunk));
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function authorized(req: any): boolean {
  return Boolean(API_KEY) && req.headers['x-api-key'] === API_KEY;
}

function jidFromPhone(phone: string): string {
  const digits = phone.replace(/[^0-9]/g, '');
  if (digits.length < 8) throw new Error('Invalid phone number');
  return digits + '@s.whatsapp.net';
}

async function connect() {
  await mkdir(AUTH_DIR, { recursive: true });
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);

  socket = makeWASocket({
    auth: state,
    markOnlineOnConnect: MARK_ONLINE_ON_CONNECT,
    syncFullHistory: false,
  });

  socket.ev.on('creds.update', saveCreds);

  socket.ev.on('connection.update', ({ connection, lastDisconnect, qr }) => {
    if (qr) latestQr = qr;

    if (connection === 'open') {
      connected = true;
      latestQr = null;
      console.log(JSON.stringify({ event: 'whatsapp_connected', instance: INSTANCE_NAME }));
      return;
    }

    if (connection === 'close') {
      connected = false;
      socket = null;
      const statusCode = (lastDisconnect?.error as any)?.output?.statusCode;
      const loggedOut = statusCode === DisconnectReason.loggedOut;

      console.warn(JSON.stringify({
        event: 'whatsapp_disconnected',
        instance: INSTANCE_NAME,
        loggedOut,
      }));

      if (!loggedOut && !reconnectTimer) {
        reconnectTimer = setTimeout(() => {
          reconnectTimer = null;
          void connect().catch((error) =>
            console.error(JSON.stringify({
              event: 'whatsapp_reconnect_failed',
              error: String(error),
            })),
          );
        }, 2000);
      }
    }
  });
}

async function sendText(to: string, text: string) {
  if (!socket || !connected) throw new Error('WhatsApp is not connected');
  return socket.sendMessage(jidFromPhone(to), { text });
}

async function sendMedia(
  to: string,
  base64: string,
  mimetype: string,
  fileName?: string,
  caption?: string,
) {
  if (!socket || !connected) throw new Error('WhatsApp is not connected');
  const buffer = Buffer.from(base64, 'base64');
  const content: WAMessageContent = mimetype.startsWith('image/')
    ? { image: buffer, mimetype, caption }
    : mimetype.startsWith('video/')
      ? { video: buffer, mimetype, caption }
      : mimetype.startsWith('audio/')
        ? { audio: buffer, mimetype }
        : { document: buffer, mimetype, fileName: fileName ?? 'document' };

  return socket.sendMessage(jidFromPhone(to), content);
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', 'http://127.0.0.1:' + PORT);

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, { ok: true, connected, instance: INSTANCE_NAME });
    }

    if (!authorized(req)) {
      return json(res, 401, { ok: false, error: 'Unauthorized' });
    }

    if (req.method === 'GET' && url.pathname === '/status') {
      return json(res, 200, {
        ok: true,
        connected,
        instance: INSTANCE_NAME,
        qr: latestQr,
      });
    }

    if (req.method === 'POST' && url.pathname === '/pairing-code') {
      if (!socket) return json(res, 503, { ok: false, error: 'WhatsApp socket is starting' });
      const payload = await readBody(req);
      const phone = String(payload.phone ?? '').replace(/[^0-9]/g, '');
      if (!phone) return json(res, 400, { ok: false, error: 'phone is required' });
      const code = await socket.requestPairingCode(phone);
      return json(res, 200, { ok: true, code });
    }

    if (req.method === 'POST' && url.pathname === '/send-text') {
      const payload = await readBody(req);
      const to = String(payload.to ?? '');
      const text = String(payload.text ?? '');
      if (!to || !text) {
        return json(res, 400, { ok: false, error: 'to and text are required' });
      }
      const result = await sendText(to, text);
      return json(res, 200, { ok: true, messageId: result?.key?.id ?? null });
    }

    if (req.method === 'POST' && url.pathname === '/send-media') {
      const payload = await readBody(req);
      const to = String(payload.to ?? '');
      const base64 = String(payload.base64 ?? '');
      const mimetype = String(payload.mimetype ?? 'application/octet-stream');
      if (!to || !base64) {
        return json(res, 400, { ok: false, error: 'to and base64 are required' });
      }
      if (Buffer.byteLength(base64, 'utf8') > 14_000_000) {
        return json(res, 413, { ok: false, error: 'media payload is too large' });
      }
      const result = await sendMedia(
        to,
        base64,
        mimetype,
        payload.fileName ? String(payload.fileName) : undefined,
        payload.caption ? String(payload.caption) : undefined,
      );
      return json(res, 200, { ok: true, messageId: result?.key?.id ?? null });
    }

    return json(res, 404, { ok: false, error: 'Not found' });
  } catch (error) {
    console.error(JSON.stringify({ event: 'request_failed', error: String(error) }));
    return json(res, 500, { ok: false, error: 'Request failed' });
  }
});

if (!API_KEY) {
  console.error('WHATSAPP_API_KEY is required; refusing to start.');
  process.exit(1);
}

server.listen(PORT, () => {
  console.log(JSON.stringify({
    event: 'whatsapp_service_started',
    port: PORT,
    instance: INSTANCE_NAME,
  }));
  void connect().catch((error) => {
    console.error(JSON.stringify({ event: 'whatsapp_start_failed', error: String(error) }));
    process.exit(1);
  });
});
