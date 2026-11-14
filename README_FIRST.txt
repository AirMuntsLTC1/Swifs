SWIFS PATCH 3: SQL as a migration, and a safe cleanup.

ONE RULE: supabase db push only runs files in supabase/migrations/.
Files in sql/ are never pushed. Every database change goes in supabase/migrations/
with a new timestamped name, then you push.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-3.zip

1) Check the migration history BEFORE anything else:
     supabase migration list --linked
   If any 20240101... rows show a value in the Remote column, do not move or delete
   those files. (This patch does not move them.)

2) Apply the pending fixes from patch 1 (if you have not yet):
     python3 apply_block_rpc.py
     rm -f apply_block_rpc.py

3) Push the new migration:
     supabase db push --remote
   Expected output: "Applying migration 20261114000005_block_user_and_counts.sql"

4) Cleanup (safe, moves files only):
     bash cleanup.sh
     rm -f cleanup.sh

5) Commit and push:
     git add -A
     git commit -m "Patch 3: block RPC migration, safe cleanup"
     git push

Then check counts (read-only). Paste this in the Supabase SQL Editor, or use
the file in sql/03_check_counts.sql. Expect no rows.
