SWIFS PATCH 11: native phone notifications, background push, live screens.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-11.zip
  supabase db push --remote          # replica identity for live updates and deletes
  python3 apply_notifications_fix.py
  rm -f apply_notifications_fix.py
  git add -A
  git commit -m "Patch 11: native notifications, background push, live screens"
  git push

Then check the Supabase webhooks (Database > Webhooks). Both must point to:
  https://zxhyubnhbskikzgktwmp.supabase.co/functions/v1/push-notify
with the header x-webhook-secret = your PUSH_WEBHOOK_SECRET.
