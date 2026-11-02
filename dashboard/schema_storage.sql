-- Solo Supabase/Lovable Cloud (usa lo schema `storage`). Applicare dopo schema.sql. Già applicato sul progetto d0718620-….
insert into storage.buckets (id, name, public) values ('reports', 'reports', false) on conflict (id) do nothing;
create policy reports_bucket_read on storage.objects for select to authenticated
  using (bucket_id = 'reports' and public.has_client_access(nullif(split_part(name, '/', 1), '')::uuid));
