SWIFS FRAME-DROP PASS 5 (unzip over the repo root, after pass 4)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass5.zip
  git add -A
  git commit -m "Frame-drop pass 5: release video players when scrolled away"
  git push

What changed:
  Videos paused when they scrolled out of view, but their native player stayed
  in memory. In a long feed that piled up and caused stutter. Now the player is
  released when the video leaves the screen. Its poster stays in place, and the
  video loads again when it returns.
