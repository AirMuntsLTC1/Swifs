-- Expect NO rows. Any row shown has a wrong follower or following count.
select p.id, p.username, p.followers_count, p.following_count,
       (select count(*) from public.follows f where f.followee = p.id) as real_followers,
       (select count(*) from public.follows f where f.follower = p.id) as real_following
from public.profiles p
where p.followers_count is distinct from (select count(*) from public.follows f where f.followee = p.id)
   or p.following_count is distinct from (select count(*) from public.follows f where f.follower = p.id);
