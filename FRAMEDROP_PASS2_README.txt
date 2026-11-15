SWIFS FRAME-DROP PASS 2 (unzip over the repo root, after pass 1)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass2.zip
  git add -A
  git commit -m "Frame-drop pass 2: skeletons instead of spinners"
  git push

What changed:
  - Full-screen list and grid loading spinners now show the grey skeleton
    placeholders (LoadingList / LoadingGrid, added to swifs_skeleton.dart).
    Screens: explore, search, hashtag, saved posts, user profile, create post
    gallery, messages (both tabs), thread, share sheet, story viewers,
    create group (members), settings.
  - Button and auth spinners are unchanged on purpose.
