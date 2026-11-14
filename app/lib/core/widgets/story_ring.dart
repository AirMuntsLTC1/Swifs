import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color kStoryBlue = Color(0xFF1877F2);
const Color kStoryTrack = Color(0xFFD0D3D9);

/// A ring around a profile photo.
/// - [uploadProgress] set (0..1): a blue arc fills clockwise while the story is shared.
/// - [seen] true: grey ring (everything already watched).
/// - otherwise: full blue ring (new story to watch).
class StoryRing extends StatelessWidget {
  final Widget child;
  final double size;
  final bool seen;
  final double? uploadProgress;

  const StoryRing({
    super.key,
    required this.child,
    this.size = 68,
    this.seen = false,
    this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StoryRingPainter(seen: seen, progress: uploadProgress),
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: ClipOval(child: child),
        ),
      ),
    );
  }
}

class _StoryRingPainter extends CustomPainter {
  final bool seen;
  final double? progress;

  _StoryRingPainter({required this.seen, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.06;
    final rect = (Offset.zero & size).deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = kStoryTrack;
    final blue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = kStoryBlue;

    if (progress != null) {
      final p = progress!.clamp(0.0, 1.0).toDouble();
      canvas.drawArc(rect, 0, 2 * math.pi, false, track);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * p, false, blue);
    } else if (seen) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    } else {
      canvas.drawArc(rect, 0, 2 * math.pi, false, blue);
    }
  }

  @override
  bool shouldRepaint(covariant _StoryRingPainter old) =>
      old.seen != seen || old.progress != progress;
}
