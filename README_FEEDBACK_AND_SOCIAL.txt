SWIFS: feedback fix + linked @mentions and #hashtags + followers/following lists

BEFORE YOU APPLY (sound file)
  The pop sound is app/assets/sounds/bubble_pop.mp3. The repo dump does not include
  binary files, so check it is there:
    ls ~/Swifs/app/assets/sounds/
  If bubble_pop.mp3 is missing, copy your file there with that exact name.

APPLY
  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-feedback-social.zip
  flutter pub get
  git add -A
  git commit -m "Feedback: one vibration + one pop per like; linked mentions/hashtags; followers list"
  git push

WHAT CHANGED
  Sound
  - pubspec.yaml declares assets/sounds/. Before, the pop was never bundled, so the
    sound failed silently on every device.
  - One shared sound player (core/feedback/swifs_feedback.dart). PopHeart no longer
    creates a new player per tap, so nothing leaks.
  - Failures print a debug message that names the missing file.

  Vibration
  - Double-tap like vibrated twice (double-tap handler + like handler). Now once.
  - Reels likes had vibration only; they now get the same vibration + pop as the feed.
  - Every feedback call goes through SwifsFeedback (like, unlike, longPress).

  Links
  - @mentions in post captions and comments open that profile.
  - #hashtags in captions and comments open the hashtag screen.

  Followers / Following
  - Tap the Followers or Following count on your profile or someone else's.
  - Each list opens its own screen. Tap a row to open that profile.

NOT IN THIS ZIP (planned next): post ... menu (edit/delete), typing and online dots,
interactive story polls, and the other items on the feature list.
