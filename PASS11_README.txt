SWIFS FIX PASS 11: no Follow on your own account (unzip over the repo root)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass11.zip
  git add -A
  git commit -m "Pass 11: no follow buttons or follows on your own account"
  git push

What changed:
  - Your own profile: no Follow button.
  - Suggested people on the home feed: your own card has no Follow button.
  - Search: your own account is not listed, so there is no Follow button for it.
  - Notifications: nothing about your own account, and no button on it.
  - Repository: notifications from your own account are dropped, and a self-follow is refused.
  - New helper core/auth/current_user.dart decides "is this me?" in one place.
