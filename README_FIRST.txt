SWIFS PATCH 5: profile editing (name, bio, avatar photo).

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-5.zip
  python3 apply_profile_edit.py      # stops with a message if anything doesn't match
  rm -f apply_profile_edit.py
  git add -A
  git commit -m "Patch 5: profile editing"
  git push

No database change is needed. The avatars bucket and profile update policies already exist.
