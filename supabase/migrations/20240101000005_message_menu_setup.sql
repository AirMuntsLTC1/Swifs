-- Run once in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Safe to run more than once. Run after messages_setup.sql.

-- 1. Pinned messages
alter table public.messages add column if not exists pinned_at timestamptz;

-- 2. Emoji reactions on a message (one per person per emoji)
create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  emoji      text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

alter table public.message_reactions enable row level security;

drop policy if exists "reactions read in my chats" on public.message_reactions;
create policy "reactions read in my chats" on public.message_reactions
  for select to authenticated
  using (exists (
    select 1 from public.messages m
    where m.id = message_reactions.message_id
      and (m.sender = auth.uid() or m.recipient = auth.uid())
  ));

drop policy if exists "reactions insert own" on public.message_reactions;
create policy "reactions insert own" on public.message_reactions
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "reactions delete own" on public.message_reactions;
create policy "reactions delete own" on public.message_reactions
  for delete to authenticated
  using (user_id = auth.uid());

-- 3. Delete for you: hides a message for one person only
create table if not exists public.message_hidden (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.message_hidden enable row level security;

drop policy if exists "hidden own" on public.message_hidden;
create policy "hidden own" on public.message_hidden
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 4. Reports of messages
create table if not exists public.message_reports (
  id         uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  reporter   uuid not null references auth.users(id) on delete cascade,
  reason     text not null default 'Other',
  created_at timestamptz not null default now()
);

alter table public.message_reports enable row level security;

drop policy if exists "reports insert own" on public.message_reports;
create policy "reports insert own" on public.message_reports
  for insert to authenticated
  with check (reporter = auth.uid());

drop policy if exists "reports read own" on public.message_reports;
create policy "reports read own" on public.message_reports
  for select to authenticated
  using (reporter = auth.uid());

-- 5. Live updates for reactions and pins
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'message_reactions') then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end $$;

-- 6. Pinning works for either person in the chat (only pinned_at can change through the app)
drop policy if exists "messages pin in my chats" on public.messages;
create policy "messages pin in my chats" on public.messages
  for update to authenticated
  using (sender = auth.uid() or recipient = auth.uid())
  with check (sender = auth.uid() or recipient = auth.uid());
