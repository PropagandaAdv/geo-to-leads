// sync-visibility — riceve le rilevazioni di visibilità (posizionamento, visibilità IA, citazioni, storico mensile) e le scrive nel database.
// POST { client_slug, rankings?, ai_snapshots?, citations?, traffic? }  (stesso formato di visibilita.json del comando /geo-visibilita)
// Auth: header x-ingest-secret (Secret INGEST_SECRET) oppure service role. NON interroga Ubersuggest: non esiste una chiave API
// utilizzabile da una edge function (solo MCP con OAuth); le rilevazioni le esegue il plugin (/geo-visibilita) o un task programmato.
import { createClient } from "npm:@supabase/supabase-js@2";
import { bearer, json, timingSafeEqual } from "../_shared/auth.ts";
import { validaVisibilita, ValidationError } from "../_shared/visibility.ts";

const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(Deno.env.get("SUPABASE_URL")!, SERVICE_KEY, { auth: { persistSession: false } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ errore: "usa POST" }, 405);
  const ingest = Deno.env.get("INGEST_SECRET");
  const okSecret = !!ingest && timingSafeEqual(req.headers.get("x-ingest-secret") ?? "", ingest);
  const okService = !!bearer(req) && timingSafeEqual(bearer(req), SERVICE_KEY);
  if (!okSecret && !okService) return json({ errore: "non autorizzato" }, 403);

  let body: any;
  try { body = await req.json(); } catch { return json({ errore: "JSON non valido" }, 400); }
  const slug = body?.client_slug;
  if (typeof slug !== "string" || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug)) return json({ errore: "client_slug non valido" }, 400);
  const { data: cl } = await admin.from("clients").select("id").eq("slug", slug).maybeSingle();
  if (!cl) return json({ errore: `cliente '${slug}' non presente nella dashboard` }, 404);

  let v;
  try { v = validaVisibilita(cl.id, body); }
  catch (e) { return json({ errore: e instanceof ValidationError ? e.message : "payload non valido" }, 422); }

  const scritte: Record<string, number> = {};
  const up = async (tab: string, rows: any[], conflict: string) => {
    if (!rows.length) return;
    const { error } = await admin.from(tab).upsert(rows, { onConflict: conflict });
    if (error) throw new Error(`${tab}: scrittura fallita`);
    scritte[tab] = rows.length;
  };
  try {
    await up("keyword_rankings", v.rankings, "client_id,keyword,lingua,paese,rilevato_il");
    await up("ai_visibility_snapshots", v.snapshots, "client_id,provider,rilevato_il");
    await up("traffic_history", v.traffic, "client_id,mese");
    if (v.citations.length) {   // nessuna chiave naturale: si sostituisce la rilevazione dello stesso giorno e provider
      for (const k of new Set(v.citations.map((c) => `${c.provider}|${c.rilevato_il}`))) {
        const [provider, giorno] = k.split("|");
        const { error } = await admin.from("ai_citations").delete().eq("client_id", cl.id).eq("provider", provider).eq("rilevato_il", giorno);
        if (error) throw new Error("ai_citations: pulizia fallita");
      }
      const { error } = await admin.from("ai_citations").insert(v.citations);
      if (error) throw new Error("ai_citations: scrittura fallita");
      scritte.ai_citations = v.citations.length;
    }
  } catch (e) { return json({ errore: e instanceof Error ? e.message : "errore", scritte }, 500); }

  await admin.from("audit_log").insert({ client_id: cl.id, azione: "visibilita_sync", entita: "visibilita", dettagli: scritte });
  return json({ ok: true, scritte });
});
