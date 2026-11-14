import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'swifs_skeleton.dart';

/// Shows a picked photo at full size, or plays a picked video (tap to pause or play).
/// A thumbnail shows while the full file loads.
class AssetPreview extends StatefulWidget {
  final AssetEntity asset;
  final BoxFit fit;

  const AssetPreview({super.key, required this.asset, this.fit = BoxFit.contain});

  @override
  State<AssetPreview> createState() => _AssetPreviewState();
}

class _AssetPreviewState extends State<AssetPreview> {
  Uint8List? _thumb;
  File? _file;
  VideoPlayerController? _video;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thumb = await widget.asset.thumbnailDataWithSize(const ThumbnailSize(720, 720));
      if (mounted && thumb != null) setState(() => _thumb = thumb);

      final file = await widget.asset.originFile;
      if (!mounted) return;
      if (file == null) {
        setState(() => _failed = true);
        return;
      }

      if (widget.asset.type == AssetType.video) {
        final c = VideoPlayerController.file(file);
        try {
          await c.initialize();
          await c.setLooping(true);
          await c.setVolume(0);
          await c.play();
        } catch (_) {
          c.dispose();
          if (mounted) setState(() => _failed = true);
          return;
        }
        if (!mounted) {
          c.dispose();
          return;
        }
        c.addListener(() {
          if (mounted && c.value.isPlaying != _playing) setState(() => _playing = c.value.isPlaying);
        });
        setState(() {
          _video = c;
          _playing = true;
        });
      } else {
        setState(() => _file = file);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _togglePlay() {
    final c = _video;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _video;
    if (c != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: widget.fit,
            child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
          ),
          GestureDetector(
            onTap: _togglePlay,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedOpacity(
                opacity: _playing ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_file != null) return Image.file(_file!, fit: widget.fit);
    if (_thumb != null) return Image.memory(_thumb!, fit: widget.fit);
    if (_failed) {
      return const ColoredBox(
        color: Color(0xFFF0F2F5),
        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
      );
    }
    return const SwifsSkeletonBox();
  }
}
