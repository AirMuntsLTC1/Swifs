-- Likes, comments and shares for many posts in one call.
-- Counted on the server so every viewer sees the same numbers.
-- A share is a chat message that carries the post (messages.shared_post_id).
create or replace function public.post_counts(p_post_ids text[])
returns table (post_id uuid, likes bigint, comments bigint, shares bigint)
language sql
stable
security definer
set search_path = public
as $$
  select p.id,
         (select count(*) from public.post_likes l where l.post_id = p.id),
         (select count(*) from public.comments c where c.post_id = p.id),
         (select count(*) from public.messages m where m.shared_post_id = p.id)
  from public.posts p
  where p.id::text = any(p_post_ids);
$$;

grant execute on function public.post_counts(text[]) to authenticated;
