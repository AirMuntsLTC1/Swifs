-- Speed up group chats and shared posts in messages.
-- Run once in Supabase: SQL Editor -> New query -> Run. Safe to run more than once.

create index if not exists messages_group_created_idx
  on public.messages (group_id, created_at desc);

create index if not exists messages_shared_post_idx
  on public.messages (shared_post_id)
  where shared_post_id is not null;
