SWIFS FRAME-DROP PASS 6 (unzip over the repo root, after pass 5)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass6.zip
  git add -A
  git commit -m "Frame-drop pass 6: load feed details in parallel"
  git push

What changed:
  Building a feed page made five server requests one after another (profiles,
  counts, likes, saves, follows). They now run together, so the feed appears
  after about one round trip instead of five. Same data, same screens.
