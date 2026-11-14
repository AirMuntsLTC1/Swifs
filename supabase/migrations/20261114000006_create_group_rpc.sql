-- Creates a group and its members in one transaction.
-- Previously the app inserted the group and each member in separate calls.
create or replace function public.create_group(p_name text, p_members uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  gid uuid;
  m uuid;
begin
  if me is null then raise exception 'Not signed in'; end if;

  insert into public.groups (name, admin_id)
  values (coalesce(nullif(trim(p_name), ''), 'New Group'), me)
  returning id into gid;

  insert into public.group_members (group_id, user_id) values (gid, me);

  foreach m in array coalesce(p_members, '{}'::uuid[]) loop
    if m <> me then
      insert into public.group_members (group_id, user_id)
      select gid, m
      where not exists (
        select 1 from public.group_members gm
        where gm.group_id = gid and gm.user_id = m
      );
    end if;
  end loop;

  return gid;
end;
$$;

grant execute on function public.create_group(text, uuid[]) to authenticated;
