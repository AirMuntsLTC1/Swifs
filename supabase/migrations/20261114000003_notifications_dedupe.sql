-- Swifs: remove duplicate follow notifications already stored (keeps the newest per person).
-- Safe to run more than once.
delete from public.notifications a
using public.notifications b
where a.user_id = b.user_id
  and a.type = b.type
  and lower(trim(both '@' from a.actor_handle)) = lower(trim(both '@' from b.actor_handle))
  and a.type like 'follow%'
  and (a.created_at < b.created_at or (a.created_at = b.created_at and a.id < b.id));
