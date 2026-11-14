-- ============================================================
-- Swifs database schema for Supabase
-- Run once: Supabase dashboard > SQL Editor > New query > paste > Run
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Tables ----------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,32}$'),
  display_name text,
  bio text,
  created_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  caption text not null default '',
  views int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.post_saves (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  parent_id uuid references public.comments (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create index if not exists posts_created_idx on public.posts (created_at desc);
create index if not exists comments_post_idx on public.comments (post_id, created_at);

-- ---------- New sign-up creates a profile ----------
-- Username comes from sign-up metadata: { "username": "alex" }.
-- If none is given, a generated name is used.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username',
             'user_' || substr(replace(new.id::text, '-', ''), 1, 10))
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Row Level Security ----------
-- Anyone signed in can read. You can only write your own rows.

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_saves enable row level security;
alter table public.follows enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;

create policy "profiles: read" on public.profiles for select to authenticated using (true);
create policy "profiles: update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy "posts: read" on public.posts for select to authenticated using (true);
create policy "posts: insert own" on public.posts for insert to authenticated
  with check (author_id = auth.uid());
create policy "posts: delete own" on public.posts for delete to authenticated
  using (author_id = auth.uid());

create policy "post_likes: read" on public.post_likes for select to authenticated using (true);
create policy "post_likes: write own" on public.post_likes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "post_saves: read own" on public.post_saves for select to authenticated
  using (user_id = auth.uid());
create policy "post_saves: write own" on public.post_saves for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "follows: read" on public.follows for select to authenticated using (true);
create policy "follows: write own" on public.follows for all to authenticated
  using (follower_id = auth.uid()) with check (follower_id = auth.uid());

create policy "comments: read" on public.comments for select to authenticated using (true);
create policy "comments: insert own" on public.comments for insert to authenticated
  with check (author_id = auth.uid());
create policy "comments: delete own" on public.comments for delete to authenticated
  using (author_id = auth.uid());

create policy "comment_likes: read" on public.comment_likes for select to authenticated using (true);
create policy "comment_likes: write own" on public.comment_likes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- Functions the app calls ----------
-- Scores are NOT stored: the app ranks with the C++ core.

-- Feed: posts with counts and the signed-in user's state
create or replace function public.get_feed()
returns table (
  id uuid,
  username text,
  caption text,
  views int,
  age_minutes int,
  likes bigint,
  comments bigint,
  liked boolean,
  is_saved boolean,
  is_following boolean
)
language sql
stable
as $$
  select
    p.id,
    pr.username,
    p.caption,
    p.views,
    greatest(0, floor(extract(epoch from (now() - p.created_at)) / 60)::int),
    (select count(*) from public.post_likes l where l.post_id = p.id),
    (select count(*) from public.comments c where c.post_id = p.id),
    exists (select 1 from public.post_likes l where l.post_id = p.id and l.user_id = auth.uid()),
    exists (select 1 from public.post_saves s where s.post_id = p.id and s.user_id = auth.uid()),
    exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followee_id = p.author_id)
  from public.posts p
  join public.profiles pr on pr.id = p.author_id
  order by p.created_at desc
  limit 50
$$;

-- Comments on one post (flat; the app builds the reply threads)
create or replace function public.get_comments(p_post_id uuid)
returns table (
  id uuid,
  parent_id uuid,
  username text,
  body text,
  age_minutes int,
  likes bigint,
  liked boolean
)
language sql
stable
as $$
  select
    c.id,
    c.parent_id,
    pr.username,
    c.body,
    greatest(0, floor(extract(epoch from (now() - c.created_at)) / 60)::int),
    (select count(*) from public.comment_likes cl where cl.comment_id = c.id),
    exists (select 1 from public.comment_likes cl where cl.comment_id = c.id and cl.user_id = auth.uid())
  from public.comments c
  join public.profiles pr on pr.id = c.author_id
  where c.post_id = p_post_id
  order by c.created_at
$$;

-- Like / unlike (desired state, so retries are safe)
create or replace function public.set_like(p_post_id uuid, p_liked boolean)
returns table (is_liked boolean, like_count bigint)
language plpgsql
as $$
begin
  if p_liked then
    insert into public.post_likes (post_id, user_id) values (p_post_id, auth.uid())
    on conflict do nothing;
  else
    delete from public.post_likes where post_id = p_post_id and user_id = auth.uid();
  end if;
  return query
    select
      exists (select 1 from public.post_likes l where l.post_id = p_post_id and l.user_id = auth.uid()),
      (select count(*) from public.post_likes l2 where l2.post_id = p_post_id);
end;
$$;

-- Save / unsave
create or replace function public.set_save(p_post_id uuid, p_saved boolean)
returns table (is_saved boolean)
language plpgsql
as $$
begin
  if p_saved then
    insert into public.post_saves (post_id, user_id) values (p_post_id, auth.uid())
    on conflict do nothing;
  else
    delete from public.post_saves where post_id = p_post_id and user_id = auth.uid();
  end if;
  return query
    select exists (select 1 from public.post_saves s where s.post_id = p_post_id and s.user_id = auth.uid());
end;
$$;

-- Follow / unfollow by username
create or replace function public.set_follow(p_username text, p_follow boolean)
returns table (is_following boolean)
language plpgsql
as $$
declare
  target uuid;
begin
  select pr.id into target from public.profiles pr where pr.username = p_username;
  if target is null then
    raise exception 'User not found';
  end if;
  if target = auth.uid() then
    raise exception 'You cannot follow yourself';
  end if;

  if p_follow then
    insert into public.follows (follower_id, followee_id) values (auth.uid(), target)
    on conflict do nothing;
  else
    delete from public.follows f where f.follower_id = auth.uid() and f.followee_id = target;
  end if;

  return query
    select exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.followee_id = target);
end;
$$;

-- Add a comment or a reply (replies go one level deep)
create or replace function public.add_comment(p_post_id uuid, p_body text, p_parent_id uuid default null)
returns table (
  id uuid,
  parent_id uuid,
  username text,
  body text,
  age_minutes int,
  likes bigint,
  liked boolean
)
language plpgsql
as $$
declare
  new_id uuid;
begin
  if p_parent_id is not null and not exists (
    select 1 from public.comments c
    where c.id = p_parent_id and c.post_id = p_post_id and c.parent_id is null
  ) then
    raise exception 'Parent comment not found or too deep';
  end if;

  insert into public.comments (post_id, parent_id, author_id, body)
  values (p_post_id, p_parent_id, auth.uid(), p_body)
  returning comments.id into new_id;

  return query
    select g.* from public.get_comments(p_post_id) g where g.id = new_id;
end;
$$;

-- Like / unlike a comment
create or replace function public.set_comment_like(p_comment_id uuid, p_liked boolean)
returns table (is_liked boolean, like_count bigint)
language plpgsql
as $$
begin
  if p_liked then
    insert into public.comment_likes (comment_id, user_id) values (p_comment_id, auth.uid())
    on conflict do nothing;
  else
    delete from public.comment_likes where comment_id = p_comment_id and user_id = auth.uid();
  end if;
  return query
    select
      exists (select 1 from public.comment_likes cl where cl.comment_id = p_comment_id and cl.user_id = auth.uid()),
      (select count(*) from public.comment_likes cl2 where cl2.comment_id = p_comment_id);
end;
$$;

-- Only signed-in users may call the functions above
revoke execute on function public.get_feed() from anon;
revoke execute on function public.get_comments(uuid) from anon;
revoke execute on function public.set_like(uuid, boolean) from anon;
revoke execute on function public.set_save(uuid, boolean) from anon;
revoke execute on function public.set_follow(text, boolean) from anon;
revoke execute on function public.add_comment(uuid, text, uuid) from anon;
revoke execute on function public.set_comment_like(uuid, boolean) from anon;
