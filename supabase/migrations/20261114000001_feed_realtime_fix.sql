-- Swifs: feed, profile and realtime fixes.
-- Safe to run more than once. Paste into Supabase > SQL Editor and press Run.

-- 1. Columns the app reads but the database did not have
--    (without posts.views the whole feed query failed, so the feed never loaded from the server)
alter table public.posts add column if not exists views integer not null default 0;
alter table public.profiles add column if not exists bio text;

-- 2. Indexes for the feed paging, counts and notifications
create index if not exists posts_created_idx on public.posts (created_at desc);
create index if not exists posts_author_created_idx on public.posts (author_id, created_at desc);
create index if not exists comments_post_created_idx on public.comments (post_id, created_at);
create index if not exists comment_likes_comment_idx on public.comment_likes (comment_id);
create index if not exists post_likes_post_idx on public.post_likes (post_id);
create index if not exists post_saves_user_idx on public.post_saves (user_id);
create index if not exists follows_follower_idx on public.follows (follower);
create index if not exists post_media_post_position_idx on public.post_media (post_id, position);
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index if not exists blocked_users_blocked_idx on public.blocked_users (blocked);

-- 3. Realtime: every table the app listens to must be in the publication
do $$
declare
  t text;
begin
  foreach t in array array[
    'posts', 'post_media', 'post_likes', 'post_saves', 'comments', 'comment_likes',
    'follows', 'profiles', 'stories', 'story_views', 'story_reactions', 'story_replies',
    'messages', 'message_reactions', 'message_hidden', 'groups', 'group_members',
    'blocked_users', 'restricted_users', 'notes', 'notifications'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- 4. Views counter, called by the app when a post is seen
create or replace function public.increment_post_views(p_post_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.posts set views = views + 1 where id = p_post_id;
$$;

grant execute on function public.increment_post_views(uuid) to authenticated;
