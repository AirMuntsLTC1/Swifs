SWIFS FIX PASS 10c: no notifications for your own actions (unzip, then migrate)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass10c.zip
  supabase db push --remote
  git add -A
  git commit -m "Pass 10c: skip self notifications, label story reactions"
  git push

What changed:
  - Removes existing notifications where the person who acted is the same person who
    received the notification (likes, comments, story reactions, messages, follows).
  - Blocks any new one of those at the database level, for every type.
  - Story reactions and story replies now show a readable sentence.
