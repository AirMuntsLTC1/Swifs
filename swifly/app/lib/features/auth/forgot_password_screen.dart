import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import 'auth_widgets.dart';

/// Email -> 6-digit code -> new password. Signs the user in at the end.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _step = 0;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _emailValue => _email.text.trim().toLowerCase();

  Future<void> _run(Future<void> Function() action, {int? nextStep}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && nextStep != null) setState(() => _step = nextStep);
    } on AuthError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() {
    if (!_emailValue.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return Future.value();
    }
    return _run(() => AuthService.sendResetCode(_emailValue), nextStep: 1);
  }

  Future<void> _verify(String code) =>
      _run(() => AuthService.checkCode(email: _emailValue, code: code, purpose: 'password_reset'), nextStep: 2);

  Future<void> _savePassword() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    await _run(() => AuthService.resetPassword(email: _emailValue, password: _password.text));
    // The AuthGate shows the app once the new session is set.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _content() {
    switch (_step) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthTitle(
              title: 'Find your account',
              subtitle: "Enter the email for your account. We'll send you a code to reset your password.",
            ),
            const SizedBox(height: 28),
            AuthField(
              controller: _email,
              hint: 'Email',
              keyboard: TextInputType.emailAddress,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            AuthErrorText(message: _error),
            const SizedBox(height: 16),
            AuthButton(
              label: 'Send code',
              busy: _busy,
              onPressed: _emailValue.isEmpty ? null : _sendCode,
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTitle(
              title: 'Enter the code',
              subtitle: 'We sent a 6-digit code to $_emailValue.',
            ),
            const SizedBox(height: 28),
            CodeEntry(
              email: _emailValue,
              busy: _busy,
              error: _error,
              onComplete: _verify,
              onResend: () => AuthService.sendResetCode(_emailValue),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthTitle(title: 'Create a new password', subtitle: 'Use at least 8 characters.'),
            const SizedBox(height: 28),
            AuthField(
              controller: _password,
              hint: 'New password',
              obscure: _hidePassword,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              suffix: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: kAuthMuted),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            AuthErrorText(message: _error),
            const SizedBox(height: 16),
            AuthButton(
              label: 'Save password',
              busy: _busy,
              onPressed: _password.text.isEmpty || _busy ? null : _savePassword,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kAuthInk, size: 20),
          onPressed: _busy ? null : () => _step == 0 ? Navigator.pop(context) : setState(() {
                _step--;
                _error = null;
              }),
        ),
        title: AuthProgress(step: _step, total: 3),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _content(),
          ),
        ),
      ),
    );
  }
}


