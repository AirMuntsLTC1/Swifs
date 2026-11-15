SWIFS FIX PASS 14: shared posts in chat open the reels feed (unzip over the repo root)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass14.zip
  git add -A
  git commit -m "Pass 14: shared posts in chat open the vertical reels feed"
  git push

What changed:
  - Tapping a shared post in a chat opens the vertical reels feed, with that post first.
    The header shows the sender's username, like the chat screenshot.
  - Swiping up from a shared post loads random posts, the same as Explore.
  - The reels feed takes an optional title; Explore keeps "Explore".
