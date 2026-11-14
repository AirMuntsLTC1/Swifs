import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import 'auth_widgets.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit => _email.text.trim().isNotEmpty && _password.text.isNotEmpty && !_busy;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.login(email: _email.text.trim().toLowerCase(), password: _password.text);
      // On success the AuthGate replaces this screen with the app.
    } on AuthError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: kAuthOrange, borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 20),
                    const Text('Swifs', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: kAuthOrange)),
                    const SizedBox(height: 36),
                    AuthField(
                      controller: _email,
                      hint: 'Email',
                      keyboard: TextInputType.emailAddress,
                      action: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    AuthField(
                      controller: _password,
                      hint: 'Password',
                      obscure: _hidePassword,
                      action: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _canSubmit ? _login : null,
                      suffix: IconButton(
                        icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: kAuthMuted),
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    AuthErrorText(message: _error),
                    const SizedBox(height: 16),
                    AuthButton(label: 'Log in', busy: _busy, onPressed: _canSubmit ? _login : null),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => _open(const ForgotPasswordScreen()),
                      child: const Text('Forgotten password?', style: TextStyle(color: kAuthOrange, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    const Divider(height: 32, color: Color(0xFFEFEFEF)),
                    AuthButton(
                      label: 'Create new account',
                      outlined: true,
                      onPressed: _busy ? null : () => _open(const CreateAccountScreen()),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
