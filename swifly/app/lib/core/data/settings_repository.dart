import 'package:supabase_flutter/supabase_flutter.dart';
import '../cache/local_cache.dart';

/// The signed-in user's settings. Field names match the user_settings table columns.
class UserSettings {
  final String accountPrivacy; // Public | Private
  final bool friendsFeedActivity;
  final String messagesAudience; // Everyone | Followers | Off
  final String tagsAudience;
  final String commentsAudience;
  final bool sharingReuse;
  final String limitInteractions; // Off | On
  final bool hiddenWords;
  final bool pushNotifications;
  final bool likeNotifications;
  final bool commentNotifications;
  final bool followNotifications;

  const UserSettings({
    required this.accountPrivacy,
    required this.friendsFeedActivity,
    required this.messagesAudience,
    required this.tagsAudience,
    required this.commentsAudience,
    required this.sharingReuse,
    required this.limitInteractions,
    required this.hiddenWords,
    required this.pushNotifications,
    required this.likeNotifications,
    required this.commentNotifications,
    required this.followNotifications,
  });

  factory UserSettings.defaults() => const UserSettings(
        accountPrivacy: 'Public',
        friendsFeedActivity: true,
        messagesAudience: 'Everyone',
        tagsAudience: 'Everyone',
        commentsAudience: 'Everyone',
        sharingReuse: true,
        limitInteractions: 'Off',
        hiddenWords: true,
        pushNotifications: true,
        likeNotifications: true,
        commentNotifications: true,
        followNotifications: true,
      );

  factory UserSettings.fromMap(Map<String, dynamic> m) {
    final d = UserSettings.defaults();
    String str(String k, String fallback) => (m[k] as String?) ?? fallback;
    bool flag(String k, bool fallback) => (m[k] as bool?) ?? fallback;
    return UserSettings(
      accountPrivacy: str('account_privacy', d.accountPrivacy),
      friendsFeedActivity: flag('friends_feed_activity', d.friendsFeedActivity),
      messagesAudience: str('messages_audience', d.messagesAudience),
      tagsAudience: str('tags_audience', d.tagsAudience),
      commentsAudience: str('comments_audience', d.commentsAudience),
      sharingReuse: flag('sharing_reuse', d.sharingReuse),
      limitInteractions: str('limit_interactions', d.limitInteractions),
      hiddenWords: flag('hidden_words', d.hiddenWords),
      pushNotifications: flag('push_notifications', d.pushNotifications),
      likeNotifications: flag('like_notifications', d.likeNotifications),
      commentNotifications: flag('comment_notifications', d.commentNotifications),
      followNotifications: flag('follow_notifications', d.followNotifications),
    );
  }

  Map<String, dynamic> toMap() => {
        'account_privacy': accountPrivacy,
        'friends_feed_activity': friendsFeedActivity,
        'messages_audience': messagesAudience,
        'tags_audience': tagsAudience,
        'comments_audience': commentsAudience,
        'sharing_reuse': sharingReuse,
        'limit_interactions': limitInteractions,
        'hidden_words': hiddenWords,
        'push_notifications': pushNotifications,
        'like_notifications': likeNotifications,
        'comment_notifications': commentNotifications,
        'follow_notifications': followNotifications,
      };

  UserSettings copyWith({
    String? accountPrivacy,
    bool? friendsFeedActivity,
    String? messagesAudience,
    String? tagsAudience,
    String? commentsAudience,
    bool? sharingReuse,
    String? limitInteractions,
    bool? hiddenWords,
    bool? pushNotifications,
    bool? likeNotifications,
    bool? commentNotifications,
    bool? followNotifications,
  }) {
    return UserSettings(
      accountPrivacy: accountPrivacy ?? this.accountPrivacy,
      friendsFeedActivity: friendsFeedActivity ?? this.friendsFeedActivity,
      messagesAudience: messagesAudience ?? this.messagesAudience,
      tagsAudience: tagsAudience ?? this.tagsAudience,
      commentsAudience: commentsAudience ?? this.commentsAudience,
      sharingReuse: sharingReuse ?? this.sharingReuse,
      limitInteractions: limitInteractions ?? this.limitInteractions,
      hiddenWords: hiddenWords ?? this.hiddenWords,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      likeNotifications: likeNotifications ?? this.likeNotifications,
      commentNotifications: commentNotifications ?? this.commentNotifications,
      followNotifications: followNotifications ?? this.followNotifications,
    );
  }
}

/// Loads and saves settings and blocked accounts. Cache first, then server.
class SettingsRepository {
  SettingsRepository._();
  static final SettingsRepository instance = SettingsRepository._();

  final LocalCache _cache = LocalCache.instance;

  SupabaseClient get _db => Supabase.instance.client;
  String? get _meOrNull => _db.auth.currentUser?.id;

  Future<UserSettings?> cachedSettings() async {
    final raw = await _cache.read('cache.settings');
    if (raw is! Map) return null;
    return UserSettings.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Asks the server. Falls back to the cached copy (or defaults) if the request fails.
  Future<UserSettings> loadSettings() async {
    final me = _meOrNull;
    if (me == null) return UserSettings.defaults();
    try {
      final row = await _db.from('user_settings').select().eq('user_id', me).maybeSingle();
      final settings = row == null ? UserSettings.defaults() : UserSettings.fromMap(row);
      await _cache.write('cache.settings', settings.toMap());
      return settings;
    } catch (_) {
      return await cachedSettings() ?? UserSettings.defaults();
    }
  }

  /// Saves to the phone first, then to the server. Throws if the server rejects it.
  Future<void> saveSettings(UserSettings settings) async {
    final me = _meOrNull;
    if (me == null) throw StateError('Please sign in.');
    await _cache.write('cache.settings', settings.toMap());
    await _db.from('user_settings').upsert({
      'user_id': me,
      ...settings.toMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Profiles of accounts the signed-in user has blocked.
  Future<List<Map<String, dynamic>>> loadBlocked() async {
    final me = _meOrNull;
    if (me == null) return [];
    final rows = await _db.from('blocked_users').select('blocked').eq('blocker', me);
    final ids = rows.map((r) => r['blocked'].toString()).toList();
    if (ids.isEmpty) return [];
    final profiles = await _db
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .inFilter('id', ids);
    return profiles.map((p) => Map<String, dynamic>.from(p)).toList();
  }

  Future<int> blockedCount() async {
    final me = _meOrNull;
    if (me == null) return 0;
    final rows = await _db.from('blocked_users').select('blocked').eq('blocker', me);
    return rows.length;
  }

  Future<void> unblock(String userId) async {
    final me = _meOrNull;
    if (me == null) throw StateError('Please sign in.');
    await _db.from('blocked_users').delete().eq('blocker', me).eq('blocked', userId);
  }
}
