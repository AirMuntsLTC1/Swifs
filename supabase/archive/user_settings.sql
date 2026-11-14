-- Run this once in the Supabase dashboard: SQL Editor -> New query -> Run.
-- Creates the tables that the Settings and activity screen saves to.
-- Safe to run more than once.

-- 1. One settings row per user
create table if not exists public.user_settings (
  user_id                uuid primary key references auth.users(id) on delete cascade,
  account_privacy        text    not null default 'Public'   check (account_privacy in ('Public', 'Private')),
  friends_feed_activity  boolean not null default true,
  messages_audience      text    not null default 'Everyone' check (messages_audience in ('Everyone', 'Followers', 'Off')),
  tags_audience          text    not null default 'Everyone' check (tags_audience in ('Everyone', 'Followers', 'Off')),
  comments_audience      text    not null default 'Everyone' check (comments_audience in ('Everyone', 'Followers', 'Off')),
  sharing_reuse          boolean not null default true,
  limit_interactions     text    not null default 'Off'      check (limit_interactions in ('Off', 'On')),
  hidden_words           boolean not null default true,
  push_notifications     boolean not null default true,
  like_notifications     boolean not null default true,
  comment_notifications  boolean not null default true,
  follow_notifications   boolean not null default true,
  updated_at             timestamptz not null default now()
);

alter table public.user_settings enable row level security;

drop policy if exists "user_settings_select_own" on public.user_settings;
create policy "user_settings_select_own" on public.user_settings
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "user_settings_insert_own" on public.user_settings;
create policy "user_settings_insert_own" on public.user_settings
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "user_settings_update_own" on public.user_settings;
create policy "user_settings_update_own" on public.user_settings
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2. Accounts a user has blocked
create table if not exists public.blocked_users (
  blocker    uuid not null references auth.users(id) on delete cascade,
  blocked    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create index if not exists blocked_users_blocker_idx on public.blocked_users (blocker);

alter table public.blocked_users enable row level security;

drop policy if exists "blocked_users_select_own" on public.blocked_users;
create policy "blocked_users_select_own" on public.blocked_users
  for select to authenticated using (auth.uid() = blocker);

drop policy if exists "blocked_users_insert_own" on public.blocked_users;
create policy "blocked_users_insert_own" on public.blocked_users
  for insert to authenticated with check (auth.uid() = blocker);

drop policy if exists "blocked_users_delete_own" on public.blocked_users;
create policy "blocked_users_delete_own" on public.blocked_users
  for delete to authenticated using (auth.uid() = blocker);
