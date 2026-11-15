SWIFS FRAME-DROP PASS 3 (unzip over the repo root, after pass 2)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass3.zip
  flutter pub get        (only if you run Flutter locally; CI does it anyway)
  git add -A
  git commit -m "Frame-drop pass 3: photo thumbnails off the UI thread, perf indexes"
  git push

Then in the Supabase dashboard: SQL Editor -> paste supabase/perf_indexes.sql -> Run.

What changed:
  - Photo thumbnails and sizes are made in a background isolate (image_prep.dart).
    Decoding, rotating and resizing no longer run on the UI thread during posting.
    Thumbnails are now JPEG (smaller uploads). Older PNG thumbnails still load.
  - Adds the image package (pubspec.yaml).
  - perf_indexes.sql: indexes for group chats and shared posts.
