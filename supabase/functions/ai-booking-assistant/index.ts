import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const providerUrl = Deno.env.get('AI_PROVIDER_URL');
const providerKey = Deno.env.get('AI_PROVIDER_KEY');
const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {status, headers:{...headers,'Content-Type':'application/json'}});
const tools = ['search_facilities','resolve_capabilities','check_availability','retrieve_pricing','prepare_booking_intent','create_booking'];
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const date = /^\d{4}-\d{2}-\d{2}$/;

async function executeTool(db: SupabaseClient, userId: string, name: string, args: Record<string, unknown>) {
  if (!tools.includes(name)) return {error:'unknown_tool'};
  if (name === 'search_facilities') {
    const q = typeof args.query === 'string' ? args.query.trim().slice(0,80) : '';
    if (!q) return {error:'invalid_query'};
    const {data,error} = await db.from('venues').select('id,name,city,description,pricing_base_amount').or(`name.ilike.%${q}%,city.ilike.%${q}%`).eq('is_active',true).limit(20);
    if (error) return {error:'search_unavailable'};
    return {venues:data ?? []};
  }
  const venueId = args.venue_id;
  if (typeof venueId !== 'string' || !uuid.test(venueId)) return {error:'invalid_venue_id'};
  if (name === 'resolve_capabilities') {
    const {data,error}=await db.from('venues').select('id,capabilities').eq('id',venueId).eq('is_active',true).maybeSingle();
    return error || !data ? {error:'venue_not_found'} : {venue_id:venueId, capabilities:data.capabilities ?? {}};
  }
  if (name === 'check_availability' || name === 'retrieve_pricing') {
    const d=args.book_date;
    if (typeof d !== 'string' || !date.test(d)) return {error:'invalid_book_date'};
    const {data,error}=await db.rpc('available_time_slots',{p_venue_id:venueId,p_book_date:d});
    if (error) return {error:'availability_unavailable'};
    const rows=(data ?? []).map((r: Record<string,unknown>)=>({slot_id:r.slot_id,label:r.label,start_time:r.start_time,end_time:r.end_time,is_available:r.is_available,price_amount:r.price_amount,reason:r.reason}));
    return {venue_id:venueId,book_date:d,slots:rows};
  }
  if (name === 'prepare_booking_intent') {
    const slot=args.slot_id;
    const d=args.book_date;
    if (typeof slot !== 'string' || !uuid.test(slot) || typeof d !== 'string' || !date.test(d)) return {error:'invalid_booking_intent'};
    return {ready:true,requires_confirmation:true,venue_id:venueId,slot_id:slot,book_date:d};
  }
  if (name === 'create_booking') {
    if (args.confirmed !== true) return {error:'explicit_confirmation_required'};
    const slot=args.slot_id, d=args.book_date, key=args.idempotency_key;
    if (typeof slot !== 'string' || !uuid.test(slot) || typeof d !== 'string' || !date.test(d) || typeof key !== 'string' || key.length < 16) return {error:'invalid_booking_input'};
    const {data,error}=await db.rpc('request_venue_booking',{p_venue_id:venueId,p_slot_id:slot,p_book_date:d,p_user_id:userId,p_idempotency_key:key,p_base_amount:0,p_tax_amount:0,p_discount_amount:0,p_approval_minutes:120});
    if (error || !data || (data as Record<string,unknown>).success !== true) return {error:'booking_not_created'};
    return {booking:data,approval_required:true,payment_required:true};
  }
  return {error:'unsupported_tool'};
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json({ok:true});
  const auth = req.headers.get('Authorization');
  if (!auth) return json({error:'missing_auth'},401);
  // Keep the caller's JWT as the database identity so RLS/tenant policies are
  // evaluated for every AI tool. No service-role client is needed here.
  const db=createClient(url,anonKey,{global:{headers:{Authorization:auth}}});
  const {data:{user}}=await db.auth.getUser();
  if (!user) return json({error:'unauthorized'},401);
  try {
    const body=await req.json();
    if (body?.tool) {
      if (typeof body.tool !== 'string' || !tools.includes(body.tool) ||
          !body.args || typeof body.args !== 'object') return json({error:'invalid_tool_request'},400);
      const result = await executeTool(db, user.id, body.tool, body.args as Record<string, unknown>);
      console.log(JSON.stringify({event:'ai_tool',user_id:user.id,tool:body.tool}));
      return json({tool:body.tool,result});
    }
    const message=typeof body.message==='string'?body.message.trim().slice(0,1000):'';
    if (!message) return json({error:'invalid_message'},400);
    if (!providerUrl || !providerKey) return json({error:'ai_provider_unavailable',fallback:'Use search and booking screens directly'},503);
    const response=await fetch(providerUrl,{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${providerKey}`},body:JSON.stringify({messages:[{role:'user',content:message}],tools:tools.map(name=>({type:'function',function:{name,description:`Validated BookMySpace ${name} tool`,parameters:{type:'object',additionalProperties:true}}}))})});
    if (!response.ok) return json({error:'ai_provider_unavailable',fallback:'Use search and booking screens directly'},503);
    const result=await response.json();
    const calls=Array.isArray(result.tool_calls)?result.tool_calls:[];
    const executed=[];
    for (const call of calls.slice(0,4)) {
      const name=call?.function?.name; let args={};
      try { args=JSON.parse(call?.function?.arguments ?? '{}'); } catch { executed.push({tool:name,error:'invalid_tool_arguments'}); continue; }
      executed.push({tool:name,result:await executeTool(db,user.id,name,args)});
    }
    console.log(JSON.stringify({event:'ai_booking',user_id:user.id,tools:executed.map(x=>x.tool)}));
    return json({reply:typeof result.reply==='string'?result.reply:'',tools:executed,requires_confirmation:executed.some(x=>(x.result as Record<string,unknown>)?.requires_confirmation===true)});
  } catch { return json({error:'invalid_request'},400); }
});
