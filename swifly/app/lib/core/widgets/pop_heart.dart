import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../theme/swifs_icon.dart';

/// Same bubble pop sound the feed uses.
void playPopSound() {
  try {
    final player = AudioPlayer();
    player.play(AssetSource('sounds/bubble_pop.mp3')).catchError((_) {});
    player.onPlayerComplete.listen((_) => player.dispose());
  } catch (_) {}
}

/// Heart with the same bounce + floating hearts + pop sound as the feed.
class PopHeart extends StatefulWidget {
  final bool isActive;
  final int count;
  final double size;
  final VoidCallback onTap;

  const PopHeart({
    super.key,
    required this.isActive,
    required this.onTap,
    this.count = 0,
    this.size = 18,
  });

  @override
  State<PopHeart> createState() => _PopHeartState();
}

class _PopHeartState extends State<PopHeart> {
  double _scale = 1.0;

  void _handleTap() {
    final wasActive = widget.isActive;
    widget.onTap();
    if (wasActive) return;

    playPopSound();
    setState(() => _scale = 1.3);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _scale = 1.0);
    });
    _showFloatingHearts();
  }

  void _showFloatingHearts() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final entry = OverlayEntry(
      builder: (_) => _FloatingHearts(startX: origin.dx + 2, startY: origin.dy - 6),
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(milliseconds: 900), entry.remove);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: widget.isActive
                ? Icon(Icons.favorite, size: widget.size, color: Colors.red)
                : SwifsIcon(LucideIcons.heart,
                    size: widget.size, color: const Color(0xFF111111)),
          ),
          if (widget.count > 0)
            Text(
              '${widget.count}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
        ],
      ),
    );
  }
}

class _FloatingHearts extends StatefulWidget {
  final double startX;
  final double startY;
  const _FloatingHearts({required this.startX, required this.startY});

  @override
  State<_FloatingHearts> createState() => _FloatingHeartsState();
}

class _FloatingHeartsState extends State<_FloatingHearts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = _controller.value;
        return Positioned(
          left: widget.startX,
          top: widget.startY - 100 * p,
          child: Opacity(
            opacity: 1 - p,
            child: Row(
              children: [
                Transform.translate(
                  offset: Offset(-15 * p, -10 * p),
                  child: const SwifsIcon(LucideIcons.heart, size: 16, color: Colors.red),
                ),
                Transform.translate(
                  offset: Offset(0, -25 * p),
                  child: const SwifsIcon(LucideIcons.heart, size: 20, color: Colors.red),
                ),
                Transform.translate(
                  offset: Offset(15 * p, -5 * p),
                  child: const SwifsIcon(LucideIcons.heart, size: 14, color: Colors.red),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


