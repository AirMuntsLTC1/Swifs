-- Run once in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Safe to run more than once. Run after the other setup files.

-- 1. Columns for read receipts and story replies
alter table public.messages add column if not exists read_at timestamptz;
alter table public.messages add column if not exists story_id uuid references public.stories(id) on delete set null;

-- 2. Defaults so new messages save without extra fields
alter table public.messages alter column id set default gen_random_uuid();
alter table public.messages alter column created_at set default now();

-- 3. Policies: read your own conversations, send as yourself, unsend your own, mark incoming as read
alter table public.messages enable row level security;

drop policy if exists "messages read" on public.messages;
create policy "messages read" on public.messages
  for select to authenticated
  using (sender = auth.uid() or recipient = auth.uid());

drop policy if exists "messages insert own" on public.messages;
create policy "messages insert own" on public.messages
  for insert to authenticated
  with check (sender = auth.uid());

drop policy if exists "messages delete own" on public.messages;
create policy "messages delete own" on public.messages
  for delete to authenticated
  using (sender = auth.uid());

drop policy if exists "messages mark read" on public.messages;
create policy "messages mark read" on public.messages
  for update to authenticated
  using (recipient = auth.uid())
  with check (recipient = auth.uid());

-- 4. Notes: one row per user, the app replaces it; followers can read it (already in place)
alter table public.notes enable row level security;

-- 5. Faster inbox and thread queries
create index if not exists messages_sender_created_idx on public.messages (sender, created_at desc);
create index if not exists messages_recipient_created_idx on public.messages (recipient, created_at desc);
create index if not exists messages_unread_idx on public.messages (recipient) where read_at is null;

-- 6. Live updates: make sure the tables are in the realtime publication
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
