SWIFS PATCH 1 (Termux)

This patch does NOT contain the whole project. It only contains what was checked
against your current source and your live Supabase database.

Steps (run in Termux):

  cd ~/swifs
  git status                      # commit or stash anything pending first
  unzip -o ~/swifs-patch-1.zip -d ~/swifs
  pkg install -y python           # only if python3 is missing
  python3 apply_block_rpc.py      # switches blockUser to the block_user RPC
  bash cleanup.sh                 # archives old SQL/migrations, removes backend/
  rm apply_block_rpc.py cleanup.sh
  git add -A
  git commit -m "Patch 1: atomic block, CI analyze/test, cleanup"
  git push

Then, in the Supabase SQL Editor, run sql/02_drop_duplicate_counter.sql
and then sql/03_check_counts.sql. The check should return NO rows.
