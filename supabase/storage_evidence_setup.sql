-- supabase/storage_evidence_setup.sql
-- Manual setup for quest_guide evidence storage.
--
-- Applies:
--   - bucket: quest-guide-for-tourists
--   - public preview compatibility with getPublicUrl
--   - upload/delete policies for path:
--       quest_evidence/{userId}/{questId}/{taskId}/{filename}
--
-- SECURITY NOTE:
-- Current Flutter client uploads with anon key and WITHOUT Supabase Auth session.
-- Therefore policy below must allow role "anon" to INSERT/DELETE inside this path.
-- This is a functional compromise: caller can spoof userId segment in path.

begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'quest-guide-for-tourists',
  'quest-guide-for-tourists',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Idempotent policy recreation.
drop policy if exists "qg_evidence_public_read" on storage.objects;
drop policy if exists "qg_evidence_anon_upload" on storage.objects;
drop policy if exists "qg_evidence_anon_delete" on storage.objects;
drop policy if exists "qg_admin_content_read" on storage.objects;
drop policy if exists "qg_admin_content_upload" on storage.objects;
drop policy if exists "qg_admin_content_delete" on storage.objects;

-- Public read (preview via getPublicUrl).
create policy "qg_evidence_public_read"
on storage.objects
for select
to public
using (
  bucket_id = 'quest-guide-for-tourists'
  and (storage.foldername(name))[1] = 'quest_evidence'
);

-- Working minimum for current app client (anon upload).
create policy "qg_evidence_anon_upload"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'quest-guide-for-tourists'
  and (storage.foldername(name))[1] = 'quest_evidence'
  and array_length(storage.foldername(name), 1) = 4
  and nullif((storage.foldername(name))[2], '') is not null
  and nullif((storage.foldername(name))[3], '') is not null
  and nullif((storage.foldername(name))[4], '') is not null
  and lower(storage.extension(name)) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

-- Working minimum for current app client (anon delete/retry flows).
create policy "qg_evidence_anon_delete"
on storage.objects
for delete
to anon, authenticated
using (
  bucket_id = 'quest-guide-for-tourists'
  and (storage.foldername(name))[1] = 'quest_evidence'
  and array_length(storage.foldername(name), 1) = 4
  and lower(storage.extension(name)) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

-- Admin content (visual quest editor):
-- quests/{filename}, locations/{filename}, tasks/{filename}
create policy "qg_admin_content_read"
on storage.objects
for select
to public
using (
  bucket_id = 'quest-guide-for-tourists'
  and (storage.foldername(name))[1] = any (array['quests', 'locations', 'tasks'])
);

create policy "qg_admin_content_upload"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'quest-guide-for-tourists'
  and (storage.foldername(name))[1] = any (array['quests', 'locations', 'tasks'])
  and array_length(storage.foldername(name), 1) = 1
  and lower(storage.extension(name)) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

create policy "qg_admin_content_delete"
on storage.objects
for delete
to anon, authenticated
using (
  bucket_id = 'quest-guide-for-tourists'
  and (storage.foldername(name))[1] = any (array['quests', 'locations', 'tasks'])
  and array_length(storage.foldername(name), 1) = 1
  and lower(storage.extension(name)) = any (array['jpg', 'jpeg', 'png', 'webp'])
);

commit;
