import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/data/stories_repository.dart';

/// Animated sticker: gently bobs and pulses forever.
class AnimatedSticker extends StatefulWidget {
  final String emoji;
  final double size;

  const AnimatedSticker({super.key, required this.emoji, this.size = 64});

  @override
  State<AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends State<AnimatedSticker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -8 * t),
          child: Transform.scale(scale: 0.94 + 0.12 * t, child: child),
        );
      },
      child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
    );
  }
}

/// Draws the photo with its layers on top. Used by the editor (editable) and the viewer (read-only).
class StoryCanvas extends StatelessWidget {
  final ImageProvider image;
  final List<StoryLayer> layers;
  final bool editable;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final void Function(int index, StoryLayer layer)? onChanged;
  final VoidCallback? onBackgroundTap;

  const StoryCanvas({
    super.key,
    required this.image,
    required this.layers,
    this.editable = false,
    this.selected,
    this.onSelect,
    this.onChanged,
    this.onBackgroundTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBackgroundTap,
        child: LayoutBuilder(
          builder: (context, c) {
            final canvas = Size(c.maxWidth, c.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image(image: image, fit: BoxFit.cover),
                for (var i = 0; i < layers.length; i++)
                  StoryLayerView(
                    key: ValueKey('layer-$i'),
                    layer: layers[i],
                    canvas: canvas,
                    editable: editable,
                    selected: selected == i,
                    onTap: editable && onSelect != null ? () => onSelect!(i) : null,
                    onChanged: editable && onChanged != null ? (l) => onChanged!(i, l) : null,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One text, sticker, or location tag. Drag with one finger; pinch to resize and twist to rotate.
class StoryLayerView extends StatefulWidget {
  final StoryLayer layer;
  final Size canvas;
  final bool editable;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<StoryLayer>? onChanged;

  const StoryLayerView({
    super.key,
    required this.layer,
    required this.canvas,
    this.editable = false,
    this.selected = false,
    this.onTap,
    this.onChanged,
  });

  @override
  State<StoryLayerView> createState() => _StoryLayerViewState();
}

class _StoryLayerViewState extends State<StoryLayerView> {
  double _lastScale = 1;
  double _lastRotation = 0;

  static double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

  void _start(ScaleStartDetails d) {
    _lastScale = 1;
    _lastRotation = 0;
  }

  void _update(ScaleUpdateDetails d) {
    final w = widget.canvas.width;
    final h = widget.canvas.height;
    if (w <= 0 || h <= 0 || widget.onChanged == null) return;

    final l = widget.layer.copy();
    l.x = _clamp(l.x + d.focalPointDelta.dx / w, 0.0, 1.0);
    l.y = _clamp(l.y + d.focalPointDelta.dy / h, 0.0, 1.0);
    l.scale = _clamp(l.scale * (d.scale / _lastScale), 0.4, 4.0);
    l.rotation = l.rotation + (d.rotation - _lastRotation);

    _lastScale = d.scale;
    _lastRotation = d.rotation;
    widget.onChanged!(l);
  }

  Widget _content() {
    final l = widget.layer;
    switch (l.kind) {
      case 'sticker':
        return AnimatedSticker(emoji: l.value, size: 64);
      case 'location':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFF6B35), size: 18),
              const SizedBox(width: 4),
              Text(
                l.value,
                style: GoogleFonts.roboto(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: widget.selected
              ? BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(
            l.value,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: Color(l.color),
              fontSize: 30,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.layer;
    Widget child = Transform.rotate(
      angle: l.rotation,
      child: Transform.scale(scale: l.scale, child: _content()),
    );
    if (widget.editable) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onScaleStart: _start,
        onScaleUpdate: _update,
        child: child,
      );
    }
    return Align(
      alignment: Alignment(l.x * 2 - 1, l.y * 2 - 1),
      child: child,
    );
  }
}
