import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
// Pinned, server-only dependencies. They are never bundled into Flutter.
// @ts-ignore npm package declarations are resolved by the Supabase Edge runtime.
import { PDFDocument, StandardFonts, rgb } from 'npm:pdf-lib@1.17.1';
// @ts-ignore npm package declarations are resolved by the Supabase Edge runtime.
import QRCode from 'npm:qrcode@1.5.4';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Content-Type': 'application/json' };

function response(body: unknown, status = 200) { return new Response(JSON.stringify(body), { status, headers: cors }); }
function safeRef(invoiceNumber: string, bookingRef: string) { return `BMS-INVOICE:${invoiceNumber}:${bookingRef}`; }

const SMALL = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const TENS = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

function underThousand(value: number): string {
  const parts: string[] = [];
  if (value >= 100) {
    parts.push(`${SMALL[Math.floor(value / 100)]} Hundred`);
    value %= 100;
  }
  if (value >= 20) {
    parts.push(TENS[Math.floor(value / 10)]);
    value %= 10;
  }
  if (value > 0) parts.push(SMALL[value]);
  return parts.join(' ');
}

function amountInWords(value: number): string {
  const rounded = Math.max(0, Math.round(value * 100) / 100);
  let rupees = Math.floor(rounded);
  const paise = Math.round((rounded - rupees) * 100);
  if (rupees === 0) return paise ? `Rupees Zero and ${underThousand(paise)} Paise Only` : 'Rupees Zero Only';
  const parts: string[] = [];
  const crore = Math.floor(rupees / 10000000); rupees %= 10000000;
  const lakh = Math.floor(rupees / 100000); rupees %= 100000;
  const thousand = Math.floor(rupees / 1000); rupees %= 1000;
  if (crore) parts.push(`${underThousand(crore)} Crore`);
  if (lakh) parts.push(`${underThousand(lakh)} Lakh`);
  if (thousand) parts.push(`${underThousand(thousand)} Thousand`);
  if (rupees) parts.push(underThousand(rupees));
  if (paise) parts.push(`and ${underThousand(paise)} Paise`);
  return `Rupees ${parts.join(' ')} Only`;
}

async function enqueueInvoiceEmail(admin: SupabaseClient, booking: any, invoice: any, payment: any) {
  const { data: customer } = await admin.auth.admin.getUserById(booking.user_id);
  if (!customer.user?.email) return false;
  await admin.from('email_outbox').upsert({
    event_key: `invoice.generated.customer.${invoice.id}`,
    event_type: 'invoice.generated',
    recipient_email: customer.user.email,
    recipient_name: String(customer.user.user_metadata?.full_name ?? ''),
    booking_id: booking.id,
    payment_id: payment?.id ?? null,
    invoice_id: invoice.id,
    template_name: 'invoice-generated',
    payload: { invoice_number: invoice.invoice_number, booking_ref: booking.booking_ref, amount: booking.total_amount },
    attachment_metadata: [{ bucket: 'invoices', path: invoice.storage_path, filename: `${invoice.invoice_number}.pdf` }],
    status: 'pending',
    next_attempt_at: new Date().toISOString(),
  }, { onConflict: 'event_key', ignoreDuplicates: true });
  return true;
}

async function authorised(client: SupabaseClient, authHeader: string, booking: any, userId: string) {
  if (booking.user_id === userId) return true;
  const { data: roles } = await client.from('user_roles').select('role').eq('user_id', userId).is('revoked_at', null);
  if ((roles ?? []).some((r: any) => ['administrator', 'super_administrator'].includes(r.role))) return true;
  const { data: org } = await client.from('organizations').select('owner_user_id').eq('id', booking.venues?.org_id).maybeSingle();
  return org?.owner_user_id === userId;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const auth = req.headers.get('Authorization');
  if (!auth) return response({ error: 'missing_auth' }, 401);
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY') ?? '', { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return response({ error: 'unauthorized' }, 401);
  const admin = createClient(url, serviceKey);
  try {
    const { booking_id } = await req.json();
    if (!booking_id) return response({ error: 'missing_booking_id' }, 400);
    const { data: booking, error: bookingError } = await admin.from('bookings')
      .select('id, booking_ref, user_id, status, amount, tax_amount, total_amount, currency, book_date, start_time, end_time, venues(name, city, org_id), payments(id, status, provider_payment_id, amount, currency, created_at)')
      .eq('id', booking_id).single();
    if (bookingError || !booking) return response({ error: 'booking_not_found' }, 404);
    if (!await authorised(admin, auth, booking, user.id)) return response({ error: 'forbidden' }, 403);
    if (!['confirmed', 'completed', 'refunded', 'no_show'].includes(booking.status)) return response({ error: 'booking_not_invoiceable' }, 409);
    const payment = (booking.payments ?? []).find((p: any) => ['captured', 'refunded', 'partially_refunded'].includes(p.status)) ?? (booking.payments ?? [])[0];
    const { data: tax, error: taxError } = await admin.rpc('calculate_invoice_tax', { p_booking_id: booking.id });
    if (taxError || !tax) return response({ error: 'invoice_tax_calculation_failed' }, 500);
    const invoiceNumber = `${String(tax.invoice_prefix ?? 'BMS').toUpperCase()}-${new Date().getUTCFullYear()}-${String(booking.booking_ref).replace(/[^A-Za-z0-9]/g, '').slice(-12)}`;
    const { data: existing } = await admin.from('invoice_documents').select('*').eq('booking_id', booking.id).maybeSingle();
    if (existing?.status === 'generated' && existing.storage_path) {
      const { data: signed } = await admin.storage.from('invoices').createSignedUrl(existing.storage_path, 900);
      const emailQueued = await enqueueInvoiceEmail(admin, booking, existing, payment);
      return response({ invoice: existing, signed_url: signed?.signedUrl ?? null, email_queued: emailQueued, tax_details: existing.tax_snapshot ?? tax });
    }
    const { data: invoice, error: invoiceError } = await admin.from('invoice_documents').upsert({
      invoice_number: existing?.invoice_number ?? invoiceNumber,
      booking_id: booking.id,
      payment_id: payment?.id ?? null,
      status: 'pending',
      tax_mode: tax.tax_mode,
      sac_code: tax.sac_code,
      seller_gstin: tax.seller_gstin,
      seller_pan: tax.seller_pan,
      buyer_gstin: tax.buyer_gstin,
      buyer_pan: tax.buyer_pan,
      taxable_amount: tax.taxable_amount,
      cgst_amount: tax.cgst_amount,
      sgst_amount: tax.sgst_amount,
      igst_amount: tax.igst_amount,
      amount_in_words: amountInWords(Number(booking.total_amount ?? 0)),
      tax_snapshot: tax,
    }, { onConflict: 'booking_id' }).select().single();
    if (invoiceError || !invoice) return response({ error: 'invoice_claim_failed' }, 500);
    const verify = safeRef(invoice.invoice_number, booking.booking_ref);
    const qrPng = await QRCode.toBuffer(verify, { type: 'png', width: 180, margin: 1 });
    const pdf = await PDFDocument.create();
    const page = pdf.addPage([595, 842]);
    const font = await pdf.embedFont(StandardFonts.Helvetica);
    const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
    const qr = await pdf.embedPng(qrPng);
    const text = (value: string, x: number, y: number, size = 11, isBold = false) => page.drawText(value.slice(0, 180), { x, y, size, font: isBold ? bold : font, color: rgb(0.12, 0.16, 0.25) });
    text('BOOKMYSPACE', 48, 790, 22, true); text('TAX INVOICE / PAYMENT RECEIPT', 48, 760, 13, true);
    text(`Invoice: ${invoice.invoice_number}`, 48, 725); text(`Booking: ${booking.booking_ref}`, 48, 706);
    text(`Property: ${booking.venues?.name ?? 'BookMySpace venue'}`, 48, 670, 12, true); text(`Location: ${booking.venues?.city ?? ''}`, 48, 650);
    text(`Date: ${booking.book_date}`, 48, 615); text(`Time: ${String(booking.start_time).slice(0, 5)} - ${String(booking.end_time).slice(0, 5)}`, 48, 595);
    text(`Seller GSTIN: ${tax.seller_gstin ?? 'Not registered'}`, 48, 570); text(`Seller PAN: ${tax.seller_pan ?? 'Not provided'}`, 48, 552); text(`SAC: ${tax.sac_code ?? '997212'} | Tax mode: ${tax.tax_mode ?? 'unregistered'}`, 48, 534, 10);
    text(`Taxable amount: ${booking.currency} ${tax.taxable_amount ?? booking.amount}`, 48, 505); text(`CGST: ${booking.currency} ${tax.cgst_amount ?? 0}`, 48, 487); text(`SGST: ${booking.currency} ${tax.sgst_amount ?? 0}`, 48, 469); text(`IGST: ${booking.currency} ${tax.igst_amount ?? 0}`, 48, 451); text(`Total: ${booking.currency} ${booking.total_amount}`, 48, 420, 13, true);
    text(`Amount in words: ${amountInWords(Number(booking.total_amount ?? 0))}`, 48, 395, 9); text(`Payment reference: ${payment?.provider_payment_id ?? 'offline'}`, 48, 370); text(`Verification reference: ${verify}`, 48, 345, 9);
    page.drawImage(qr, { x: 400, y: 440, width: 130, height: 130 });
    text('This document contains no payment secrets. Verify using the reference above.', 48, 90, 9);
    const bytes = await pdf.save();
    const path = `${booking.user_id}/${booking.id}/${invoice.invoice_number}.pdf`;
    const upload = await admin.storage.from('invoices').upload(path, bytes, { contentType: 'application/pdf', upsert: true });
    if (upload.error) { await admin.from('invoice_documents').update({ status: 'failed', error_message: 'storage_upload_failed' }).eq('id', invoice.id); return response({ error: 'invoice_storage_failed' }, 500); }
    const { data: generated, error: generatedError } = await admin.from('invoice_documents').update({ storage_path: path, status: 'generated', generated_at: new Date().toISOString(), error_message: null, amount_in_words: amountInWords(Number(booking.total_amount ?? 0)), tax_snapshot: tax }).eq('id', invoice.id).select().single();
    if (generatedError || !generated) return response({ error: 'invoice_finalize_failed' }, 500);
    const { data: signed } = await admin.storage.from('invoices').createSignedUrl(path, 900);
    const emailQueued = await enqueueInvoiceEmail(admin, booking, { ...generated, storage_path: path }, payment);
    return response({ invoice: generated, signed_url: signed?.signedUrl ?? null, email_queued: emailQueued, tax_details: tax });
  } catch (_) { return response({ error: 'invoice_generation_failed' }, 500); }
});
