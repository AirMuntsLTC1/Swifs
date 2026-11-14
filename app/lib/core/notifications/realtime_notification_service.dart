import 'dart:async';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One live connection for the signed-in user.
///
/// Every change to a watched table is announced on [changes] with the table name, so any screen can
/// refresh itself: `RealtimeHub.instance.changes.listen((table) { ... })`.
/// New notifications also show as a phone notification.
///
/// Started and stopped by the auth listener in main.dart, so it works for a login after launch too.
class RealtimeHub {
  static final RealtimeHub instance = RealtimeHub._();
  RealtimeHub._();

  static const MethodChannel _channel = MethodChannel('com.swifs.native/notifications');

  /// Tables the app listens to. RLS on the server still decides what each user receives.
  static const List<String> watchedTables = [
    'posts',
    'post_media',
    'post_likes',
    'post_saves',
    'comments',
    'comment_likes',
    'follows',
    'profiles',
    'stories',
    'story_views',
    'story_reactions',
    'story_replies',
    'messages',
    'message_reactions',
    'message_hidden',
    'groups',
    'group_members',
    'blocked_users',
    'restricted_users',
    'notes',
  ];

  final StreamController<String> _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

  RealtimeChannel? _channelRef;
  String? _userId;
  int _notifId = 0;

  bool get isRunning => _channelRef != null;

  /// Connects for the signed-in user. Does nothing if already connected for that user.
  void start() {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    if (_channelRef != null && _userId == me) return;
    stop();

    _userId = me;
    final channel = client.channel('swifs-live-$me');
    for (final table in watchedTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _changes.add(table),
      );
    }
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: me),
      callback: (payload) {
        _changes.add('notifications');
        _showNative(payload.newRecord);
      },
    );
    channel.subscribe();
    _channelRef = channel;
  }

  /// Disconnects (on sign-out).
  void stop() {
    final ch = _channelRef;
    _channelRef = null;
    _userId = null;
    if (ch != null) {
      Supabase.instance.client.removeChannel(ch);
    }
  }

  Future<void> _showNative(Map<String, dynamic> record) async {
    final type = record['type'];
    final actorHandle = record['actor_handle'] ?? 'Someone';
    final actorName = record['actor_name'] ?? '';
    final avatarUrl = record['avatar_url'];

    String title = 'New follower';
    String body = '$actorName ($actorHandle) started following you.';

    if (type == 'follow_accept') {
      title = 'Follow request accepted';
      body = '$actorName ($actorHandle) accepted your follow request.';
    } else if (type == 'message') {
      title = 'New message';
      final preview = record['preview'] ?? 'Sent you a message.';
      body = '$actorName: $preview';
    }

    _notifId++;
    try {
      await _channel.invokeMethod('showNotification', {
        'id': _notifId,
        'title': title,
        'body': body,
        'avatarUrl': avatarUrl,
      });
    } catch (_) {
      // The native side is not available. The in-app list still updates.
    }
  }
}

/// Kept so older call sites still compile. New code should use [RealtimeHub].
class RealtimeNotificationService {
  static final RealtimeNotificationService instance = RealtimeNotificationService._();
  RealtimeNotificationService._();

  void startListening() => RealtimeHub.instance.start();
  void stopListening() => RealtimeHub.instance.stop();
}
