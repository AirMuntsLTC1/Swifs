-- Fix missing INSERT policy for notifications trigger
drop policy if exists "notifications insert trigger" on public.notifications;
create policy "notifications insert trigger" on public.notifications
  for insert to authenticated with check (true);
