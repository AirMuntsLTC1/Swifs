import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A message the user can read. [status] is the HTTP status (for example 409 = username taken).
class AuthError implements Exception {
  final String message;
  final int? status;
  final int? retryAfter;

  const AuthError(this.message, {this.status, this.retryAfter});

  @override
  String toString() => message;
}

/// Talks to the existing `email-code-auth` edge function.
class AuthService {
  AuthService._();

  static const String _function = 'email-code-auth';

  /// Letters and numbers added after the name: wilmeolid_fhr23 has 3 letters and 2 numbers.
  static const int usernameLetters = 3;
  static const int usernameDigits = 2;

  static const String _letters = 'abcdefghijklmnopqrstuvwxyz';
  static const String _digits = '0123456789';

  static SupabaseClient get _client => Supabase.instance.client;

  /// "Wilme" + "Olid" -> "wilmeolid_fhr23"
  static String generateUsername(String firstName, String lastName, {Random? random}) {
    final r = random ?? Random.secure();
    String clean(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    var base = clean(firstName) + clean(lastName);
    if (base.isEmpty) base = 'user';
    if (base.length > 22) base = base.substring(0, 22);

    final letters = List.generate(usernameLetters, (_) => _letters[r.nextInt(_letters.length)]).join();
    final digits = List.generate(usernameDigits, (_) => _digits[r.nextInt(_digits.length)]).join();
    return '${base}_$letters$digits';
  }

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(_function, body: body);
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on FunctionException catch (e) {
      final details = e.details;
      final map = details is Map ? Map<String, dynamic>.from(details) : <String, dynamic>{};
      final retry = map['retry_after'];
      throw AuthError(
        map['error']?.toString() ?? 'Something went wrong. Try again.',
        status: e.status,
        retryAfter: retry is num ? retry.toInt() : null,
      );
    } catch (_) {
      throw const AuthError("No connection. Check your internet and try again.");
    }
  }

  /// Signs the user in with the session the function returns.
  static Future<void> _adopt(Map<String, dynamic> data) async {
    final session = data['session'];
    final refresh = session is Map ? session['refresh_token']?.toString() : null;
    if (refresh == null) throw const AuthError('Could not sign you in. Please log in.');
    await _client.auth.setSession(refresh);
  }

  static Future<void> login({required String email, required String password}) async {
    final data = await _call({'action': 'login', 'email': email, 'password': password});
    await _adopt(data);
  }

  /// Step 2 of sign-up: emails a code. The username is checked for availability here.
  static Future<void> sendSignupCode({
    required String email,
    required String username,
    required String displayName,
    required String firstName,
    required String lastName,
  }) async {
    await _call({
      'action': 'send_code',
      'purpose': 'signup',
      'email': email,
      'username': username,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
    });
  }

  static Future<void> sendResetCode(String email) async {
    await _call({'action': 'send_code', 'purpose': 'password_reset', 'email': email});
  }

  /// Checks the 6-digit code. Does not need a password.
  static Future<void> checkCode({required String email, required String code, required String purpose}) async {
    await _call({'action': 'check_code', 'email': email, 'code': code, 'purpose': purpose});
  }

  /// Last step of sign-up: creates the account and signs in.
  static Future<void> createAccount({required String email, required String password}) async {
    final data = await _call({'action': 'create_account', 'email': email, 'password': password});
    await _adopt(data);
  }

  /// Last step of forgot password: sets the new password and signs in.
  static Future<void> resetPassword({required String email, required String password}) async {
    final data = await _call({'action': 'reset_password', 'email': email, 'password': password});
    await _adopt(data);
  }

  static Future<void> signOut() => _client.auth.signOut();
}
