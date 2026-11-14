-- Adds the restricted_users table
create table if not exists public.restricted_users (
  restrictor uuid not null references auth.users(id) on delete cascade,
  restricted uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (restrictor, restricted)
);

alter table public.restricted_users enable row level security;

drop policy if exists "restricted_users_select_own" on public.restricted_users;
create policy "restricted_users_select_own" on public.restricted_users
  for select to authenticated using (auth.uid() = restrictor);

drop policy if exists "restricted_users_insert_own" on public.restricted_users;
create policy "restricted_users_insert_own" on public.restricted_users
  for insert to authenticated with check (auth.uid() = restrictor);
