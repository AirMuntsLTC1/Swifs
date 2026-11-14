import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../push/push_service.dart';

/// One live connection for the signed-in user.
///
/// - Every change to a watched table is announced on [changes] so screens can refresh themselves.
/// - New messages show as "New Message" with the sender's circle photo.
/// - Follows, follow requests, accepted requests, likes, comments and reactions show as
///   "New Follower", "Follow Request", "Request Accepted", and so on, with the person's circle photo.
///
/// Started and stopped by the auth listener in main.dart, so it also works after a login made
/// while the app is open.
class RealtimeHub {
  static final RealtimeHub instance = RealtimeHub._();
  RealtimeHub._();

  static const MethodChannel _channel = MethodChannel('com.swifs.native/notifications');

  /// Tables the app listens to. RLS on the server still decides what each user receives.
  static const List<String> watchedTables = [
    'posts', 'post_media', 'post_likes', 'post_saves', 'comments', 'comment_likes',
    'follows', 'profiles', 'stories', 'story_views', 'story_reactions', 'story_replies',
    'message_reactions', 'message_hidden', 'groups', 'group_members',
    'blocked_users', 'restricted_users', 'notes',
  ];

  final StreamController<String> _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

  RealtimeChannel? _channelRef;
  String? _userId;
  bool _permissionAsked = false;
  Timer? _restartTimer;

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

    // Messages and notifications: inserts have their own bindings below, which show the
    // phone notification. Updates and deletes only refresh the screens (read receipts,
    // unsends, badge counts), so they get separate bindings here. Each table has one
    // binding per event type.
    for (final table in const ['messages', 'notifications']) {
      for (final event in const [PostgresChangeEvent.update, PostgresChangeEvent.delete]) {
        channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          callback: (_) => _changes.add(table),
        );
      }
    }

    // Activity: follows, requests, accepted requests, likes, comments, reactions, replies.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: me),
      callback: (payload) {
        _changes.add('notifications');
        final record = payload.newRecord;
        // Messages are announced from the messages table below, so skip message rows here.
        if (record['type'] == 'message') return;
        _showActivity(record);
      },
    );

    // Direct and group messages. RLS limits what arrives to chats I belong to.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        _changes.add('messages');
        _showMessage(payload.newRecord);
      },
    );

    channel.subscribe(_onStatus);
    _channelRef = channel;
    unawaited(PushService.instance.register());
  }

  /// Logs the connection state and reconnects if the channel fails or times out.
  void _onStatus(RealtimeSubscribeStatus status, Object? error) {
    debugPrint('Realtime status: $status${error == null ? '' : ' ($error)'}');
    if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut ||
        status == RealtimeSubscribeStatus.closed) {
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(seconds: 3), () {
        _channelRef = null;
        _userId = null;
        start();
      });
    }
  }

  /// Rebuilds the live connection and tells open screens to reload.
  void restart() {
    stop();
    _channelRef = null;
    _userId = null;
    start();
    _changes.add('resume');
  }

  /// Disconnects (on sign-out).
  void stop() {
    _restartTimer?.cancel();
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

  /// Follows, requests, accepted requests, likes, comments, saves, reactions and replies.
  Future<void> _showActivity(Map<String, dynamic> record) async {
    final type = (record['type'] ?? '').toString();
    final who = _displayName(record['actor_name'], record['actor_handle']);
    final preview = (record['preview'] ?? '').toString().trim();
    final emoji = (record['emoji'] ?? '').toString().trim();

    final (title, body) = switch (type) {
      'follow' => ('New Follower', '$who started following you'),
      'follow_request' => ('Follow Request', '$who wants to follow you'),
      'follow_accept' => ('Request Accepted', '$who accepted your follow request'),
      'like' => ('New Like', '$who liked your post'),
      'comment' => ('New Comment', preview.isEmpty ? '$who commented on your post' : '$who: $preview'),
      'save' => ('Post Saved', '$who saved your post'),
      'story_reaction' || 'reaction' => (
          'Story Reaction',
          emoji.isEmpty ? '$who reacted to your story' : '$who reacted $emoji to your story',
        ),
      'story_reply' => ('Story Reply', preview.isEmpty ? '$who replied to your story' : '$who: $preview'),
      _ => ('New Activity', '$who sent you a notification'),
    };

    var avatar = record['avatar_url']?.toString();
    if (avatar == null || avatar.isEmpty) {
      avatar = await _avatarByHandle(record['actor_handle']?.toString());
    }
    await _post(title: title, body: body, avatarUrl: avatar);
  }

  /// A new direct message: title "New Message", the sender's circle photo, and "Name: text".
  Future<void> _showMessage(Map<String, dynamic> record) async {
    final senderId = record['sender']?.toString();
    if (senderId == null || senderId == _userId) return;

    var name = 'Someone';
    String? avatar;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();
      if (row != null) {
        name = _displayName(row['display_name'], row['username']);
        avatar = row['avatar_url']?.toString();
      }
    } catch (e) {
      debugPrint('Could not load sender for notification: $e');
    }

    final text = (record['text'] ?? '').toString().trim();
    final detail = text.isNotEmpty
        ? text
        : (record['shared_post_id'] != null ? 'Shared a post with you' : 'Sent you a message');
    await _post(title: 'New Message', body: '$name: $detail', avatarUrl: avatar);
  }

  /// The profile photo for a username, used when the notification row has none.
  Future<String?> _avatarByHandle(String? handle) async {
    if (handle == null || handle.isEmpty) return null;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('username', handle)
          .maybeSingle();
      return row?['avatar_url']?.toString();
    } catch (_) {
      return null;
    }
  }

  String _displayName(Object? name, Object? handle) {
    final n = (name ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final h = (handle ?? '').toString().trim();
    return h.isNotEmpty ? '@$h' : 'Someone';
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
