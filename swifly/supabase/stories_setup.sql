-- Run once in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Safe to run more than once. Run AFTER user_settings.sql.

-- 1. Who has watched which story (drives the grey "seen" ring)
create table if not exists public.story_views (
  story_id   uuid not null references public.stories(id) on delete cascade,
  viewer_id  uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

alter table public.story_views enable row level security;

drop policy if exists "story_views_select" on public.story_views;
create policy "story_views_select" on public.story_views
  for select to authenticated
  using (
    viewer_id = auth.uid()
    or exists (select 1 from public.stories s where s.id = story_views.story_id and s.author_id = auth.uid())
  );

drop policy if exists "story_views_insert_own" on public.story_views;
create policy "story_views_insert_own" on public.story_views
  for insert to authenticated with check (viewer_id = auth.uid());

-- 2. Defaults so reactions and replies save without extra fields
alter table public.story_reactions alter column id set default gen_random_uuid();
alter table public.story_reactions alter column created_at set default now();
alter table public.story_replies alter column id set default gen_random_uuid();
alter table public.story_replies alter column created_at set default now();

-- 3. Stories table defaults
alter table public.stories alter column id set default gen_random_uuid();
alter table public.stories alter column created_at set default now();

-- 4. Users can upload only into their own folder in the "stories" bucket
drop policy if exists "stories bucket upload own folder" on storage.objects;
create policy "stories bucket upload own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'stories' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "stories bucket update own folder" on storage.objects;
create policy "stories bucket update own folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'stories' and (storage.foldername(name))[1] = auth.uid()::text);
