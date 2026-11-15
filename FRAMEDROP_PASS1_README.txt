SWIFS FRAME-DROP PASS 1 (unzip over the repo root)

  cd ~/swifs
  unzip -o ~/swifs-framedrop-pass1.zip
  git add -A
  git commit -m "Frame-drop pass 1: cached FFI symbols, cheaper shimmer, reused like-sound player"
  git push

Changed files:
  app/lib/core/native/swifs_ffi.dart
    C++ symbols are looked up once and cached, not on every feed/comment score.
  app/lib/core/widgets/swifs_skeleton.dart
    Shimmer no longer uses ShaderMask (an offscreen layer every frame). One animated
    colour is shared through an InheritedWidget, inside a RepaintBoundary.
    Same look, same widget names, no design change.
  app/lib/features/home/home_screen.dart
    The like sound reuses the screen's single low-latency AudioPlayer instead of
    creating and leaking a new player on every tap.
