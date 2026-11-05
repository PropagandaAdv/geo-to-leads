// Validazione del payload di visibilità (stessa regola di scripts/sync_dashboard.py): ogni dato ha fonte e data, niente valori inventati.
export const PROVIDER_IA = ["openai", "gemini", "google_aio", "perplexity", "altro"] as const;
export class ValidationError extends Error {}

const DATA_RE = /^\d{4}-\d{2}-\d{2}$/;
const need = (r: any, keys: string[], tab: string) => {
  for (const k of keys) if (r?.[k] === undefined || r?.[k] === null || r?.[k] === "") throw new ValidationError(`${tab}: campo '${k}' mancante (ogni dato richiede fonte e data)`);
};
const data = (v: string, tab: string) => { if (!DATA_RE.test(v) || isNaN(Date.parse(v))) throw new ValidationError(`${tab}: data non valida '${v}' (AAAA-MM-GG)`); };
const numOrNull = (v: unknown, tab: string, campo: string, min = -Infinity, max = Infinity) => {
  if (v === undefined || v === null) return null;
  if (typeof v !== "number" || !Number.isFinite(v) || v < min || v > max) throw new ValidationError(`${tab}: '${campo}' deve essere un numero tra ${min} e ${max}`);
  return v;
};

export function validaVisibilita(clientId: string, d: any) {
  if (!d || typeof d !== "object") throw new ValidationError("payload non valido");
  const arr = (k: string) => (d[k] === undefined ? [] : Array.isArray(d[k]) ? d[k] : (() => { throw new ValidationError(`${k} deve essere un array`); })());
  const tot = ["rankings", "ai_snapshots", "citations", "traffic"].reduce((n, k) => n + arr(k).length, 0);
  if (tot === 0) throw new ValidationError("payload vuoto");
  if (tot > 5000) throw new ValidationError("payload troppo grande (max 5000 righe)");

  const rankings = arr("rankings").map((r: any) => {
    need(r, ["keyword", "rilevato_il", "fonte"], "rankings"); data(r.rilevato_il, "rankings");
    return { client_id: clientId, keyword: String(r.keyword).slice(0, 300), url: r.url ?? null, posizione: numOrNull(r.posizione, "rankings", "posizione", 1, 1000),
      volume: numOrNull(r.volume, "rankings", "volume", 0), difficolta: numOrNull(r.difficolta, "rankings", "difficolta", 0, 100),
      lingua: r.lingua ?? "it", paese: r.paese ?? "IT", rilevato_il: r.rilevato_il, fonte: String(r.fonte).slice(0, 200) };
  });
  const snapshots = arr("ai_snapshots").map((r: any) => {
    need(r, ["provider", "rilevato_il", "fonte"], "ai_snapshots"); data(r.rilevato_il, "ai_snapshots");
    if (!PROVIDER_IA.includes(r.provider)) throw new ValidationError(`ai_snapshots: provider non valido '${r.provider}'`);
    return { client_id: clientId, provider: r.provider, visibilita_pct: numOrNull(r.visibilita_pct, "ai_snapshots", "visibilita_pct", 0, 100),
      rank_medio: numOrNull(r.rank_medio, "ai_snapshots", "rank_medio", 0), share_of_voice: numOrNull(r.share_of_voice, "ai_snapshots", "share_of_voice", 0),
      menzioni: numOrNull(r.menzioni, "ai_snapshots", "menzioni", 0), sentiment: numOrNull(r.sentiment, "ai_snapshots", "sentiment"),
      rilevato_il: r.rilevato_il, fonte: String(r.fonte).slice(0, 200) };
  });
  const citations = arr("citations").map((r: any) => {
    need(r, ["provider", "prompt", "rilevato_il", "fonte"], "citations"); data(r.rilevato_il, "citations");
    if (!PROVIDER_IA.includes(r.provider)) throw new ValidationError(`citations: provider non valido '${r.provider}'`);
    return { client_id: clientId, provider: r.provider, prompt: String(r.prompt).slice(0, 500), url_citato: r.url_citato ?? null, dominio: r.dominio ?? null,
      cita_cliente: r.cita_cliente === true, competitor: r.competitor ?? null, rilevato_il: r.rilevato_il, fonte: String(r.fonte).slice(0, 200) };
  });
  const traffic = arr("traffic").map((r: any) => {
    need(r, ["mese", "fonte"], "traffic"); data(r.mese, "traffic");
    if (!String(r.mese).endsWith("-01")) throw new ValidationError(`traffic: 'mese' deve essere il primo del mese (AAAA-MM-01): ${r.mese}`);
    return { client_id: clientId, mese: r.mese, traffico_organico: numOrNull(r.traffico_organico, "traffic", "traffico_organico", 0),
      keyword_organiche: numOrNull(r.keyword_organiche, "traffic", "keyword_organiche", 0), domain_authority: numOrNull(r.domain_authority, "traffic", "domain_authority", 0, 100),
      backlink: numOrNull(r.backlink, "traffic", "backlink", 0), domini_referenti: numOrNull(r.domini_referenti, "traffic", "domini_referenti", 0), fonte: String(r.fonte).slice(0, 200) };
  });
  return { rankings, snapshots, citations, traffic };
}
