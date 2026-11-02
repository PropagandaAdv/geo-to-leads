Crea un'app web in italiano chiamata "Portale Clienti", multi-tenant, mobile-friendly, con Lovable Cloud (Supabase) per Auth, Database, Realtime, Storage ed Edge Functions.
- Login con email e password (e magic link). Nessuna registrazione libera: gli utenti sono invitati dall'agenzia.
- Dopo il login, leggi `agency_admins` e `client_users`: l'utente vede solo i dati del proprio cliente; `agency_admin` vede un selettore cliente.
- Layout con sidebar: Panoramica, Aziende, Email, Appuntamenti, Integrazioni, Report, Admin (solo agency_admin). Branding dal record `clients.branding` (logo_url, colore, nome_visualizzato). Tono caldo, testi in italiano, stile pulito e professionale.
- Non esporre mai token o chiavi nel frontend. Non creare tabelle: lo schema arriva nel prompt 02.
