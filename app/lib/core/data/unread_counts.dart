import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/realtime_notification_service.dart';

/// Unread counts for the bell (notifications) and the Messages tab (direct messages).
/// They update live from realtime and reload when the app comes back to the foreground.
class UnreadCounts {
  static final UnreadCounts instance = UnreadCounts._();
  UnreadCounts._();

  /// Capped at 100 per list, which the badge shows as 99+.
  final ValueNotifier<int> notifications = ValueNotifier<int>(0);
  final ValueNotifier<int> messages = ValueNotifier<int>(0);

  StreamSubscription<String>? _sub;
  Timer? _debounce;

  void start() {
    _sub ??= RealtimeHub.instance.changes.listen((table) {
      if (table == 'notifications' || table == 'messages' || table == 'resume') _schedule();
    });
    refresh();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    notifications.value = 0;
    messages.value = 0;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), refresh);
  }

  Future<void> refresh() async {
    final db = Supabase.instance.client;
    final me = db.auth.currentUser?.id;
    if (me == null) return;
    try {
      final n = await db
          .from('notifications')
          .select('id')
          .eq('user_id', me)
          .eq('read', false)
          .neq('type', 'message')
          .limit(100);
      final m = await db
          .from('messages')
          .select('id')
          .eq('recipient', me)
          .isFilter('read_at', null)
          .limit(100);
      notifications.value = n.length;
      messages.value = m.length;
    } catch (_) {
      // Offline or signed out: keep the last numbers.
    }
  }

  /// Opening the notifications screen clears the bell count.
  Future<void> markAllNotificationsRead() async {
    final db = Supabase.instance.client;
    final me = db.auth.currentUser?.id;
    if (me == null) return;
    try {
      await db.from('notifications').update({'read': true}).eq('user_id', me).eq('read', false);
      notifications.value = 0;
    } catch (_) {
      // Try again next time the screen opens.
    }
  }
}
