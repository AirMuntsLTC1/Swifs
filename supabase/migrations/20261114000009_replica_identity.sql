-- Realtime needs the full old row for UPDATE and DELETE events (unsend, read receipts,
-- profile edits). Without this, those events arrive with only the primary key.
alter table public.posts replica identity full;
alter table public.profiles replica identity full;
alter table public.messages replica identity full;
alter table public.notifications replica identity full;
alter table public.follows replica identity full;
alter table public.stories replica identity full;
