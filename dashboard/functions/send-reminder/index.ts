// send-reminder — promemoria periodico ai clienti: "guarda la tua dashboard". UNICO invio automatico del sistema.
// Chiamata da cron giornaliero con header x-cron-secret. POST opzionale { dry_run?: boolean, client_id?: uuid }.
// Parte solo se: reminder_settings.attivo, testo_approvato_il valorizzato, prossimo_invio nullo o scaduto, casella dell'agenzia collegata.
// Secrets: CRON_SECRET, AGENCY_MAILBOX_ENC_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, APP_URL (es. https://portale-clienti-pro.lovable.app)
// Il token OAuth (refresh token) di commerciale@propagandaadv.com è in agency_mailbox.token_cifrato (vedi tools/encrypt-token.ts).
import { createClient } from "npm:@supabase/supabase-js@2";
import { json, timingSafeEqual, UUID_RE } from "../_shared/auth.ts";
import { assertEmail, buildRawEmail, decifra, prossimoInvio, renderTemplate, type Frequenza } from "../_shared/reminder.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const MAX_DESTINATARI = 50;

async function accessToken(mittente: string): Promise<string> {
  const { data: mb } = await admin.from("agency_mailbox").select("stato, token_cifrato").eq("email", mittente).maybeSingle();
  if (!mb || mb.stato !== "collegata" || !mb.token_cifrato) throw new Error(`casella ${mittente} non collegata`);
  const refresh = await decifra(mb.token_cifrato, Deno.env.get("AGENCY_MAILBOX_ENC_KEY")!);
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, signal: AbortSignal.timeout(15_000),
    body: new URLSearchParams({ client_id: Deno.env.get("GOOGLE_CLIENT_ID")!, client_secret: Deno.env.get("GOOGLE_CLIENT_SECRET")!, refresh_token: refresh, grant_type: "refresh_token" }),
  });
  if (!r.ok) {
    if (r.status === 400 || r.status === 401) await admin.from("agency_mailbox").update({ stato: "scaduta", aggiornato_il: new Date().toISOString() }).eq("email", mittente);
    throw new Error(`rinnovo token Google fallito (HTTP ${r.status})`);
  }
  return (await r.json()).access_token;
}

async function inviaGmail(token: string, raw: string) {
  const r = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/messages/send", {
    method: "POST", headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" }, body: JSON.stringify({ raw }), signal: AbortSignal.timeout(20_000),
  });
  if (!r.ok) throw new Error(`Gmail HTTP ${r.status}`);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ errore: "usa POST" }, 405);
  const secret = Deno.env.get("CRON_SECRET");
  if (!secret || !timingSafeEqual(req.headers.get("x-cron-secret") ?? "", secret)) return json({ errore: "non autorizzato" }, 403);
  let body: any = {};
  try { body = await req.json(); } catch { /* corpo opzionale */ }
  const dry = body?.dry_run === true;
  const appUrl = (Deno.env.get("APP_URL") ?? "").replace(/\/$/, "");
  if (!appUrl.startsWith("https://")) return json({ errore: "APP_URL non impostata (https://…)" }, 500);

  const adesso = new Date();
  let q = admin.from("reminder_settings").select("client_id, frequenza, mittente, oggetto, corpo, prossimo_invio")
    .eq("attivo", true).not("testo_approvato_il", "is", null)
    .or(`prossimo_invio.is.null,prossimo_invio.lte.${adesso.toISOString()}`);
  if (typeof body?.client_id === "string" && UUID_RE.test(body.client_id)) q = q.eq("client_id", body.client_id);
  const { data: dovuti, error } = await q;
  if (error) return json({ errore: "lettura impostazioni fallita" }, 500);

  const esiti: unknown[] = [];
  for (const s of dovuti ?? []) {
    const log = async (esito: "inviato" | "errore" | "saltato", destinatari: number, errore?: string) => {
      if (!dry) await admin.from("reminder_log").insert({ client_id: s.client_id, destinatari, esito, errore: errore?.slice(0, 300) ?? null });
      esiti.push({ client_id: s.client_id, esito, destinatari, errore });
    };
    try {
      // "prenotazione" ottimistica: evita doppi invii se due esecuzioni si sovrappongono (riprova domani in caso di errore)
      if (!dry) {
        const dom = new Date(adesso.getTime() + 24 * 3600 * 1000).toISOString();
        const { data: preso } = await admin.from("reminder_settings").update({ prossimo_invio: dom })
          .eq("client_id", s.client_id).or(`prossimo_invio.is.null,prossimo_invio.lte.${adesso.toISOString()}`).select("client_id");
        if (!preso?.length) continue;
      }
      const { data: utenti } = await admin.from("client_users").select("user_id").eq("client_id", s.client_id);
      const { data: prefs } = await admin.from("user_prefs").select("user_id, notifiche_promemoria").eq("client_id", s.client_id);
      const no = new Set((prefs ?? []).filter((p: any) => p.notifiche_promemoria === false).map((p: any) => p.user_id));
      const emails: string[] = [];
      for (const u of (utenti ?? []).filter((u: any) => !no.has(u.user_id)).slice(0, MAX_DESTINATARI)) {
        const { data } = await admin.auth.admin.getUserById(u.user_id);
        const e = data?.user?.email;
        if (e) { try { emails.push(assertEmail(e, "destinatario")); } catch { /* indirizzo non valido: saltato */ } }
      }
      if (!emails.length) { await log("saltato", 0, "nessun destinatario (utenti assenti o notifiche disattivate)"); continue; }
      if (dry) { esiti.push({ client_id: s.client_id, esito: "dry_run", destinatari: emails.length }); continue; }

      const vars = { link: appUrl, link_notifiche: `${appUrl}/impostazioni/notifiche` };
      const oggetto = renderTemplate(s.oggetto, vars), testo = renderTemplate(s.corpo, vars) + `\n\nPer non ricevere più questo promemoria: ${vars.link_notifiche}`;
      const token = await accessToken(s.mittente);
      let ok = 0, ultimoErrore = "";
      for (const to of emails) {   // un messaggio per destinatario: nessun indirizzo esposto agli altri
        try { await inviaGmail(token, buildRawEmail({ from: s.mittente, to, subject: oggetto, text: testo, listUnsubscribe: vars.link_notifiche })); ok++; }
        catch (e) { ultimoErrore = e instanceof Error ? e.message : "errore"; }
      }
      if (ok > 0) {
        await admin.from("reminder_settings").update({ ultimo_invio: adesso.toISOString(), prossimo_invio: prossimoInvio(s.frequenza as Frequenza, adesso).toISOString() }).eq("client_id", s.client_id);
        await log("inviato", ok, ok < emails.length ? `parziale: ${ok}/${emails.length}; ${ultimoErrore}` : undefined);
      } else await log("errore", 0, ultimoErrore);
    } catch (e) {
      await log("errore", 0, e instanceof Error ? e.message : "errore");
    }
  }
  return json({ dry_run: dry, clienti_dovuti: dovuti?.length ?? 0, esiti });
});
