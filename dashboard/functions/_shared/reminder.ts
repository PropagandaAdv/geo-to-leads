// Logica pura di send-reminder: modello, calendario, email RFC 822, cifratura del token.
export type Frequenza = "mensile" | "quindicinale";

export function renderTemplate(t: string, vars: Record<string, string>): string {
  return t.replace(/\{\{\s*(\w+)\s*\}\}/g, (_m, k) => (k in vars ? vars[k] : `{{${k}}}`));
}

/** Prossimo invio: +1 mese di calendario (con il giorno limitato alla fine del mese) oppure +14 giorni. */
export function prossimoInvio(freq: Frequenza, da: Date): Date {
  const d = new Date(da.getTime());
  if (freq === "quindicinale") { d.setUTCDate(d.getUTCDate() + 14); return d; }
  const giorno = d.getUTCDate();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() + 1);
  const fine = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(giorno, fine));
  return d;
}

const b64 = (u: Uint8Array) => btoa(String.fromCharCode(...u));
const unb64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
export const b64url = (u: Uint8Array) => b64(u).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

function noCRLF(s: string, campo: string): string {
  if (/[\r\n]/.test(s)) throw new Error(`${campo} contiene a capo: possibile header injection`);
  return s;
}
const EMAIL_RE = /^[^\s@<>",;]+@[^\s@<>",;]+\.[^\s@<>",;]+$/;
export function assertEmail(e: string, campo: string): string {
  noCRLF(e, campo);
  if (!EMAIL_RE.test(e)) throw new Error(`${campo} non è un indirizzo valido`);
  return e;
}
const encHeader = (s: string) => (/^[\x20-\x7e]*$/.test(s) ? s : `=?UTF-8?B?${b64(new TextEncoder().encode(s))}?=`);

/** Costruisce il messaggio RFC 822 (testo semplice UTF-8, base64) e lo restituisce in base64url per l'API Gmail. */
export function buildRawEmail(o: { from: string; to: string; subject: string; text: string; listUnsubscribe?: string }): string {
  assertEmail(o.from, "mittente"); assertEmail(o.to, "destinatario"); noCRLF(o.subject, "oggetto");
  const body = b64(new TextEncoder().encode(o.text)).replace(/(.{76})/g, "$1\r\n");
  const h = [
    `From: ${o.from}`, `To: ${o.to}`, `Subject: ${encHeader(o.subject)}`, "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=UTF-8", "Content-Transfer-Encoding: base64",
  ];
  if (o.listUnsubscribe) h.push(`List-Unsubscribe: <${noCRLF(o.listUnsubscribe, "link disiscrizione")}>`);
  return b64url(new TextEncoder().encode(h.join("\r\n") + "\r\n\r\n" + body));
}

async function chiave(segreto: string): Promise<CryptoKey> {
  if (segreto.length < 16) throw new Error("AGENCY_MAILBOX_ENC_KEY troppo corta (minimo 16 caratteri)");
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(segreto));
  return crypto.subtle.importKey("raw", h, "AES-GCM", false, ["encrypt", "decrypt"]);
}
/** AES-GCM; formato: base64(iv[12] | ciphertext). */
export async function cifra(testo: string, segreto: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await chiave(segreto), new TextEncoder().encode(testo)));
  const out = new Uint8Array(12 + ct.length); out.set(iv); out.set(ct, 12);
  return b64(out);
}
export async function decifra(cifrato: string, segreto: string): Promise<string> {
  const raw = unb64(cifrato);
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv: raw.slice(0, 12) }, await chiave(segreto), raw.slice(12));
  return new TextDecoder().decode(pt);
}
