SWIFS PATCH 9: likes, comments and shares on every post.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-9.zip
  supabase db push --remote          # creates post_counts
  python3 apply_post_counts.py       # stops with a message if anything doesn't match
  rm -f apply_post_counts.py
  git add -A
  git commit -m "Patch 9: likes, comments and shares on posts"
  git push
