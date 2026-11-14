-- Migration: atomic block RPC, and removal of a redundant counter trigger.
-- Safe to run more than once. Your live database already has follows_counts
-- maintaining follower counts, so the extra counter trigger is dropped here.

create or replace function public.block_user(p_target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'Not signed in'; end if;
  if p_target = me then raise exception 'You cannot block yourself'; end if;

  insert into public.blocked_users (blocker, blocked)
  select me, p_target
  where not exists (
    select 1 from public.blocked_users b
    where b.blocker = me and b.blocked = p_target
  );

  delete from public.follows
  where (follower = me and followee = p_target)
     or (follower = p_target and followee = me);
end;
$$;

grant execute on function public.block_user(uuid) to authenticated;

drop trigger if exists swifly_recount_follows on public.follows;
drop function if exists public.recount_follows();
