import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One live connection for the signed-in user.
///
/// - Every change to a watched table is announced on [changes] with the table name,
///   so screens can refresh themselves.
/// - New follows, likes, comments, and similar activity show as phone notifications.
/// - New direct messages show as phone notifications (sender name and text).
///
/// Started and stopped by the auth listener in main.dart, so it also works after a login
/// made while the app is open.
class RealtimeHub {
  static final RealtimeHub instance = RealtimeHub._();
  RealtimeHub._();

  static const MethodChannel _channel = MethodChannel('com.swifs.native/notifications');

  /// Tables the app listens to. RLS on the server still decides what each user receives.
  static const List<String> watchedTables = [
    'posts', 'post_media', 'post_likes', 'post_saves', 'comments', 'comment_likes',
    'follows', 'profiles', 'stories', 'story_views', 'story_reactions', 'story_replies',
    'messages', 'message_reactions', 'message_hidden', 'groups', 'group_members',
    'blocked_users', 'restricted_users', 'notes',
  ];

  final StreamController<String> _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

  RealtimeChannel? _channelRef;
  String? _userId;
  bool _permissionAsked = false;

  bool get isRunning => _channelRef != null;

  /// Connects for the signed-in user. Does nothing if already connected for that user.
  void start() {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    if (_channelRef != null && _userId == me) return;
    stop();
    _askPermission();

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

    // Activity notifications (follow, like, comment, reaction, reply).
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: me),
      callback: (payload) {
        _changes.add('notifications');
        final record = payload.newRecord;
        // Messages get their own notification below, so skip any message-type row to avoid two.
        if (record['type'] == 'message') return;
        _showActivity(record);
      },
    );

    // Direct messages sent to me.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'recipient', value: me),
      callback: (payload) {
        _changes.add('messages');
        _showMessage(payload.newRecord);
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

  /// Android 13+ only shows notifications after the user allows them. Ask once.
  Future<void> _askPermission() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    try {
      final status = await Permission.notification.request();
      debugPrint('Notification permission: $status');
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  // ------------------------------------------------------------------
  // Phone notifications
  // ------------------------------------------------------------------

  /// Follow, like, comment, reaction, reply and similar activity.
  Future<void> _showActivity(Map<String, dynamic> record) async {
    final type = (record['type'] ?? '').toString();
    final actor = _nameOf(record['actor_name'], record['actor_handle']);
    final action = switch (type) {
      'follow' => 'started following you',
      'follow_accept' => 'accepted your follow request',
      'follow_request' => 'asked to follow you',
      'like' => 'liked your post',
      'comment' => 'commented on your post',
      'save' => 'saved your post',
      'story_reaction' || 'reaction' => 'reacted to your story ${_emojiOf(record)}',
      'story_reply' => 'replied to your story',
      _ => 'sent you a notification',
    };
    await _post(
      title: actor,
      body: action,
      avatarUrl: record['avatar_url']?.toString(),
    );
  }

  /// A new direct message. Shows the sender's name and the message text.
  Future<void> _showMessage(Map<String, dynamic> record) async {
    final senderId = record['sender']?.toString();
    if (senderId == null || senderId == _userId) return;

    var name = 'New message';
    String? avatar;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();
      if (row != null) {
        name = _nameOf(row['display_name'], row['username']);
        avatar = row['avatar_url']?.toString();
      }
    } catch (e) {
      debugPrint('Could not load sender for notification: $e');
    }

    final text = (record['text'] ?? '').toString().trim();
    final body = text.isNotEmpty
        ? text
        : (record['shared_post_id'] != null ? 'Shared a post with you' : 'Sent you a message');
    await _post(title: name, body: body, avatarUrl: avatar);
  }

  String _nameOf(Object? name, Object? handle) {
    final n = (name ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final h = (handle ?? '').toString().trim();
    return h.isNotEmpty ? '@$h' : 'Someone';
  }

  String _emojiOf(Map<String, dynamic> record) {
    final e = (record['emoji'] ?? '').toString();
    return e;
  }

  /// Sends one notification to the native side. Errors are logged, not hidden.
  Future<void> _post({required String title, required String body, String? avatarUrl}) async {
    try {
      await _channel.invokeMethod('showNotification', {
        // A unique id per notification, so a new one never replaces an older one.
        'id': DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
        'title': title,
        'body': body,
        'avatarUrl': avatarUrl,
      });
    } catch (e) {
      debugPrint('Native notification failed: $e');
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
