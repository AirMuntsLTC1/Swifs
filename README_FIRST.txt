SWIFS PATCH 4: group chats in the inbox and thread, atomic group creation.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-4.zip
  supabase db push --remote          # creates the create_group function
  python3 apply_group_chat.py        # edits the Dart files (stops if anything doesn't match)
  rm -f apply_group_chat.py
  git add -A
  git commit -m "Patch 4: group chats in inbox and thread"
  git push
