import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import 'auth_widgets.dart';

/// Facebook-style sign-up, one question per screen:
///   0. Name (display name, first name, last name)
///   1. Email (sends a code)
///   2. Code (checked with the edge function)
///   3. Password, then "Creating your account..." until it is done
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  int _step = 0;
  String _username = '';
  bool _busy = false;
  bool _creating = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
      _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _emailValue => _email.text.trim().toLowerCase();
  bool get _isFirstNameValid => _firstName.text.isEmpty || _firstName.text[0] == _firstName.text[0].toUpperCase();
  bool get _isLastNameValid => _lastName.text.isEmpty || _lastName.text[0] == _lastName.text[0].toUpperCase();
  bool get _nameFilled => _firstName.text.trim().isNotEmpty && _lastName.text.trim().isNotEmpty && _isFirstNameValid && _isLastNameValid;

  void _rebuild() => setState(() {});

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  /// Runs an action with a busy state and a readable error.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } on AuthError catch (e) {
      if (mounted) setState(() => _error = e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_emailPattern.hasMatch(_emailValue)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    // Make a username from the name. If it is taken, make another one.
    _username = _username.isEmpty ? AuthService.generateUsername(_firstName.text, _lastName.text) : _username;

    final sent = await _run(() async {
      for (var attempt = 0;; attempt++) {
        try {
          await AuthService.sendSignupCode(
            email: _emailValue,
            username: _username,
            displayName: '${_firstName.text.trim()} ${_lastName.text.trim()}',
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
          );
          return;
        } on AuthError catch (e) {
          if (e.status == 409 && attempt < 5) {
            _username = AuthService.generateUsername(_firstName.text, _lastName.text);
            continue;
          }
          rethrow;
        }
      }
    });
    if (sent && mounted) setState(() => _step = 2);
  }

  Future<void> _verify(String code) async {
    final ok = await _run(() => AuthService.checkCode(email: _emailValue, code: code, purpose: 'signup'));
    if (ok && mounted) setState(() => _step = 3);
  }

  Future<void> _finish() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await AuthService.createAccount(email: _emailValue, password: _password.text);
      // The AuthGate shows the app now. Close the sign-up screens underneath it.
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthError catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = e.message;
        });
      }
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
              title: "What's your name?",
              subtitle: 'Your display name is how people see you. Your first and last name stay private.',
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _isFirstNameValid ? Colors.transparent : Colors.red, width: 1.5),
                    ),
                    child: AuthField(
                      controller: _firstName,
                      hint: 'First name',
                      capitalization: TextCapitalization.words,
                      action: TextInputAction.next,
                      onChanged: (_) => _rebuild(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _isLastNameValid ? Colors.transparent : Colors.red, width: 1.5),
                    ),
                    child: AuthField(
                      controller: _lastName,
                      hint: 'Last name',
                      capitalization: TextCapitalization.words,
                      action: TextInputAction.next,
                      onChanged: (_) => _rebuild(),
                    ),
                  ),
                ),
              ],
            ),
            AuthErrorText(message: _error),
            const SizedBox(height: 16),
            AuthButton(label: 'Next', onPressed: _nameFilled ? () => setState(() => _step = 1) : null),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthTitle(
              title: "What's your email?",
              subtitle: "We'll send a 6-digit code to check it's you.",
            ),
            const SizedBox(height: 28),
            AuthField(
              controller: _email,
              hint: 'Email',
              keyboard: TextInputType.emailAddress,
              autofocus: true,
              onChanged: (_) => _rebuild(),
            ),
            AuthErrorText(message: _error),
            const SizedBox(height: 16),
            AuthButton(label: 'Next', busy: _busy, onPressed: _emailValue.isEmpty ? null : _sendCode),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTitle(title: 'Enter the code', subtitle: 'We sent a 6-digit code to $_emailValue.'),
            const SizedBox(height: 28),
            CodeEntry(
              email: _emailValue,
              busy: _busy,
              error: _error,
              onComplete: _verify,
              onResend: () => AuthService.sendSignupCode(
                email: _emailValue,
                username: _username,
                displayName: '${_firstName.text.trim()} ${_lastName.text.trim()}',
                firstName: _firstName.text.trim(),
                lastName: _lastName.text.trim(),
              ),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey(3),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTitle(
              title: 'Create a password',
              subtitle: 'Use at least 8 characters. Your username will be @$_username.',
            ),
            const SizedBox(height: 28),
            AuthField(
              controller: _password,
              hint: 'Password',
              obscure: _hidePassword,
              autofocus: true,
              onChanged: (_) => _rebuild(),
              onSubmitted: _password.text.length >= 8 ? _finish : null,
              suffix: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: kAuthMuted),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            AuthErrorText(message: _error),
            const SizedBox(height: 16),
            AuthButton(
              label: 'Create account',
              onPressed: _password.text.length >= 8 ? _finish : null,
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
          onPressed: _back,
        ),
        title: AuthProgress(step: _step, total: 4),
        titleSpacing: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _content(),
              ),
            ),
          ),
          if (_creating) const _CreatingOverlay(),
        ],
      ),
    );
  }
}

/// Full-screen wait while the account is being created.
class _CreatingOverlay extends StatelessWidget {
  const _CreatingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: kAuthOrange),
          ),
          SizedBox(height: 24),
          Text('Creating your account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kAuthInk)),
          SizedBox(height: 6),
          Text('This only takes a moment.', style: TextStyle(fontSize: 14, color: kAuthMuted)),
        ],
      ),
    );
  }
}
