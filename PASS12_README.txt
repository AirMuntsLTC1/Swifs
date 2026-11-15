SWIFS FIX PASS 12: Instagram-style post feed from profile tiles (unzip over the repo root)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass12.zip
  git add -A
  git commit -m "Pass 12: profile post tiles open a vertical posts feed"
  git push

What changed:
  - Tapping a post tile on your profile, or on someone else's profile, opens a "Posts"
    screen. It starts on the post you tapped, and you scroll up for newer posts and down
    for older ones, like Instagram.
  - Each post in the feed has its own header (avatar and username), media, like, comment,
    share and save buttons, and the caption.
  - The "Posts" screen is PostFeedScreen in core/widgets/post_media.dart.
  - Other screens (explore, hashtags, saved, thread) still open a single post.
