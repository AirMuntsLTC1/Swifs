import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../network/interaction_queue.dart';
import '../theme/swifs_icon.dart';
import '../widgets/user_avatar.dart';
import '../../features/comments/comments_sheet.dart';

const Color _kPrimary = Color(0xFFFF6B35);
const Color _kTile = Color(0xFFF0F2F5);
const Color _kInk = Color(0xFF111111);
const Color _kMuted = Color(0xFF8E8E93);

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
    c.initialize().then((_) {
      if (!mounted) return;
      c.setLooping(true);
      c.setVolume(_muted ? 0 : 1);
      setState(() => _ready = true);
      if (_visible && !_userPaused) c.play();
    }).catchError((_) {
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
            placeholder: (_, __) => Container(color: _kTile, child: const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2))),
            errorWidget: (_, __, ___) => Container(color: _kTile, child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey))),
          ),
        if (showPlay) const Center(child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white70)),
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
                    bottom: 12, right: 12,
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
                  imageUrl: url, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: _kTile),
                  errorWidget: (_, __, ___) => Container(color: _kTile, child: const Center(child: SwifsIcon(LucideIcons.image, color: Colors.grey))),
                ),
          if (post.mediaType == 'video')
            const Positioned(top: 6, right: 6, child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20)),
          if (post.views > 0)
            Positioned(
              bottom: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                    const SizedBox(width: 2),
                    Text(_formatViews(post.views), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatViews(int views) {
  if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
  if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
  return views.toString();
}

class PostViewerScreen extends StatefulWidget {
  final FeedPost post;
  const PostViewerScreen({super.key, required this.post});

  @override
  State<PostViewerScreen> createState() => _PostViewerScreenState();
}

class _PostViewerScreenState extends State<PostViewerScreen> {
  List<Map<String, dynamic>> _media = [];
  int _currentIndex = 0;
  late bool _liked;
  late int _likes;
  late bool _saved;
  bool _loading = true;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _liked = widget.post.liked;
    _likes = widget.post.likes;
    _saved = widget.post.isSaved;
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final media = await social.fetchPostMedia(widget.post.id);
      if (mounted) setState(() { _media = media; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          if (widget.post.mediaUrl != null) {
            _media = [{'type': widget.post.mediaType ?? 'image', 'url': widget.post.mediaUrl, 'thumbUrl': widget.post.thumbUrl}];
          }
          _loading = false;
        });
      }
    }
  }

  void _toggleLike() {
    final wasLiked = _liked;
    final prevLikes = _likes;
    setState(() {
      _liked = !wasLiked;
      _likes = prevLikes + (_liked ? 1 : -1);
    });

    InteractionQueue.instance.enqueue(
      OutboxOp('like:${widget.post.id}', 'like', {'postId': widget.post.id, 'liked': _liked}),
      onSuccess: (result) {
        final r = result as LikeResult;
        if (mounted) setState(() { _liked = r.liked; _likes = r.count; });
      },
      onFail: (_) {
        if (mounted) setState(() { _liked = wasLiked; _likes = prevLikes; });
      },
    );
  }

  void _toggleSave() {
    final wasSaved = _saved;
    setState(() => _saved = !wasSaved);

    InteractionQueue.instance.enqueue(
      OutboxOp('save:${widget.post.id}', 'save', {'postId': widget.post.id, 'saved': _saved}),
      onSuccess: (result) {
        if (mounted) setState(() => _saved = result as bool);
      },
      onFail: (_) {
        if (mounted) setState(() => _saved = wasSaved);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            UserAvatar(url: widget.post.avatarUrl, name: widget.post.user, radius: 16),
            const SizedBox(width: 8),
            Text('@${widget.post.user}', style: const TextStyle(color: _kInk, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentIndex = i),
                        itemCount: _media.length,
                        itemBuilder: (_, i) {
                          final m = _media[i];
                          return PostMedia(url: m['url'], thumbUrl: m['thumbUrl'], type: m['type']);
                        },
                      ),
                      if (_media.length > 1)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_media.length, (i) {
                              return Container(
                                width: 6, height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentIndex == i ? _kPrimary : Colors.grey.shade300,
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _toggleLike,
                            child: SwifsIcon(_liked ? LucideIcons.heart : LucideIcons.heart, size: 28, color: _liked ? Colors.red : _kInk),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => showCommentsSheet(context, postId: widget.post.id),
                            child: const SwifsIcon(LucideIcons.messageCircle, size: 28, color: _kInk),
                          ),
                          const SizedBox(width: 16),
                          const SwifsIcon(LucideIcons.send, size: 28, color: _kInk),
                          const Spacer(),
                          GestureDetector(
                            onTap: _toggleSave,
                            child: SwifsIcon(LucideIcons.bookmark, size: 28, color: _saved ? _kPrimary : _kInk),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('$_likes likes', style: const TextStyle(fontWeight: FontWeight.w600, color: _kInk)),
                      const SizedBox(height: 4),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '@${widget.post.user} ', style: const TextStyle(fontWeight: FontWeight.w600, color: _kInk)),
                        TextSpan(text: widget.post.caption, style: const TextStyle(color: _kInk)),
                      ])),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
