import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/widgets/swifs_skeleton.dart';

/// A video story. Fills the story canvas, loops while the story is open, and plays with sound.
class StoryVideoCanvas extends StatefulWidget {
  final String url;

  const StoryVideoCanvas({super.key, required this.url});

  @override
  State<StoryVideoCanvas> createState() => _StoryVideoCanvasState();
}

class _StoryVideoCanvasState extends State<StoryVideoCanvas> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c.setLooping(true);
      c.setVolume(1);
      c.play();
      setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('Video unavailable', style: TextStyle(color: Colors.white70))),
      );
    }
    if (!_ready || c == null) return const SwifsSkeletonBox();
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      ),
    );
  }
}
