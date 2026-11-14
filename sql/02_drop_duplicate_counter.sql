-- Your live database already has follows_counts on public.follows,
-- which maintains the follower counts. The counter trigger I added earlier
-- is redundant, so remove it.
drop trigger if exists swifly_recount_follows on public.follows;
drop function if exists public.recount_follows();
