import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/feedback/swifs_feedback.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/auth/current_user.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/network/interaction_queue.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/count_text.dart';
import '../../core/widgets/double_tap_like.dart';
import '../../core/widgets/post_media.dart';
import '../../core/widgets/user_avatar.dart';
import '../comments/comments_sheet.dart';
import '../messages/share_bottom_sheet.dart';

const Color _kReelPrimary = Color(0xFFFF6B35);

/// Full-screen vertical posts, like Reels. Swipe up for the next post.
/// The next posts are random picks from the Explore posts, and more are loaded as you go.
class ReelsScreen extends StatefulWidget {
  /// The first post is the one you tapped. The rest are shuffled.
  final List<FeedPost> posts;
  /// Shown at the top. Explore uses 'Explore'. A chat shows the sender's name.
  final String title;

  const ReelsScreen({super.key, required this.posts, this.title = 'Explore'});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final List<FeedPost> _posts = List<FeedPost>.of(widget.posts);
  final Set<String> _seen = {};
  bool _refilling = false;

  @override
  void initState() {
    super.initState();
    _seen.addAll(_posts.map((p) => p.id));
    // A single shared post still needs more posts to swipe to.
    if (_posts.length < 4) _refill();
  }

  /// Loads more Explore posts in a random order. Posts already shown come last.
  Future<void> _refill() async {
    if (_refilling) return;
    _refilling = true;
    try {
      final more = await social.fetchExplorePosts();
      if (!mounted || more.isEmpty) return;
      final rnd = Random();
      var fresh = more.where((p) => !_seen.contains(p.id)).toList()..shuffle(rnd);
      if (fresh.isEmpty) fresh = List<FeedPost>.of(more)..shuffle(rnd);
      setState(() {
        _posts.addAll(fresh);
        _seen.addAll(fresh.map((p) => p.id));
      });
    } catch (_) {
      // Keep the posts already on screen.
    } finally {
      _refilling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _posts.length,
            onPageChanged: (index) {
              if (index >= _posts.length - 3) _refill();
            },
            itemBuilder: (_, i) => _ReelPage(
              key: ValueKey('reel-$i-${_posts[i].id}'),
              post: _posts[i],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const SwifsIcon(LucideIcons.arrowLeft, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      widget.title,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One full-screen post with its actions. Same like, comment, share and save as Home.
class _ReelPage extends StatefulWidget {
  final FeedPost post;

  const _ReelPage({super.key, required this.post});

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  late bool _liked = widget.post.liked;
  late int _likes = widget.post.likes;
  late bool _saved = widget.post.isSaved;
  late bool _following = widget.post.isFollowing;
  late int _comments = widget.post.comments;
  late int _shares = widget.post.shares;

  List<Map<String, dynamic>> get _media {
    if (widget.post.media.isNotEmpty) return widget.post.media;
    final url = widget.post.mediaUrl;
    if (url == null || url.isEmpty) return const [];
    return [
      {'type': widget.post.mediaType ?? 'image', 'url': url, 'thumbUrl': widget.post.thumbUrl},
    ];
  }

  void _like() {
    final wasLiked = _liked;
    final prevLikes = _likes;
    final nowLiked = !wasLiked;
    if (nowLiked) SwifsFeedback.like(); // vibration + pop, once
    setState(() {
      _liked = nowLiked;
      _likes = prevLikes + (nowLiked ? 1 : -1);
    });
    final id = widget.post.id;
    InteractionQueue.instance.enqueue(
      OutboxOp('like:$id', 'like', {'postId': id, 'liked': nowLiked}),
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
    final nowSaved = !wasSaved;
    setState(() => _saved = nowSaved);
    final id = widget.post.id;
    InteractionQueue.instance.enqueue(
      OutboxOp('save:$id', 'save', {'postId': id, 'saved': nowSaved}),
      onSuccess: (result) {
        if (mounted) setState(() => _saved = result as bool);
      },
      onFail: (_) {
        if (mounted) setState(() => _saved = wasSaved);
      },
    );
  }

  void _toggleFollow() {
    final was = _following;
    setState(() => _following = !was);
    social.setFollow(widget.post.authorId, !was).then((v) {
      if (mounted) setState(() => _following = v);
    }).catchError((_) {
      if (mounted) setState(() => _following = was);
    });
  }

  Future<void> _refreshCounts() async {
    try {
      final counts = await social.fetchPostCounts([widget.post.id]);
      final c = counts[widget.post.id];
      if (c == null || !mounted) return;
      setState(() {
        _likes = c['likes'] ?? _likes;
        _comments = c['comments'] ?? _comments;
        _shares = c['shares'] ?? _shares;
      });
    } catch (_) {
      // Keep the numbers on screen.
    }
  }

  Future<void> _openComments() async {
    await showCommentsSheet(context, postId: widget.post.id);
    _refreshCounts();
  }

  void _openShare() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareBottomSheet(postId: widget.post.id),
    ).then((_) => _refreshCounts());
  }

  Widget _count(String text) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 14),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ratio = size.width / size.height;
    final post = widget.post;
    final mine = isMyAccount(post.authorId);

    return Stack(
      fit: StackFit.expand,
      children: [
        DoubleTapLike(
          alreadyLiked: _liked,
          onLike: () {
            if (!_liked) _like();
          },
          child: Center(child: PostCarousel(media: _media, ratio: ratio)),
        ),
        // Dark fade at the bottom so the text reads on any photo.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReelActionIcon(
                icon: LucideIcons.heart,
                isActive: _liked,
                activeColor: Colors.red,
                floatIcon: LucideIcons.heart,
                inkColor: Colors.white,
                onTap: _like,
              ),
              _count(compactCount(_likes)),
              ReelActionIcon(
                icon: LucideIcons.messageCircle,
                isActive: false,
                activeColor: Colors.white,
                inkColor: Colors.white,
                onTap: _openComments,
              ),
              _count(compactCount(_comments)),
              ReelActionIcon(
                icon: LucideIcons.upload,
                isActive: false,
                activeColor: Colors.white,
                inkColor: Colors.white,
                onTap: _openShare,
              ),
              _count(compactCount(_shares)),
              ReelActionIcon(
                icon: LucideIcons.bookmark,
                isActive: _saved,
                activeColor: _kReelPrimary,
                floatIcon: LucideIcons.bookmark,
                inkColor: Colors.white,
                onTap: _toggleSave,
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 84,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  UserAvatar(url: post.avatarUrl, name: post.user, radius: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '@${post.user}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!mine) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _toggleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white70),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _following ? 'Following' : 'Follow',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (post.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ReelActionIcon extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final IconData? floatIcon;
  final VoidCallback onTap;
  final Color inkColor;

  const ReelActionIcon({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    this.floatIcon,
    required this.onTap,
    this.inkColor = Colors.black,
  });

  @override
  State<ReelActionIcon> createState() => ReelActionIconState();
}

class ReelActionIconState extends State<ReelActionIcon> {
  double _scale = 1.0;

  void _handleTap() {
    widget.onTap();
    if (widget.isActive) return; 

    setState(() => _scale = 1.3);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _scale = 1.0);
    });

    if (widget.floatIcon != null) {
      _showFloatingIcons();
    }
  }

  void _showFloatingIcons() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    final entry = OverlayEntry(
      builder: (context) => _ReelFloatingHearts(
        startX: offset.dx + 10,
        startY: offset.dy - 10,
        icon: widget.floatIcon!,
        color: widget.activeColor,
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1000), () => entry.remove());
  }

  Widget _buildIcon() {
    if (widget.isActive) {
      if (widget.icon == LucideIcons.heart) {
        return const Icon(Icons.favorite, size: 28, color: Colors.red);
      } else if (widget.icon == LucideIcons.bookmark) {
        return const Icon(Icons.bookmark, size: 28, color: _kReelPrimary);
      }
    }
    return SwifsIcon(widget.icon, size: 28, color: widget.inkColor);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: _buildIcon(),
        ),
      ),
    );
  }
}

class _ReelFloatingHearts extends StatefulWidget {
  final double startX;
  final double startY;
  final IconData icon;
  final Color color;

  const _ReelFloatingHearts({
    required this.startX,
    required this.startY,
    required this.icon,
    required this.color,
  });

  @override
  State<_ReelFloatingHearts> createState() => _ReelFloatingHeartsState();
}

class _ReelFloatingHeartsState extends State<_ReelFloatingHearts> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
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
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = 1.0 - progress;
        final yOffset = -100.0 * progress;

        return Positioned(
          left: widget.startX,
          top: widget.startY + yOffset,
          child: Opacity(
            opacity: opacity,
            child: Row(
              children: [
                Transform.translate(
                  offset: Offset(-15 * progress, -10 * progress),
                  child: SwifsIcon(widget.icon, size: 16, color: widget.color),
                ),
                Transform.translate(
                  offset: Offset(0, -25 * progress),
                  child: SwifsIcon(widget.icon, size: 20, color: widget.color),
                ),
                Transform.translate(
                  offset: Offset(15 * progress, -5 * progress),
                  child: SwifsIcon(widget.icon, size: 14, color: widget.color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
