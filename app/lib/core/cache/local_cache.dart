import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-first storage on the phone. Everything is stored as JSON.
///
/// Keys:
///   cache.feed              the last loaded feed
///   cache.comments.<postId> the last loaded comments for a post
///   cache.profiles          profile info by user id
///   cache.tmpids            temporary comment id -> server id
///   outbox                  actions waiting to be sent to the server
class LocalCache {
  LocalCache._();
  static final LocalCache instance = LocalCache._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async => _prefs ??= await SharedPreferences.getInstance();

  Future<dynamic> read(String key) async {
    final raw = (await _store).getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object? value) async {
    await (await _store).setString(key, jsonEncode(value));
  }

  /// Removes everything that belongs to the signed-in user (used on sign-out).
  Future<void> clearUserData() async {
    final store = await _store;
    for (final key in store.getKeys().toList()) {
      if (key.startsWith('cache.') || key == 'outbox') {
        await store.remove(key);
      }
    }
  }
}
