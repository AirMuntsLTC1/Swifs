-- Device tokens for Firebase push. Each row is one phone.
create table if not exists public.user_devices (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

create index if not exists user_devices_user_idx on public.user_devices (user_id);

alter table public.user_devices enable row level security;

drop policy if exists swifs_devices_read_own on public.user_devices;
create policy swifs_devices_read_own on public.user_devices
  for select to authenticated using (user_id = auth.uid());

drop policy if exists swifs_devices_delete_own on public.user_devices;
create policy swifs_devices_delete_own on public.user_devices
  for delete to authenticated using (user_id = auth.uid());

-- No insert or update policy: tokens are written only through register_device().

-- Saves a token for the signed-in user. A phone that changes account is moved to the new user.
create or replace function public.register_device(p_token text, p_platform text default 'android')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'Not signed in'; end if;
  if p_token is null or length(p_token) < 20 then raise exception 'Invalid token'; end if;

  insert into public.user_devices (token, user_id, platform, updated_at)
  values (p_token, me, coalesce(p_platform, 'android'), now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

grant execute on function public.register_device(text, text) to authenticated;
