import 'package:flutter/widgets.dart';

/// Runs [action] once the page holding [context] has finished sliding in.
///
/// Starting heavy loads during the slide makes the transition stutter. Call this from a
/// post-frame callback in initState (ModalRoute cannot be read from initState itself):
///
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     if (mounted) runAfterRouteAnimation(context, () { if (mounted) _load(); });
///   });
void runAfterRouteAnimation(BuildContext context, VoidCallback action) {
  final animation = ModalRoute.of(context)?.animation;
  if (animation == null || animation.status == AnimationStatus.completed) {
    action();
    return;
  }
  void listener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      animation.removeStatusListener(listener);
      action();
    } else if (status == AnimationStatus.dismissed) {
      // The page was closed before it finished opening. Nothing to load.
      animation.removeStatusListener(listener);
    }
  }
  animation.addStatusListener(listener);
}
