import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeNotificationService {
  static final RealtimeNotificationService instance = RealtimeNotificationService._();
  RealtimeNotificationService._();

  static const MethodChannel _channel = MethodChannel('com.swifs.native/notifications');

  RealtimeChannel? _channelSub;
  int _notifId = 0;

  void startListening() {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;

    // Listen to the Supabase notifications table for this user
    _channelSub = Supabase.instance.client
        .channel('realtime-notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            _triggerNativeNotification(newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _triggerNativeNotification(Map<String, dynamic> record) async {
    final type = record['type'];
    final actorHandle = record['actor_handle'] ?? 'Someone';
    final actorName = record['actor_name'] ?? '';
    final avatarUrl = record['avatar_url']; // Ensure your trigger passes this

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
      // Native method failed
    }
  }

  void stopListening() {
    _channelSub?.unsubscribe();
  }
}
