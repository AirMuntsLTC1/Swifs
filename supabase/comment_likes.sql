-- Adds the table that stores likes on comments (your database has no comment likes table yet).
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run.

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.comment_likes enable row level security;

drop policy if exists "comment likes read" on public.comment_likes;
create policy "comment likes read" on public.comment_likes
  for select to authenticated using (true);

drop policy if exists "comment likes insert own" on public.comment_likes;
create policy "comment likes insert own" on public.comment_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "comment likes delete own" on public.comment_likes;
create policy "comment likes delete own" on public.comment_likes
  for delete to authenticated using (user_id = auth.uid());


