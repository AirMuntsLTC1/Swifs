import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _FeedScoreNative = Int32 Function(Int32, Int32, Int32, Int32);
typedef _FeedScoreDart = int Function(int, int, int, int);
typedef _CommentScoreNative = Int32 Function(Int32, Int32, Int32);
typedef _CommentScoreDart = int Function(int, int, int);
typedef _HashUserNative = Int32 Function(Pointer<Utf8>);
typedef _HashUserDart = int Function(Pointer<Utf8>);

/// Raw calls into libswifs_core (app/native/src/swifs_core.cpp).
///
/// Symbols are looked up once and kept in static fields. Looking them up on
/// every call (as before) costs a dlsym per score, which adds up across a feed.
class SwifsCore {
  static DynamicLibrary? _lib;
  static _FeedScoreDart? _feedFn;
  static _CommentScoreDart? _commentFn;
  static _HashUserDart? _hashFn;

  static DynamicLibrary get lib {
    if (_lib != null) return _lib!;
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libswifs_core.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      _lib = DynamicLibrary.open('./build/swifs_core.so');
    }
    return _lib!;
  }

  static _FeedScoreDart get _feed =>
      _feedFn ??= lib.lookupFunction<_FeedScoreNative, _FeedScoreDart>('swifs_feed_score');

  static _CommentScoreDart get _comment =>
      _commentFn ??= lib.lookupFunction<_CommentScoreNative, _CommentScoreDart>('swifs_comment_score');

  static _HashUserDart get _hash =>
      _hashFn ??= lib.lookupFunction<_HashUserNative, _HashUserDart>('swifs_hash_user');

  static int feedScore(int likes, int comments, int views, int ageMinutes) =>
      _feed(likes, comments, views, ageMinutes);

  static int commentScore(int likes, int replies, int ageMinutes) =>
      _comment(likes, replies, ageMinutes);

  static int hashUser(String name) {
    final ptr = name.toNativeUtf8();
    try {
      return _hash(ptr);
    } finally {
      malloc.free(ptr);
    }
  }
}

/// What the app uses. Calls the C++ core. If the native library is missing,
/// it runs the same formula in Dart. The parity test keeps all three equal.
class SwifsScore {
  static int feed(int likes, int comments, int views, int ageMinutes) {
    try {
      return SwifsCore.feedScore(likes, comments, views, ageMinutes);
    } catch (_) {
      final age = ageMinutes < 1 ? 1 : ageMinutes;
      return (likes * 3 + comments * 5 + views) ~/ (age + 1);
    }
  }

  static int comment(int likes, int replies, int ageMinutes) {
    try {
      return SwifsCore.commentScore(likes, replies, ageMinutes);
    } catch (_) {
      final age = ageMinutes < 1 ? 1 : ageMinutes;
      return ((likes * 2 + replies * 3) * 100) ~/ (age + 1);
    }
  }

  static int userHash(String name) {
    try {
      return SwifsCore.hashUser(name);
    } catch (_) {
      var h = 2166136261;
      for (final b in utf8.encode(name)) {
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF;
      }
      return h & 0x7FFFFFFF;
    }
  }
}
