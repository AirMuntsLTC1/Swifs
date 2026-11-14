-- Swifs: remove duplicate notifications that were already stored. Safe to run more than once.
-- Follow rows: one per person (keeps the newest).
delete from public.notifications a
using public.notifications b
where a.user_id = b.user_id
  and a.type ilike '%follow%' and b.type ilike '%follow%'
  and lower(trim(both '@' from a.actor_handle)) = lower(trim(both '@' from b.actor_handle))
  and (a.created_at < b.created_at or (a.created_at = b.created_at and a.id < b.id));

-- Other rows: one per person, per kind, per post or comment (keeps the newest).
delete from public.notifications a
using public.notifications b
where a.user_id = b.user_id
  and a.type = b.type
  and coalesce(a.post_id::text, '') = coalesce(b.post_id::text, '')
  and coalesce(a.comment_id::text, '') = coalesce(b.comment_id::text, '')
  and lower(trim(both '@' from a.actor_handle)) = lower(trim(both '@' from b.actor_handle))
  and (a.created_at < b.created_at or (a.created_at = b.created_at and a.id < b.id));
