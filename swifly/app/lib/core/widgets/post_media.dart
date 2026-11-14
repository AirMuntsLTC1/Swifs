import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../data/models.dart';
import '../theme/swifs_icon.dart';

const Color _kPrimary = Color(0xFFFF6B35);
const Color _kTile = Color(0xFFF0F2F5);

/// A post's photo or video in the feed. Photos show the thumbnail first, then the full image.
/// Videos show the thumbnail, then play automatically while at least 60% of them is on screen,
/// and pause when they scroll away.
class PostMedia extends StatefulWidget {
  final String url;
  final String? thumbUrl;
  final String type;

  const PostMedia({super.key, required this.url, this.thumbUrl, required this.type});

  @override
  State<PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<PostMedia> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _visible = false;
  bool _userPaused = false;
  bool _muted = true;

  bool get _isVideo => widget.type == 'video';

  void _ensureController() {
    if (!_isVideo || _controller != null) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    c
        .initialize()
        .then((_) {
          if (!mounted) return;
          c.setLooping(true);
          c.setVolume(_muted ? 0 : 1);
          setState(() => _ready = true);
          if (_visible && !_userPaused) c.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  void _onVisibility(VisibilityInfo info) {
    if (!_isVideo || !mounted) return;
    final nowVisible = info.visibleFraction >= 0.6;
    if (nowVisible == _visible) return;
    _visible = nowVisible;
    if (nowVisible) {
      _ensureController();
      if (_ready && !_userPaused) _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() {
      _userPaused = c.value.isPlaying;
      _userPaused ? c.pause() : c.play();
    });
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _thumb({bool showPlay = false}) {
    final url = (widget.thumbUrl != null && widget.thumbUrl!.isNotEmpty)
        ? widget.thumbUrl!
        : (!_isVideo ? widget.url : '');
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isEmpty)
          Container(color: _kTile, child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey)))
        else
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: _kTile,
              child: const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => Container(
              color: _kTile,
              child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey)),
            ),
          ),
        if (showPlay)
          const Center(child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white70)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('media-${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: _isVideo && _ready && _controller != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.play_arrow, size: 64, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: _isVideo && !_failed ? () => _ensureController() : null,
                child: _thumb(showPlay: _isVideo && !_failed),
              ),
      ),
    );
  }
}

/// One square tile in a grid of posts. Shows the thumbnail that the server stored.
class PostGridTile extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onTap;

  const PostGridTile({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = (post.thumbUrl != null && post.thumbUrl!.isNotEmpty)
        ? post.thumbUrl!
        : ((post.mediaType != 'video') ? (post.mediaUrl ?? '') : '');
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          url.isEmpty
              ? Container(color: _kTile, child: const Center(child: SwifsIcon(LucideIcons.image, color: Colors.grey)))
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: _kTile),
                  errorWidget: (_, __, ___) =>
                      Container(color: _kTile, child: const Center(child: SwifsIcon(LucideIcons.image, color: Colors.grey))),
                ),
          if (post.mediaType == 'video')
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
            ),
        ],
      ),
    );
  }
}

/// Full-screen view of one post: media, author, caption, and counts.
class PostViewerScreen extends StatelessWidget {
  final FeedPost post;

  const PostViewerScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: Color(0xFF111111)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${post.user}',
          style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        children: [
          if (post.mediaUrl != null)
            PostMedia(url: post.mediaUrl!, thumbUrl: post.thumbUrl, type: post.mediaType ?? 'image')
          else
            Container(height: 300, color: _kTile),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '@${post.user} ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: post.caption),
            ])),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${post.likes} likes · ${post.comments} comments',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
