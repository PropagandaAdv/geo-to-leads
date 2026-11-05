// Cifra il refresh token OAuth della casella commerciale@propagandaadv.com per agency_mailbox.token_cifrato.
// Uso (in locale, MAI in chat né nel repo):
//   AGENCY_MAILBOX_ENC_KEY='<stessa chiave dei Secrets>' deno run tools/encrypt-token.ts   (il token si digita/incolla su stdin)
// Poi in SQL (editor Lovable): insert into agency_mailbox (email, stato, token_cifrato) values ('commerciale@propagandaadv.com','collegata','<output>') on conflict (email) do update set stato='collegata', token_cifrato=excluded.token_cifrato, aggiornato_il=now();
import { cifra } from "../_shared/reminder.ts";
const key = Deno.env.get("AGENCY_MAILBOX_ENC_KEY");
if (!key) { console.error("Imposta AGENCY_MAILBOX_ENC_KEY"); Deno.exit(1); }
const token = (await new Response(Deno.stdin.readable).text()).trim();
if (!token) { console.error("Nessun token su stdin"); Deno.exit(1); }
console.log(await cifra(token, key));
