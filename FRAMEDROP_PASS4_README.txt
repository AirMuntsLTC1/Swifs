SWIFS FRAME-DROP PASS 4 (unzip over the repo root, after pass 3)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass4.zip
  git add -A
  git commit -m "Frame-drop pass 4: decode images at display size"
  git push

What changed:
  Every photo was decoded at full camera resolution (often 12 MP) even when shown
  in a small tile or avatar. Now each image decodes at about its display size:
    - feed photos: 900 px wide
    - profile grid tiles: 360 px
    - avatars: 200 px (profile, settings)
    - story strip in messages: 240 / 480 px
    - story viewer photo: 1080 px
  Same look; much less memory and CPU work while scrolling.
