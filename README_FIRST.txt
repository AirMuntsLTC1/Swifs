SWIFS PATCH 6: background push (Firebase Cloud Messaging)

STEP 1: put your Firebase config in the repo (public client config, safe to commit)
  cd ~/Swifs
  mkdir -p android-config
  cp ~/storage/downloads/google-services.json android-config/

STEP 2: unzip and apply the code changes
  unzip -o ~/storage/downloads/swifs-patch-6.zip
  python3 apply_push.py
  rm -f apply_push.py

STEP 3: database (creates user_devices and register_device)
  supabase db push --remote

STEP 4: secrets for the edge function (Supabase dashboard > Edge Functions > Secrets)
  FCM_SERVICE_ACCOUNT   = the whole JSON from the service account key file (paste the full contents)
  PUSH_WEBHOOK_SECRET   = any long random text you make up (keep it, you need it in step 6)
  Then delete the downloaded service account file from your phone.

STEP 5: deploy the edge function "push-notify"
  Dashboard: Edge Functions > New function > name push-notify > paste supabase/functions/push-notify/index.ts > Deploy.
  Turn OFF "Verify JWT" for this function (the webhook uses the secret instead).
  (CLI alternative: supabase functions deploy push-notify --no-verify-jwt)

STEP 6: two database webhooks (Dashboard > Database > Webhooks > Create)
  Webhook 1: name push_notifications, table notifications, events Insert,
             type Supabase Edge Function, function push-notify,
             HTTP header  x-webhook-secret = the PUSH_WEBHOOK_SECRET value
  Webhook 2: name push_messages, table messages, events Insert, same function and header.

STEP 7: commit and push
  git add -A
  git commit -m "Patch 6: Firebase push"
  git push

Test: sign in on the phone, close the app completely, then have another account send a
message or like a post. The notification should appear even though the app is closed.
