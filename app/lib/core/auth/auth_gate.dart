import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/login_screen.dart';

/// Shows the app when someone is signed in, and the login screen when not.
/// Uses the current session on the first frame, so there is no flash of the login screen.
class AuthGate extends StatelessWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        return session != null ? child : const LoginScreen();
      },
    );
  }
}
