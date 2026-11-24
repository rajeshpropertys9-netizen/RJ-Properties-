-- RJ Properties CRM V8.8: private media for owner-linked properties
-- Additive migration only. Existing owner/property rows and buckets are preserved.
alter table public.owner_properties
  add column if not exists photo_paths text[] not null default '{}',
  add column if not exists cover_photo_path text,
  add column if not exists youtube_video_url text,
  add column if not exists instagram_video_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('rj-owner-property-media','rj-owner-property-media',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "RJ owner media admin read" on storage.objects;
create policy "RJ owner media admin read" on storage.objects for select to authenticated
using (bucket_id='rj-owner-property-media' and exists(select 1 from public.admin_users au where au.user_id=auth.uid()));
drop policy if exists "RJ owner media admin upload" on storage.objects;
create policy "RJ owner media admin upload" on storage.objects for insert to authenticated
with check (bucket_id='rj-owner-property-media' and exists(select 1 from public.admin_users au where au.user_id=auth.uid()));
drop policy if exists "RJ owner media admin update" on storage.objects;
create policy "RJ owner media admin update" on storage.objects for update to authenticated
using (bucket_id='rj-owner-property-media' and exists(select 1 from public.admin_users au where au.user_id=auth.uid()))
with check (bucket_id='rj-owner-property-media' and exists(select 1 from public.admin_users au where au.user_id=auth.uid()));
drop policy if exists "RJ owner media admin delete" on storage.objects;
create policy "RJ owner media admin delete" on storage.objects for delete to authenticated
using (bucket_id='rj-owner-property-media' and exists(select 1 from public.admin_users au where au.user_id=auth.uid()));
