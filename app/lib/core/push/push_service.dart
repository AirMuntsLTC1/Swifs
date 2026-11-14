import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Saves this phone's Firebase token so the server can send push when the app is closed.
/// Errors are logged and never block sign-in.
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  bool _firebaseReady = false;
  StreamSubscription<String>? _refreshSub;

  Future<void> register() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;
    try {
      if (!_firebaseReady) {
        await Firebase.initializeApp();
        _firebaseReady = true;
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(); // Android 13+ asks once
      final token = await messaging.getToken();
      if (token != null) await _save(token);
      _refreshSub ??= messaging.onTokenRefresh.listen(_save);
    } catch (e) {
      debugPrint('Push registration skipped: $e');
    }
  }

  Future<void> _save(String token) async {
    try {
      await Supabase.instance.client.rpc('register_device', params: {
        'p_token': token,
        'p_platform': Platform.isAndroid ? 'android' : 'other',
      });
    } catch (e) {
      // Not signed in yet, or offline. The next sign-in or token refresh tries again.
      debugPrint('Could not save device token: $e');
    }
  }
}
