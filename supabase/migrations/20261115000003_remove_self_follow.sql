-- Swifs: remove self-follows and the notifications they created. Stop new ones.
-- Safe to run more than once.

-- 1. Notifications that say a person followed themselves.
delete from public.notifications n
where n.type = 'follow'
  and exists (
    select 1 from public.profiles p
    where p.id = n.user_id
      and lower(p.username) = lower(trim(both '@' from n.actor_handle))
  );

-- 2. The self-follow rows themselves.
delete from public.follows where follower = followee;

-- 3. The database refuses a self-follow from now on.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'follows_no_self') then
    alter table public.follows add constraint follows_no_self check (follower <> followee);
  end if;
end $$;
