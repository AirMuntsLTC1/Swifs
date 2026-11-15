import 'package:flutter/material.dart';
import '../feedback/swifs_feedback.dart';

/// Instagram-style double tap. Shows a heart burst exactly where the finger
/// landed. [onLike] runs on every double tap; pass [alreadyLiked] so a post
/// that is already liked only replays the burst (it never unlikes).
class DoubleTapLike extends StatefulWidget {
  final Widget child;
  final VoidCallback onLike;
  final bool alreadyLiked;

  const DoubleTapLike({
    super.key,
    required this.child,
    required this.onLike,
    this.alreadyLiked = false,
  });

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Offset _tapAt = Offset.zero;
  bool _visible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _tapAt = details.localPosition;
  }

  void _onDoubleTap() {
    // A new like is felt by the caller's like handler (once). Re-liking only ticks.
    if (!widget.alreadyLiked) {
      widget.onLike();
    } else {
      SwifsFeedback.unlike();
    }
    setState(() => _visible = true);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        children: [
          widget.child,
          if (_visible)
            Positioned(
              left: _tapAt.dx - 50,
              top: _tapAt.dy - 50,
              width: 100,
              height: 100,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final t = _controller.value;
                    final scale =
                        t < 0.3 ? Curves.easeOutBack.transform(t / 0.3) : 1.0;
                    final opacity = t < 0.6
                        ? 1.0
                        : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0).toDouble();
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: const Icon(
                          Icons.favorite,
                          size: 96,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 12, color: Colors.black38),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
