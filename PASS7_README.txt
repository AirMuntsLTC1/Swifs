SWIFS FIX PASS 7: keyboard, chat channels, shared realtime, tab switching, route transitions
(unzip over the repo root)

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-framedrop-pass7.zip
  git add -A
  git commit -m "Pass 7: keyboard isolation, one realtime channel, tab keep-alive, deferred loads"
  git push

WHAT CHANGED

1. Realtime: one shared channel for chat.
   RealtimeHub did not watch the messages table, so the chat screens each opened a
   separate channel. "messages" is now in the hub's table list. MessagesScreen and
   ThreadScreen no longer open their own channels. Opening a chat is faster.

2. Keyboard: no whole-sheet rebuild on each keyboard frame.
   - New core/widgets/keyboard_inset.dart: lifts a child above the keyboard, reading
     the keyboard height only inside its own padding.
   - Comments sheet and share sheet use it.
   - Comments composer rebuilds only itself while typing (no whole-sheet setState).
   - Share sheet search rebuilds only its user list while typing.

3. Tabs: no reload on switch.
   Each tab is kept alive inside the existing PageView. The slide animation is unchanged.

4. Route transitions: heavy loads wait for the slide to finish.
   - New core/widgets/route_defer.dart.
   - Chat thread and visitor profile start their data loads after the slide-in.
