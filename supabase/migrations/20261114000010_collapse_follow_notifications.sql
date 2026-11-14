-- Swifs: one follow notification per person.
-- A follow, unfollow or re-follow used to add a new row each time, so the same person showed many
-- times. This removes the extra rows that already exist, then makes every new follow row replace the
-- older rows from the same person. Safe to run more than once.

-- 1. Remove the repeated follow rows that already exist (keeps the newest per person and kind).
delete from public.notifications a
using public.notifications b
where a.user_id = b.user_id
  and a.type = b.type
  and a.type like 'follow%'
  and lower(trim(both '@' from a.actor_handle)) = lower(trim(both '@' from b.actor_handle))
  and (a.created_at < b.created_at or (a.created_at = b.created_at and a.id < b.id));

-- 2. Before each new follow row is saved, delete the older rows from the same person.
create or replace function public.swifs_collapse_follow_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.type like 'follow%' then
    delete from public.notifications
    where user_id = new.user_id
      and type = new.type
      and lower(trim(both '@' from actor_handle)) = lower(trim(both '@' from new.actor_handle));
  end if;
  return new;
end;
$$;

drop trigger if exists swifs_collapse_follow on public.notifications;
create trigger swifs_collapse_follow
  before insert on public.notifications
  for each row execute function public.swifs_collapse_follow_notification();
