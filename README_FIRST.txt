SWIFS PATCH 12: realtime hub, one binding per table.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-12.zip
  python3 apply_hub_fix.py
  rm -f apply_hub_fix.py
  git add -A
  git commit -m "Patch 12: realtime bindings per table"
  git push

CHECK 1: replica identity (should show f = full for all six):
  select c.relname, c.relreplident
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('posts','profiles','messages','notifications','follows','stories');

CHECK 2: migrations applied:
  supabase migration list --linked
  (20261114000009 should show in both Local and Remote columns)

CHECK 3: database webhooks (Dashboard > Database > Webhooks). Both must point to:
  https://zxhyubnhbskikzgktwmp.supabase.co/functions/v1/push-notify
  with header x-webhook-secret = your PUSH_WEBHOOK_SECRET.
  Table notifications (Insert) and table messages (Insert).
  The URL https://supabase.co is not the function. Webhooks to that URL do nothing.
