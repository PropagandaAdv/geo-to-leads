// evaluate-icp — valuta se le aziende rientrano nell'ICP (testo libero) della versione ATTIVA del profilo Outreach.
// POST { client_id, company_ids?: uuid[], force?: boolean, use_website?: boolean }
// Auth: service role (plugin/cron) OPPURE utente con ruolo client_owner/agency_admin sul cliente.
// Secrets: ANTHROPIC_API_KEY (obbligatorio), ANTHROPIC_MODEL (default claude-sonnet-5-5). SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY sono forniti dalla piattaforma.
import { createClient } from "npm:@supabase/supabase-js@2";
import { bearer, json, timingSafeEqual, UUID_RE } from "../_shared/auth.ts";
import { buildPrompts, dominioPubblico, htmlToText, sanificaValutazione, TOOL } from "../_shared/icp.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5";
const MAX_BATCH = 20;   // tetto per chiamata: controlla il consumo di Claude
const CONCURRENCY = 3;

const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

async function autorizzato(req: Request, clientId: string): Promise<boolean> {
  const tok = bearer(req);
  if (!tok) return false;
  if (timingSafeEqual(tok, SERVICE_KEY)) return true;
  const user = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: `Bearer ${tok}` } }, auth: { persistSession: false },
  });
  const { data, error } = await user.rpc("is_client_owner", { cid: clientId });
  return !error && data === true;
}

// Lettura limitata di una pagina pubblica. Un solo redirect, solo verso lo stesso dominio (o www.).
async function leggiSito(dominio: string): Promise<string | null> {
  try {
    let url = `https://${dominio}/`;
    for (let hop = 0; hop < 2; hop++) {
      const res = await fetch(url, { redirect: "manual", signal: AbortSignal.timeout(8000), headers: { "user-agent": "Mozilla/5.0 (compatible; GEO-Growth-Engine ICP check)" } });
      if (res.status >= 300 && res.status < 400) {
        const loc = res.headers.get("location");
        if (!loc) return null;
        const u = new URL(loc, url);
        const h = u.hostname.replace(/^www\./, "");
        if (u.protocol !== "https:" || h !== dominio.replace(/^www\./, "")) return null;
        url = u.toString();
        continue;
      }
      if (!res.ok || !(res.headers.get("content-type") ?? "").includes("text/html")) return null;
      const reader = res.body?.getReader();
      if (!reader) return null;
      let bytes = 0; const parts: Uint8Array[] = [];
      while (bytes < 400_000) { const { done, value } = await reader.read(); if (done || !value) break; parts.push(value); bytes += value.length; }
      await reader.cancel().catch(() => {});
      const all = new Uint8Array(bytes); let o = 0; for (const p of parts) { all.set(p, o); o += p.length; }
      return htmlToText(new TextDecoder().decode(all));
    }
  } catch { /* sito non raggiungibile: si valuta senza */ }
  return null;
}

async function chiediAClaude(system: string, user: string) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: MODEL, max_tokens: 1024, system, tools: [TOOL], tool_choice: { type: "tool", name: TOOL.name }, messages: [{ role: "user", content: user }] }),
    signal: AbortSignal.timeout(60_000),
  });
  if (!res.ok) throw new Error(`Anthropic HTTP ${res.status}`);
  const j = await res.json();
  return j.content?.find((b: any) => b.type === "tool_use" && b.name === TOOL.name)?.input ?? null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ errore: "usa POST" }, 405);
  if (!ANTHROPIC_KEY) return json({ errore: "ANTHROPIC_API_KEY non impostata nei Secrets" }, 500);
  let body: any;
  try { body = await req.json(); } catch { return json({ errore: "JSON non valido" }, 400); }
  const clientId = body?.client_id;
  if (typeof clientId !== "string" || !UUID_RE.test(clientId)) return json({ errore: "client_id non valido" }, 400);
  if (!(await autorizzato(req, clientId))) return json({ errore: "non autorizzato" }, 403);

  const { data: profilo } = await admin.from("v_outreach_attivo").select("id, versione, icp_prompt, offerta").eq("client_id", clientId).maybeSingle();
  if (!profilo) return json({ errore: "nessun profilo Outreach attivo: l'ICP lo definisce il titolare nelle Impostazioni Outreach" }, 409);

  let q = admin.from("companies").select("id, nome, dominio, settore, dimensione, paese").eq("client_id", clientId).order("ultima_visita", { ascending: false, nullsFirst: false });
  if (Array.isArray(body.company_ids)) {
    const ids = body.company_ids.filter((x: unknown) => typeof x === "string" && UUID_RE.test(x));
    if (!ids.length) return json({ errore: "company_ids non valido" }, 400);
    q = q.in("id", ids);
  }
  const { data: aziende, error: eAz } = await q;
  if (eAz) return json({ errore: "lettura aziende fallita" }, 500);
  const { data: fatte } = await admin.from("icp_evaluations").select("company_id").eq("profile_id", profilo.id);
  const giaFatte = new Set((fatte ?? []).map((e: any) => e.company_id));
  const daFare = (aziende ?? []).filter((a: any) => body.force === true || !giaFatte.has(a.id)).slice(0, MAX_BATCH);

  const oggi = new Date().toISOString().slice(0, 10);
  const conteggi: Record<string, number> = { in_target: 0, fuori_target: 0, da_verificare: 0 };
  const errori: { company_id: string; errore: string }[] = [];
  let declassate = 0;

  const lavora = async (az: any) => {
    try {
      const dom = dominioPubblico(az.dominio);
      const sito = body.use_website === true && dom ? await leggiSito(dom) : null;
      const { system, user } = buildPrompts(profilo, az, sito, oggi);
      const raw = await chiediAClaude(system, user);
      const v = sanificaValutazione(raw, sito ? ["dashboard", "sito"] : ["dashboard"], oggi);
      if (v.declassata) declassate++;
      // upsert: aggiorna solo le colonne inviate, quindi gli override del titolare restano intatti
      const { error } = await admin.from("icp_evaluations").upsert(
        { client_id: clientId, company_id: az.id, profile_id: profilo.id, stato: v.stato, motivazione: v.motivazione, evidenze: v.evidenze },
        { onConflict: "company_id,profile_id" });
      if (error) throw new Error("scrittura fallita");
      conteggi[v.stato]++;
    } catch (e) {
      errori.push({ company_id: az.id, errore: e instanceof Error ? e.message.slice(0, 200) : "errore" });
    }
  };
  const coda = [...daFare];
  await Promise.all(Array.from({ length: CONCURRENCY }, async () => { for (let a = coda.shift(); a; a = coda.shift()) await lavora(a); }));

  await admin.from("audit_log").insert({ client_id: clientId, azione: "icp_valutazione", entita: "icp_evaluations",
    dettagli: { profilo_versione: profilo.versione, modello: MODEL, valutate: daFare.length - errori.length, conteggi, declassate, errori: errori.length, use_website: body.use_website === true } });
  return json({ profilo_versione: profilo.versione, valutate: daFare.length - errori.length, conteggi, declassate, errori,
    rimanenti: Math.max(0, (aziende ?? []).filter((a: any) => body.force === true || !giaFatte.has(a.id)).length - daFare.length) });
});
