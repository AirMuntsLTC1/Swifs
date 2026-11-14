import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _FeedScoreNative = Int32 Function(Int32, Int32, Int32, Int32);
typedef _FeedScoreDart = int Function(int, int, int, int);
typedef _HashUserNative = Int32 Function(Pointer<Utf8>);
typedef _HashUserDart = int Function(Pointer<Utf8>);

class SwifsCore {
  static DynamicLibrary? _lib;

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

  static int feedScore(int likes, int comments, int views, int ageMinutes) {
    final fn = lib.lookupFunction<_FeedScoreNative, _FeedScoreDart>('swifs_feed_score');
    return fn(likes, comments, views, ageMinutes);
  }

  static int hashUser(String name) {
    final fn = lib.lookupFunction<_HashUserNative, _HashUserDart>('swifs_hash_user');
    final ptr = name.toNativeUtf8();
    try { return fn(ptr); } finally { malloc.free(ptr); }
  }
}
