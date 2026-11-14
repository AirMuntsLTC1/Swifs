SWIFS PATCH 10: unread badges and live updates.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-10.zip
  python3 apply_realtime_badges.py
  rm -f apply_realtime_badges.py
  git add -A
  git commit -m "Patch 10: unread badges and realtime"
  git push

No database change is needed.
