import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The size of a photo and a small JPEG thumbnail of it.
class ImagePrep {
  final int width;
  final int height;

  /// About 480px wide JPEG. Null if the file could not be decoded.
  final Uint8List? thumbJpeg;

  const ImagePrep(this.width, this.height, this.thumbJpeg);
}

/// Runs in a background isolate. Decoding, rotating and encoding all happen here,
/// so the UI thread never waits on a large photo.
ImagePrep _prepInIsolate(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const ImagePrep(0, 0, null);

    // Apply the EXIF rotation so the thumbnail and size match what the user sees.
    final upright = img.bakeOrientation(decoded);
    final thumb = upright.width > 480
        ? img.copyResize(upright, width: 480)
        : upright;
    final jpg = img.encodeJpg(thumb, quality: 80);

    return ImagePrep(upright.width, upright.height, Uint8List.fromList(jpg));
  } catch (_) {
    return const ImagePrep(0, 0, null);
  }
}

/// Prepares a photo off the UI thread. Safe to await from any screen.
Future<ImagePrep> prepareImage(String path) => compute(_prepInIsolate, path);
