SWIFS PATCH 2 (Termux). Run after patch 1 is committed.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-2.zip
  python3 fix_group_inbox_crash.py
  rm fix_group_inbox_crash.py
  git add -A
  git commit -m "Patch 2: group message inbox crash"
  git push
