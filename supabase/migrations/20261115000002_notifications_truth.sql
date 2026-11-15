-- Swifs: notifications show only what really happened.
-- Safe to run more than once.

-- 1. Remove the older notification triggers on follows and messages. Only triggers whose
--    function writes to notifications are removed. The follower-count trigger is kept.
do $$
declare r record;
begin
  for r in
    select t.tgname, c.relname
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'public'
      and c.relname in ('follows', 'messages')
      and not t.tgisinternal
      and p.prosrc ilike '%notifications%'
  loop
    execute format('drop trigger if exists %I on public.%I', r.tgname, r.relname);
  end loop;
end $$;

-- 2. A follow row creates one follow notification for the person who was followed.
create or replace function public.swifs_follow_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor record;
begin
  if new.follower = new.followee then
    return new;
  end if;
  select username, display_name, avatar_url into actor
  from public.profiles where id = new.follower;
  if actor.username is null then
    return new;
  end if;
  insert into public.notifications (user_id, type, actor_handle, actor_name, avatar_url, read)
  values (new.followee, 'follow', actor.username,
          coalesce(actor.display_name, actor.username), actor.avatar_url, false);
  return new;
end;
$$;

drop trigger if exists swifs_follow_notify on public.follows;
create trigger swifs_follow_notify
  after insert on public.follows
  for each row execute function public.swifs_follow_notify();

-- 3. Unfollowing removes that person's follow notification, because it is no longer true.
create or replace function public.swifs_unfollow_clean()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.notifications n
  where n.user_id = old.followee
    and n.type = 'follow'
    and lower(trim(both '@' from n.actor_handle)) = (
      select lower(p.username) from public.profiles p where p.id = old.follower
    );
  return old;
end;
$$;

drop trigger if exists swifs_unfollow_clean on public.follows;
create trigger swifs_unfollow_clean
  after delete on public.follows
  for each row execute function public.swifs_unfollow_clean();

-- 4. A direct message creates one "message" notification per sender. A newer message from the
--    same person replaces the older one. Group messages are not added here.
create or replace function public.swifs_message_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor record;
begin
  if new.group_id is not null or new.recipient is null or new.recipient = new.sender then
    return new;
  end if;
  select username, display_name, avatar_url into actor
  from public.profiles where id = new.sender;
  if actor.username is null then
    return new;
  end if;
  delete from public.notifications
  where user_id = new.recipient
    and type = 'message'
    and lower(trim(both '@' from actor_handle)) = lower(actor.username);
  insert into public.notifications (user_id, type, actor_handle, actor_name, avatar_url, preview, read)
  values (new.recipient, 'message', actor.username,
          coalesce(actor.display_name, actor.username), actor.avatar_url,
          left(coalesce(new.text, ''), 80), false);
  return new;
end;
$$;

drop trigger if exists swifs_message_notify on public.messages;
create trigger swifs_message_notify
  after insert on public.messages
  for each row execute function public.swifs_message_notify();

-- 5. Clean up existing rows that are no longer true.
-- A follow notification stays only while that person still follows you.
delete from public.notifications n
where n.type = 'follow'
  and not exists (
    select 1
    from public.follows f
    join public.profiles p on p.id = f.follower
    where f.followee = n.user_id
      and lower(p.username) = lower(trim(both '@' from n.actor_handle))
  );

-- A like notification stays only while that person still likes the post.
delete from public.notifications n
where n.type = 'like'
  and n.post_id is not null
  and not exists (
    select 1
    from public.post_likes l
    join public.profiles p on p.id = l.user_id
    where l.post_id = n.post_id
      and lower(p.username) = lower(trim(both '@' from n.actor_handle))
  );
