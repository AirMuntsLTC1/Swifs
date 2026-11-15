SWIFS FIX PASS 8: remaining keyboard sheets (unzip over the repo root, after pass 7)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass8.zip
  git add -A
  git commit -m "Pass 8: keyboard isolation for story text, sticker and note sheets"
  git push

What changed:
  - Story text sheet, story location sheet and the Note sheet in messages no longer
    read the keyboard height in their own build. They use KeyboardInset with
    basePadding, so only the padding updates as the keyboard animates.
  - KeyboardInset gained an optional basePadding (default zero, so earlier uses are
    unchanged).
  - messages_screen.dart is included as the full current file. It already contains
    pass 7 changes, so unzipping this one is safe after pass 7.
