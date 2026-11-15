import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's touch feedback in one place: vibration and the bubble pop sound.
///
/// Each action calls exactly one of these, so a like never buzzes twice and
/// every screen feels the same. The sound uses one shared player, so no native
/// player is created per tap.
class SwifsFeedback {
  SwifsFeedback._();

  /// Path inside app/assets/ (declared in pubspec.yaml under assets/sounds/).
  static const String popAsset = 'sounds/bubble_pop.mp3';

  static AudioPlayer? _player;

  static AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    // Low latency: taps play without a startup delay.
    unawaited(p.setPlayerMode(PlayerMode.lowLatency).catchError((_) {}));
    _player = p;
    return p;
  }

  /// The pop sound. A missing file is logged, never thrown into the UI.
  static Future<void> pop() async {
    try {
      await _ensurePlayer().play(AssetSource(popAsset));
    } catch (e) {
      debugPrint('Pop sound failed. Is $popAsset in app/assets/sounds/? $e');
    }
  }

  static void _vibrate(Future<void> Function() action) {
    unawaited(action().catchError((_) {}));
  }

  /// Like: a light tap and the pop.
  static void like() {
    _vibrate(HapticFeedback.lightImpact);
    unawaited(pop());
  }

  /// Haptic only, for a like whose sound the caller already plays.
  static void hapticLike() => _vibrate(HapticFeedback.lightImpact);

  /// Unlike, or a double tap on a post that is already liked: a soft tick, no sound.
  static void unlike() => _vibrate(HapticFeedback.selectionClick);

  /// Long press that opens a menu.
  static void longPress() => _vibrate(HapticFeedback.mediumImpact);
}
