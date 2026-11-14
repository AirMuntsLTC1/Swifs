import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../data/models.dart';
import '../data/social.dart';
import '../network/interaction_queue.dart';
import '../theme/swifs_icon.dart';
import 'swifs_skeleton.dart';
import '../../features/messages/share_bottom_sheet.dart';
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
  /// Width divided by height. Instagram uses 4:5 (portrait) up to 1.91:1 (landscape).
  final double ratio;

  const PostMedia({super.key, required this.url, this.thumbUrl, required this.type, this.ratio = 4 / 5});

  @override
  State<PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<PostMedia> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _loading = false;
  bool _failed = false;
  bool _playing = false;
  bool _visible = false;
  bool _wantPlay = false;
  bool _muted = true;

  bool get _isVideo => widget.type == 'video';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Loads the video once. A failed load can be retried by tapping.
  Future<void> _prepare() async {
    if (!_isVideo || _ready || _loading) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await c.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await c.setLooping(true);
      await c.setVolume(_muted ? 0 : 1);
      c.addListener(_onTick);
      setState(() {
        _ready = true;
        _loading = false;
      });
      if (_wantPlay) await c.play();
    } catch (e) {
      debugPrint('Video failed to load: $e');
      if (!mounted) return;
      _controller?.dispose();
      _controller = null;
      setState(() {
        _failed = true;
        _loading = false;
        _ready = false;
      });
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    if (c.value.isPlaying != _playing) setState(() => _playing = c.value.isPlaying);
  }

  /// Starts playback as soon as the video is ready.
  void _playWhenReady() {
    _wantPlay = true;
    if (_ready) {
      _controller?.play();
    } else {
      _prepare();
    }
  }

  void _onVisibility(VisibilityInfo info) {
    if (!_isVideo || !mounted) return;
    final nowVisible = info.visibleFraction >= 0.6;
    if (nowVisible == _visible) return;
    _visible = nowVisible;
    if (nowVisible) {
      _playWhenReady();
    } else {
      _wantPlay = false;
      _controller?.pause();
    }
  }

  void _onTap() {
    if (!_isVideo) return;
    if (_failed) {
      _controller = null;
      _playWhenReady();
      return;
    }
    if (!_ready) {
      _playWhenReady();
      return;
    }
    final c = _controller!;
    if (c.value.isPlaying) {
      _wantPlay = false;
      c.pause();
    } else {
      _wantPlay = true;
      c.play();
    }
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0 : 1);
  }

  Widget _poster() {
    final url = (widget.thumbUrl != null && widget.thumbUrl!.isNotEmpty)
        ? widget.thumbUrl!
        : (_isVideo ? '' : widget.url);
    if (url.isEmpty) return const VideoPosterTile();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const SwifsSkeletonBox(),
      errorWidget: (_, __, ___) => Container(
        color: _kTile,
        child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    Widget content;
    if (!_isVideo) {
      content = _poster();
    } else if (_ready && c != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          ),
          GestureDetector(
            onTap: _onTap,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedOpacity(
                opacity: _playing ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
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
      );
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          _poster(),
          if (_loading) const SwifsSkeletonBox(),
          if (!_loading)
            GestureDetector(
              onTap: _onTap,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: Icon(_failed ? Icons.refresh : Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ),
            ),
          if (_failed)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  "Couldn't play this video. Tap to try again.",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
        ],
      );
    }

    return VisibilityDetector(
      key: Key('media-${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: AspectRatio(aspectRatio: widget.ratio, child: content),
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
              ? (post.mediaType == 'video' ? const VideoPosterTile() : Container(color: _kTile, child: const Center(child: SwifsIcon(LucideIcons.image, color: Colors.grey))))
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

/// Slides the new page in from the right, like Instagram. Use for opening a post.
Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

/// Dark tile with a play icon, for a video that has no thumbnail.
class VideoPosterTile extends StatelessWidget {
  const VideoPosterTile({super.key});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1C1C1E),
        child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 56)),
      );
}

/// Full post view, opened from Find, profiles, saved and shared messages.
/// Same icons and actions as the home feed: heart, comment, share and bookmark.
class PostViewerScreen extends StatefulWidget {
  final FeedPost post;
  const PostViewerScreen({super.key, required this.post});

  @override
  State<PostViewerScreen> createState() => _PostViewerScreenState();
}

class _PostViewerScreenState extends State<PostViewerScreen> {
  late bool _liked;
  late int _likes;
  late bool _saved;
  late int _comments;
  List<Map<String, dynamic>> _media = const [];
  bool _loadingMedia = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.liked;
    _likes = widget.post.likes;
    _saved = widget.post.isSaved;
    _comments = widget.post.comments;
    if (widget.post.media.isNotEmpty) {
      _media = widget.post.media;
    } else {
      _loadingMedia = true;
      _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    try {
      final media = await social.fetchPostMedia(widget.post.id);
      if (mounted) setState(() => _media = media);
    } catch (_) {
      // Keep whatever is shown. The post still opens.
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
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
    final ratio = postAspectRatio(_media.isEmpty ? null : _media.first);
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
      body: ListView(
        children: [
          _loadingMedia && _media.isEmpty
              ? AspectRatio(aspectRatio: ratio, child: const SwifsSkeletonBox())
              : SizedBox(
                  width: double.infinity,
                  child: PostCarousel(media: _media, ratio: ratio),
                ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                _ActionButton(
                  onTap: _toggleLike,
                  child: _liked
                      ? const Icon(Icons.favorite, size: 28, color: Colors.red)
                      : const SwifsIcon(LucideIcons.heart, size: 28, color: _kInk),
                ),
                _ActionButton(
                  onTap: () => showCommentsSheet(context, postId: widget.post.id),
                  child: const SwifsIcon(LucideIcons.messageCircle, size: 28, color: _kInk),
                ),
                _ActionButton(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ShareBottomSheet(postId: widget.post.id),
                  ),
                  child: const SwifsIcon(LucideIcons.upload, size: 28, color: _kInk),
                ),
                const Spacer(),
                _ActionButton(
                  onTap: _toggleSave,
                  child: _saved
                      ? const Icon(Icons.bookmark, size: 28, color: _kPrimary)
                      : const SwifsIcon(LucideIcons.bookmark, size: 28, color: _kInk),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_likes likes', style: const TextStyle(fontWeight: FontWeight.w600, color: _kInk)),
                const SizedBox(height: 4),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '@${widget.post.user} ', style: const TextStyle(fontWeight: FontWeight.w600, color: _kInk)),
                  TextSpan(text: widget.post.caption, style: const TextStyle(color: _kInk)),
                ])),
                if (_comments > 0) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => showCommentsSheet(context, postId: widget.post.id),
                    child: Text('View all $_comments comments', style: const TextStyle(color: _kMuted, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _ActionButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(width: 44, height: 44, child: Center(child: child)),
    );
  }
}

/// The feed's aspect ratio for a post, from its first media. Unknown size gives 4:5.
double postAspectRatio(Map<String, dynamic>? m) {
  final w = (m?['width'] as num?)?.toDouble() ?? 0;
  final h = (m?['height'] as num?)?.toDouble() ?? 0;
  if (w <= 0 || h <= 0) return 4 / 5;
  return (w / h).clamp(4 / 5, 1.91).toDouble();
}

/// Instagram-style swipeable media for one post: dots, a 1/N counter, and one shape for every page.
class PostCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final double ratio;

  const PostCarousel({super.key, required this.media, required this.ratio});

  @override
  State<PostCarousel> createState() => _PostCarouselState();
}

class _PostCarouselState extends State<PostCarousel> {
  int _index = 0;

  Widget _page(Map<String, dynamic> m) => PostMedia(
        url: m['url'].toString(),
        thumbUrl: m['thumbUrl']?.toString(),
        type: (m['type'] ?? 'image').toString(),
        ratio: widget.ratio,
      );

  @override
  Widget build(BuildContext context) {
    final items = widget.media;
    if (items.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.ratio,
        child: Container(
          color: _kTile,
          child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey)),
        ),
      );
    }
    if (items.length == 1) return _page(items.first);

    return AspectRatio(
      aspectRatio: widget.ratio,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _page(items[i]),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${_index + 1}/${items.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  items.length,
                  (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _index == i ? _kPrimary : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
