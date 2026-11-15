SWIFS FIX PASS 10b: remove self-follows (unzip, then migrate)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass10b.zip
  supabase db push --remote
  git add -A
  git commit -m "Pass 10b: remove self-follows"
  git push

Run this after pass 10. It deletes the row where you follow yourself, the notifications
it created, and adds a database rule so a self-follow is refused.
