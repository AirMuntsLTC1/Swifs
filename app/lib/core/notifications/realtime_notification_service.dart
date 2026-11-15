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
    // 'messages' is not listed here: it has its own bindings below (insert, update, delete),
    // so every message event reaches the screens exactly once.
    'message_reactions', 'message_hidden', 'groups', 'group_members',
    'blocked_users', 'restricted_users', 'notes',
  ];

  final StreamController<String> _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

  RealtimeChannel? _channelRef;
  String? _userId;
  bool _permissionAsked = false;
  Timer? _restartTimer;
  // Reconnect wait grows with each failed try: 3, 6, 12, 24, 48, then 60 seconds.
  static const List<int> _retryDelays = [3, 6, 12, 24, 48, 60];
  int _attempt = 0;
  // True after a drop (or a forced restart). The next successful connect tells screens to catch up.
  bool _dropped = false;

  bool get isRunning => _channelRef != null;

  /// Connects for the signed-in user. Does nothing if already connected for that user.
  void start() {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    if (_channelRef != null && _userId == me) return;
    _restartTimer?.cancel();
    _detach();
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

    channel.subscribe((status, error) => _onStatus(channel, status, error));
    _channelRef = channel;
    unawaited(PushService.instance.register());
  }

  /// Logs the connection state and retries a dropped connection with a growing wait.
  /// Events from a channel that was already replaced or closed on purpose are ignored.
  void _onStatus(RealtimeChannel channel, RealtimeSubscribeStatus status, Object? error) {
    if (!identical(channel, _channelRef)) return;
    debugPrint('Realtime status: $status${error == null ? '' : ' ($error)'}');

    if (status == RealtimeSubscribeStatus.subscribed) {
      _attempt = 0;
      _restartTimer?.cancel();
      if (_dropped) {
        // Back after a drop: open screens catch up once. Not sent on the very first connect.
        _dropped = false;
        _changes.add('resume');
      }
      return;
    }

    if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut ||
        status == RealtimeSubscribeStatus.closed) {
      _dropped = true;
      _restartTimer?.cancel();
      final i = _attempt < _retryDelays.length ? _attempt : _retryDelays.length - 1;
      _attempt++;
      _restartTimer = Timer(Duration(seconds: _retryDelays[i]), () {
        _detach();
        start();
      });
    }
  }

  /// Rebuilds the live connection, for example after the app returns to the foreground.
  /// The next successful connection tells open screens to catch up.
  void restart() {
    _restartTimer?.cancel();
    _attempt = 0;
    _dropped = true;
    _detach();
    start();
  }

  /// Disconnects (on sign-out).
  void stop() {
    _restartTimer?.cancel();
    _restartTimer = null;
    _attempt = 0;
    _dropped = false;
    _detach();
  }

  /// Removes the current channel. Its close event is ignored by [_onStatus].
  void _detach() {
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
    await _post(title: title, body: body, avatarUrl: avatar, tag: _tagFor('activity', record['id']));
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
    await _post(
      title: 'New Message',
      body: '$name: $detail',
      avatarUrl: avatar,
      tag: _tagFor('message', record['id']),
    );
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

  /// Same tag the server sends with the push, so a phone never shows one event twice.
  String? _tagFor(String prefix, Object? id) =>
      id == null ? null : '$prefix-$id';

  /// Sends one notification to the native side. Errors are logged, not hidden.
  Future<void> _post({
    required String title,
    required String body,
    String? avatarUrl,
    String? tag,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        // A unique id per notification, so a new one never replaces an older one.
        'id': DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
        'title': title,
        'body': body,
        'avatarUrl': avatarUrl,
        'tag': tag,
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
