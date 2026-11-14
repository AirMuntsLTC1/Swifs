import 'dart:async';
import 'package:flutter/material.dart';

const Color kAuthOrange = Color(0xFFFF6B35);
const Color kAuthInk = Color(0xFF111111);
const Color kAuthMuted = Color(0xFF8E8E93);
const Color kAuthFill = Color(0xFFF3F3F5);

/// Big title and short line under it, Facebook style.
class AuthTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AuthTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kAuthInk, height: 1.2)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: const TextStyle(fontSize: 15, color: kAuthMuted, height: 1.4)),
        ],
      ],
    );
  }
}

/// Rounded input with a light fill and no border.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;
  final bool autofocus;
  final TextCapitalization capitalization;
  final TextInputAction? action;
  final VoidCallback? onSubmitted;
  final int? maxLength;
  final TextAlign align;
  final double fontSize;
  final TextStyle? textStyle;
  final ValueChanged<String>? onChanged;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboard,
    this.obscure = false,
    this.suffix,
    this.autofocus = false,
    this.capitalization = TextCapitalization.none,
    this.action,
    this.onSubmitted,
    this.maxLength,
    this.align = TextAlign.start,
    this.fontSize = 16,
    this.textStyle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      textInputAction: action,
      maxLength: maxLength,
      textAlign: align,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: textStyle ?? TextStyle(fontSize: fontSize, color: kAuthInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kAuthMuted, fontSize: 16),
        counterText: '',
        filled: true,
        fillColor: kAuthFill,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: _border,
        enabledBorder: _border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: kAuthOrange, width: 1.5),
        ),
      ),
    );
  }

  static final OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(28),
    borderSide: BorderSide.none,
  );
}

/// Full-width rounded orange button. Shows a spinner while [busy].
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;

  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    final child = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: kAuthOrange,
            side: const BorderSide(color: kAuthOrange, width: 1.4),
            shape: shape,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAuthOrange,
          disabledBackgroundColor: const Color(0xFFFFD2C2),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: shape,
        ),
        child: child,
      ),
    );
  }
}

/// Thin bar at the top of a multi-step flow.
class AuthProgress extends StatelessWidget {
  final int step;
  final int total;

  const AuthProgress({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (step + 1) / total,
        minHeight: 4,
        backgroundColor: kAuthFill,
        color: kAuthOrange,
      ),
    );
  }
}

/// Red error line under a form. Empty when [message] is null.
class AuthErrorText extends StatelessWidget {
  final String? message;

  const AuthErrorText({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(message!, style: const TextStyle(color: Color(0xFFD93025), fontSize: 14, height: 1.3)),
    );
  }
}

/// Six-digit code entry with resend and a cooldown.
/// Calls [onComplete] as soon as 6 digits are typed.
class CodeEntry extends StatefulWidget {
  final String email;
  final bool busy;
  final String? error;
  final ValueChanged<String> onComplete;
  final Future<void> Function() onResend;

  const CodeEntry({
    super.key,
    required this.email,
    required this.busy,
    required this.error,
    required this.onComplete,
    required this.onResend,
  });

  @override
  State<CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends State<CodeEntry> {
  final TextEditingController _code = TextEditingController();
  Timer? _timer;
  int _cooldown = 60;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _resend() async {
    _code.clear();
    try {
      await widget.onResend();
    } catch (_) {
      // Shown as a network problem next time the user tries.
    }
    if (mounted) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthField(
          controller: _code,
          hint: '••••••',
          keyboard: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          align: TextAlign.center,
          fontSize: 28,
          textStyle: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w600, color: kAuthInk),
          onChanged: (value) {
            setState(() {});
            if (value.length == 6 && !widget.busy) widget.onComplete(value);
          },
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: (_cooldown > 0 || widget.busy) ? null : _resend,
            child: Text(
              _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
              style: TextStyle(color: _cooldown > 0 ? kAuthMuted : kAuthOrange, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        AuthErrorText(message: widget.error),
        const SizedBox(height: 16),
        AuthButton(
          label: 'Next',
          busy: widget.busy,
          onPressed: _code.text.length == 6 ? () => widget.onComplete(_code.text) : null,
        ),
      ],
    );
  }
}


