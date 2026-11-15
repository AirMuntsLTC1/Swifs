SWIFS FIX PASS 13: Explore posts open a full-screen reels feed (unzip over the repo root)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass13.zip
  git add -A
  git commit -m "Pass 13: explore tiles open a vertical reels feed"
  git push

What changed:
  - Tapping a tile in the Find (Explore) grid opens a full-screen vertical feed.
    The post you tapped comes first. Swipe up for the next post.
  - Next posts are shuffled at random from the Explore posts. More are loaded as you go,
    and posts you have already seen come last.
  - The like, comment, share and save buttons are the same animated buttons as the Home
    feed, with the same heart burst. Double tap a post to like it.
  - The author's name has a Follow button, which is hidden on your own posts.
  - Video plays while its post is on screen and stops when you swipe away.
