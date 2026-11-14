import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/unread_counts.dart';
import 'realtime_notification_service.dart';

/// When the app returns to the foreground, rebuild the live connection and refresh the badges.
/// Android closes sockets while the app is in the background, so this is what makes live
/// updates resume without reopening the app.
class RealtimeLifecycle with WidgetsBindingObserver {
  static final RealtimeLifecycle instance = RealtimeLifecycle._();
  RealtimeLifecycle._();

  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    RealtimeHub.instance.restart();
    UnreadCounts.instance.refresh();
  }
}
