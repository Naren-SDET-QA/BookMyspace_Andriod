// Authenticated adapter over the Phase 7 application tools. This endpoint
// intentionally contains no database access or booking logic.
const url = Deno.env.get('SUPABASE_URL')!;
const headers = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...headers,'Content-Type':'application/json'}});
const allowed=new Set(['search_facilities','resolve_capabilities','check_availability','retrieve_pricing','prepare_booking_intent','create_booking']);
Deno.serve(async req=>{
 if(req.method==='OPTIONS') return json({ok:true});
 const auth=req.headers.get('Authorization'); if(!auth) return json({error:'missing_auth'},401);
 try {
  const body=await req.json();
  if(typeof body?.tool!=='string'||!allowed.has(body.tool)||!body.args||typeof body.args!=='object') return json({error:'invalid_tool_request'},400);
  const upstream=await fetch(`${url}/functions/v1/ai-booking-assistant`,{method:'POST',headers:{'Authorization':auth,'Content-Type':'application/json'},body:JSON.stringify({tool:body.tool,args:body.args})});
  const result=await upstream.json();
  return json(result,upstream.status);
 } catch { return json({error:'invalid_request'},400); }
});
