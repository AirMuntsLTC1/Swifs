SWIFS FIX PASS 9: keyboard and composer lag (unzip over the repo root, after pass 8)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass9.zip
  git add -A
  git commit -m "Pass 9: keyboard and composer rebuild fixes"
  git push

WHY THE LAG HAPPENED
  MediaQuery.of(context) subscribes to the WHOLE MediaQuery. The keyboard changes
  MediaQuery every animation frame, so any widget that called MediaQuery.of(context)
  rebuilt 60-120 times a second while the keyboard opened. In the chat thread,
  every message bubble did this just to read the screen width.

WHAT CHANGED
  - MediaQuery.of(x).size -> MediaQuery.sizeOf(x), and .padding -> MediaQuery.paddingOf(x),
    everywhere. These only rebuild when the size or padding changes, not the keyboard.
    Chat bubbles, the tab bar, story and message sheets are included.
  - Messages search: typing rebuilds only the conversation list, not the whole screen.
  - Group creation search: removed a keystroke rebuild that did nothing.
