-- Swifs: nobody gets a notification about their own actions. Safe to run more than once.

-- 1. Remove notifications that were made for your own actions (actor is the recipient).
delete from public.notifications n
where exists (
  select 1 from public.profiles p
  where p.id = n.user_id
    and lower(p.username) = lower(trim(both '@' from n.actor_handle))
);

-- 2. Refuse any new one. This covers every type (like, comment, story reaction, message, follow).
create or replace function public.swifs_skip_self_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.profiles p
    where p.id = new.user_id
      and lower(p.username) = lower(trim(both '@' from new.actor_handle))
  ) then
    return null;  -- returning null cancels the insert
  end if;
  return new;
end;
$$;

drop trigger if exists swifs_skip_self_notification on public.notifications;
create trigger swifs_skip_self_notification
  before insert on public.notifications
  for each row execute function public.swifs_skip_self_notification();
