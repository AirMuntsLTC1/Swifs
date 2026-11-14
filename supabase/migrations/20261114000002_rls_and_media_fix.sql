-- Swifs: full RLS rewrite + media fixes. Safe to run more than once.
-- Drops EVERY policy in the public schema first, because permissive policies combine with OR:
-- an old, looser policy left behind would still let rows through.

-- 0. Columns the app uses
alter table public.posts alter column audience set default 'Everyone';
update public.posts set audience = 'Everyone' where audience is null;
alter table public.stories add column if not exists media_type text not null default 'image';

-- 1. Helper functions. SECURITY DEFINER so a policy never recurses into another policy's table.
create or replace function public.is_following(p_author uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.follows f where f.follower = auth.uid() and f.followee = p_author);
$$;

create or replace function public.is_blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.blocked_users x
    where (x.blocker = a and x.blocked = b) or (x.blocker = b and x.blocked = a)
  );
$$;

create or replace function public.is_group_member(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.group_members gm where gm.group_id = gid and gm.user_id = auth.uid());
$$;

create or replace function public.is_group_admin(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.groups g where g.id = gid and g.admin_id = auth.uid());
$$;

-- 2. Remove every existing policy in public
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public' loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- 3. Row level security on for every app table
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_saves enable row level security;
alter table public.follows enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.blocked_users enable row level security;
alter table public.restricted_users enable row level security;
alter table public.notifications enable row level security;
alter table public.notes enable row level security;
alter table public.profile_fields enable row level security;
alter table public.profile_suggestions enable row level security;
alter table public.trending_tags enable row level security;
alter table public.user_settings enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.story_reactions enable row level security;
alter table public.story_replies enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_hidden enable row level security;
alter table public.message_reactions enable row level security;
alter table public.message_reports enable row level security;

-- 4. Profiles
create policy swifs_profiles_read on public.profiles for select to authenticated using (true);
create policy swifs_profiles_insert_own on public.profiles for insert to authenticated with check (id = auth.uid());
create policy swifs_profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- 5. Posts: public posts, or the author's own, or followers' posts. Never a blocked user's.
create policy swifs_posts_read on public.posts for select to authenticated using (
  author_id = auth.uid()
  or (lower(coalesce(audience, 'everyone')) = 'everyone' and not public.is_blocked_between(auth.uid(), author_id))
  or (public.is_following(author_id) and not public.is_blocked_between(auth.uid(), author_id))
);
create policy swifs_posts_insert_own on public.posts for insert to authenticated with check (author_id = auth.uid());
create policy swifs_posts_update_own on public.posts for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy swifs_posts_delete_own on public.posts for delete to authenticated using (author_id = auth.uid());

-- 6. Post media: visible when its post is visible (posts policy applies inside the check).
create policy swifs_post_media_read on public.post_media for select to authenticated using (
  exists (select 1 from public.posts p where p.id = post_media.post_id)
);
create policy swifs_post_media_insert_author on public.post_media for insert to authenticated with check (
  exists (select 1 from public.posts p where p.id = post_media.post_id and p.author_id = auth.uid())
);
create policy swifs_post_media_delete_author on public.post_media for delete to authenticated using (
  exists (select 1 from public.posts p where p.id = post_media.post_id and p.author_id = auth.uid())
);

-- 7. Likes, saves, comment likes
create policy swifs_post_likes_read on public.post_likes for select to authenticated using (true);
create policy swifs_post_likes_insert_own on public.post_likes for insert to authenticated with check (user_id = auth.uid());
create policy swifs_post_likes_delete_own on public.post_likes for delete to authenticated using (user_id = auth.uid());

create policy swifs_post_saves_read_own on public.post_saves for select to authenticated using (user_id = auth.uid());
create policy swifs_post_saves_insert_own on public.post_saves for insert to authenticated with check (user_id = auth.uid());
create policy swifs_post_saves_delete_own on public.post_saves for delete to authenticated using (user_id = auth.uid());

create policy swifs_comment_likes_read on public.comment_likes for select to authenticated using (true);
create policy swifs_comment_likes_insert_own on public.comment_likes for insert to authenticated with check (user_id = auth.uid());
create policy swifs_comment_likes_delete_own on public.comment_likes for delete to authenticated using (user_id = auth.uid());

-- 8. Follows: anyone can see who follows whom; you can only follow or unfollow as yourself
create policy swifs_follows_read on public.follows for select to authenticated using (true);
create policy swifs_follows_insert_own on public.follows for insert to authenticated with check (
  follower = auth.uid() and not public.is_blocked_between(auth.uid(), followee)
);
create policy swifs_follows_delete_own on public.follows for delete to authenticated using (follower = auth.uid());

-- 9. Comments: visible on visible posts; you write as yourself; you delete your own or on your post
create policy swifs_comments_read on public.comments for select to authenticated using (
  exists (select 1 from public.posts p where p.id = comments.post_id)
);
create policy swifs_comments_insert_own on public.comments for insert to authenticated with check (
  author_id = auth.uid() and exists (select 1 from public.posts p where p.id = comments.post_id)
);
create policy swifs_comments_delete on public.comments for delete to authenticated using (
  author_id = auth.uid()
  or exists (select 1 from public.posts p where p.id = comments.post_id and p.author_id = auth.uid())
);

-- 10. Blocks and restrictions
create policy swifs_blocked_read on public.blocked_users for select to authenticated
  using (blocker = auth.uid() or blocked = auth.uid());
create policy swifs_blocked_insert_own on public.blocked_users for insert to authenticated with check (blocker = auth.uid());
create policy swifs_blocked_delete_own on public.blocked_users for delete to authenticated using (blocker = auth.uid());

create policy swifs_restricted_read_own on public.restricted_users for select to authenticated using (restrictor = auth.uid());
create policy swifs_restricted_insert_own on public.restricted_users for insert to authenticated with check (restrictor = auth.uid());
create policy swifs_restricted_delete_own on public.restricted_users for delete to authenticated using (restrictor = auth.uid());

-- 11. Notifications: you see, change and clear your own. Triggers create them (insert check true).
create policy swifs_notifications_read_own on public.notifications for select to authenticated using (user_id = auth.uid());
create policy swifs_notifications_update_own on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy swifs_notifications_delete_own on public.notifications for delete to authenticated using (user_id = auth.uid());
create policy swifs_notifications_insert_trigger on public.notifications for insert to authenticated with check (true);

-- 12. Notes, profile fields, suggestions, trending, settings
create policy swifs_notes_read on public.notes for select to authenticated
  using (user_id = auth.uid() or public.is_following(user_id));
create policy swifs_notes_write_own on public.notes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy swifs_profile_fields_read on public.profile_fields for select to authenticated using (
  user_id = auth.uid() or audience = 'everyone' or (audience = 'followers' and public.is_following(user_id))
);
create policy swifs_profile_fields_write_own on public.profile_fields for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy swifs_suggestions_read on public.profile_suggestions for select to authenticated using (true);
create policy swifs_trending_read on public.trending_tags for select to authenticated using (true);

create policy swifs_user_settings_read_own on public.user_settings for select to authenticated using (user_id = auth.uid());
create policy swifs_user_settings_insert_own on public.user_settings for insert to authenticated with check (user_id = auth.uid());
create policy swifs_user_settings_update_own on public.user_settings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 13. Stories: active stories from people you follow, and your own
create policy swifs_stories_read on public.stories for select to authenticated using (
  author_id = auth.uid()
  or (expires_at > now() and public.is_following(author_id) and not public.is_blocked_between(auth.uid(), author_id))
);
create policy swifs_stories_insert_own on public.stories for insert to authenticated with check (author_id = auth.uid());
create policy swifs_stories_update_own on public.stories for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy swifs_stories_delete_own on public.stories for delete to authenticated using (author_id = auth.uid());

-- Views: you see your own view; the story's author sees everyone's. Upsert needs update too.
create policy swifs_story_views_read on public.story_views for select to authenticated using (
  viewer_id = auth.uid() or exists (select 1 from public.stories s where s.id = story_views.story_id and s.author_id = auth.uid())
);
create policy swifs_story_views_insert_own on public.story_views for insert to authenticated with check (viewer_id = auth.uid());
create policy swifs_story_views_update_own on public.story_views for update to authenticated
  using (viewer_id = auth.uid()) with check (viewer_id = auth.uid());

create policy swifs_story_reactions_read on public.story_reactions for select to authenticated using (
  user_id = auth.uid() or exists (select 1 from public.stories s where s.id = story_reactions.story_id and s.author_id = auth.uid())
);
create policy swifs_story_reactions_insert_own on public.story_reactions for insert to authenticated with check (user_id = auth.uid());
create policy swifs_story_reactions_delete_own on public.story_reactions for delete to authenticated using (user_id = auth.uid());

create policy swifs_story_replies_read on public.story_replies for select to authenticated using (
  user_id = auth.uid() or exists (select 1 from public.stories s where s.id = story_replies.story_id and s.author_id = auth.uid())
);
create policy swifs_story_replies_insert_own on public.story_replies for insert to authenticated with check (user_id = auth.uid());
create policy swifs_story_replies_delete_own on public.story_replies for delete to authenticated using (user_id = auth.uid());

-- 14. Groups. The creator can read the group right after making it (admin_id), then members can too.
create policy swifs_groups_read on public.groups for select to authenticated using (
  admin_id = auth.uid() or public.is_group_member(id)
);
create policy swifs_groups_insert_admin on public.groups for insert to authenticated with check (admin_id = auth.uid());
create policy swifs_groups_update_admin on public.groups for update to authenticated
  using (admin_id = auth.uid()) with check (admin_id = auth.uid());
create policy swifs_groups_delete_admin on public.groups for delete to authenticated using (admin_id = auth.uid());

create policy swifs_group_members_read on public.group_members for select to authenticated using (
  user_id = auth.uid() or public.is_group_member(group_id)
);
create policy swifs_group_members_insert on public.group_members for insert to authenticated with check (
  user_id = auth.uid() or public.is_group_admin(group_id)
);
create policy swifs_group_members_delete on public.group_members for delete to authenticated using (
  user_id = auth.uid() or public.is_group_admin(group_id)
);

-- 15. Messages: you see messages you sent, received, or in a group you are in.
--     You can send to someone who has not blocked you (either way), or to a group you are in.
create policy swifs_messages_read on public.messages for select to authenticated using (
  sender = auth.uid() or recipient = auth.uid() or public.is_group_member(group_id)
);
create policy swifs_messages_insert on public.messages for insert to authenticated with check (
  sender = auth.uid() and (
    (recipient is not null and not public.is_blocked_between(auth.uid(), recipient))
    or (group_id is not null and public.is_group_member(group_id))
  )
);
create policy swifs_messages_update on public.messages for update to authenticated
  using (sender = auth.uid() or recipient = auth.uid() or public.is_group_member(group_id))
  with check (sender = auth.uid() or recipient = auth.uid() or public.is_group_member(group_id));
create policy swifs_messages_delete_sender on public.messages for delete to authenticated using (sender = auth.uid());

create policy swifs_message_hidden_own on public.message_hidden for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy swifs_message_reactions_read on public.message_reactions for select to authenticated using (
  exists (select 1 from public.messages m where m.id = message_reactions.message_id)
);
create policy swifs_message_reactions_insert_own on public.message_reactions for insert to authenticated with check (user_id = auth.uid());
create policy swifs_message_reactions_delete_own on public.message_reactions for delete to authenticated using (user_id = auth.uid());
create policy swifs_message_reports_insert on public.message_reports for insert to authenticated with check (reporter = auth.uid());
create policy swifs_message_reports_read_own on public.message_reports for select to authenticated using (reporter = auth.uid());

-- 16. Storage: anyone reads public media. You write only inside your own folder (your user id).
drop policy if exists "stories bucket upload own folder" on storage.objects;
drop policy if exists "stories bucket update own folder" on storage.objects;

create policy swifs_media_read on storage.objects for select to anon, authenticated
  using (bucket_id in ('post-media', 'stories', 'avatars'));
create policy swifs_media_insert_own_folder on storage.objects for insert to authenticated
  with check (bucket_id in ('post-media', 'stories', 'avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy swifs_media_update_own_folder on storage.objects for update to authenticated
  using (bucket_id in ('post-media', 'stories', 'avatars') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('post-media', 'stories', 'avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy swifs_media_delete_own_folder on storage.objects for delete to authenticated
  using (bucket_id in ('post-media', 'stories', 'avatars') and (storage.foldername(name))[1] = auth.uid()::text);
