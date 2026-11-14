import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../core/theme/swifs_refresh.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/network/interaction_queue.dart';
import '../comments/comments_sheet.dart';
import '../create/create_post_screen.dart';
import '../../core/native/swifs_ffi.dart';

const Color kPrimary = Color(0xFFFF6B35);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Map<String, dynamic>> _posts;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _posts = [];

    // Preload audio for low latency
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    _audioPlayer.setSource(AssetSource('sounds/bubble_pop.mp3'));
    _loadFeed();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _playPopSound() async {
    try {
      final player = AudioPlayer();
      player.play(AssetSource('sounds/bubble_pop.mp3'));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('Audio error: $e');
    }
  }

  Map<String, dynamic>? _findPost(String id) {
    for (final post in _posts) {
      if (post['id'] == id) return post;
    }
    return null;
  }

  void _rescore(Map<String, dynamic> post) {
    post['score'] = SwifsScore.feed(
      (post['likes'] as num).toInt(),
      (post['comments'] as num).toInt(),
      (post['views'] as num).toInt(),
      (post['age_minutes'] as num).toInt(),
    );
  }

  void _applyPost(String id, Map<String, dynamic> values) {
    final post = _findPost(id);
    if (post == null || !mounted) return;
    setState(() {
      post.addAll(values);
      _rescore(post);
    });
  }

  void _applyFollow(String authorId, bool following) {
    if (!mounted) return;
    setState(() {
      for (final post in _posts) {
        if (post['authorId'] == authorId) post['isFollowing'] = following;
      }
    });
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) =>
      list..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

  /// Offline first: show the saved feed at once, then update it from Supabase.
  Future<void> _loadFeed() async {
    final cached = await social.cachedFeed();
    if (cached != null && mounted) {
      setState(() => _posts = _sorted(cached.map((p) => p.toMap()).toList()));
    }
    try {
      final fresh = await social.fetchFeed();
      if (mounted) setState(() => _posts = _sorted(fresh.map((p) => p.toMap()).toList()));
    } catch (_) {
      // Offline: keep the saved posts on screen.
    }
  }

  /// Refreshes counts after the comments sheet closes.
  Future<void> _refreshCounts() async {
    try {
      final fresh = await social.fetchFeed();
      if (!mounted) return;
      final byId = {for (final p in fresh) p.id: p};
      setState(() {
        for (final post in _posts) {
          final f = byId[post['id']];
          if (f == null) continue;
          post['comments'] = f.comments;
          post['likes'] = f.likes;
          _rescore(post);
        }
      });
    } catch (_) {}
  }

  Future<void> _openComments(String postId) async {
    await showCommentsSheet(context, postId: postId);
    _refreshCounts();
  }

  void _handleLike(int index) {
    final post = _posts[index];
    final id = post['id'] as String;
    final wasLiked = post['liked'] == true;
    final prevLikes = (post['likes'] as num).toInt();
    final prevScore = post['score'];
    final nowLiked = !wasLiked;
    if (nowLiked) _playPopSound();

    setState(() {
      post['liked'] = nowLiked;
      post['likes'] = prevLikes + (nowLiked ? 1 : -1);
      _rescore(post);
    });

    InteractionQueue.instance.enqueue(
      OutboxOp('like:$id', 'like', {'postId': id, 'liked': nowLiked}),
      onSuccess: (result) {
        final r = result as LikeResult;
        _applyPost(id, {'liked': r.liked, 'likes': r.count});
      },
      onFail: (_) => _applyPost(id, {'liked': wasLiked, 'likes': prevLikes, 'score': prevScore}),
    );
  }

  void _handleSave(int index) {
    final post = _posts[index];
    final id = post['id'] as String;
    final wasSaved = post['isSaved'] == true;
    final nowSaved = !wasSaved;
    if (nowSaved) _playPopSound();
    setState(() => post['isSaved'] = nowSaved);

    InteractionQueue.instance.enqueue(
      OutboxOp('save:$id', 'save', {'postId': id, 'saved': nowSaved}),
      onSuccess: (result) => _applyPost(id, {'isSaved': result as bool}),
      onFail: (_) => _applyPost(id, {'isSaved': wasSaved}),
    );
  }

  void _handleFollow(int index) {
    final authorId = _posts[index]['authorId'] as String;
    final wasFollowing = _posts[index]['isFollowing'] == true;
    final nowFollowing = !wasFollowing;
    _applyFollow(authorId, nowFollowing);

    InteractionQueue.instance.enqueue(
      OutboxOp('follow:$authorId', 'follow', {'authorId': authorId, 'following': nowFollowing}),
      onSuccess: (result) => _applyFollow(authorId, result as bool),
      onFail: (_) => _applyFollow(authorId, wasFollowing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _storiesRow(),
            Expanded(
              child: SmartRefresher(
                enablePullDown: true,
                header: CustomHeader(
                  height: 60.0, // Constrains the pull area
                  builder: (context, mode) => Center(
                    child: buildSwifsRefreshIcon(LucideIcons.house),
                  ),
                ),
                controller: _refreshController,
                onRefresh: () async {
                  await Future.delayed(const Duration(seconds: 1));
                  _refreshController.refreshCompleted();
                },
                child: _feed(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Swifs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: kPrimary)),
            Row(children: [
              IconButton(
                icon: const SwifsIcon(LucideIcons.plus), 
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const CreatePostScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                          child: child,
                        );
                      },
                    ),
                  );
                }
              ),
              IconButton(icon: const SwifsIcon(LucideIcons.bell), onPressed: () {}),
            ]),
          ],
        ),
      );

  Widget _storiesRow() {
    final stories = ['Your Story', 'alex', 'mia', 'leo', 'zara'];
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12),
        itemCount: stories.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: i == 0 ? Colors.grey.shade300 : kPrimary, width: 2.5),
              ),
              child: const CircleAvatar(backgroundColor: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(stories[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  Widget _feed() => ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final p = _posts[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(radius: 18, backgroundColor: Colors.grey),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${p['user']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                        Text(p['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _handleFollow(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: p['isFollowing'] ? Colors.grey.shade200 : kPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          p['isFollowing'] ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: p['isFollowing'] ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (p['mediaUrl'] != null)
                PostMedia(url: p['mediaUrl']!, thumbUrl: p['thumbUrl'], type: p['mediaType'] ?? 'image')
              else
                Container(
                  height: 350, color: const Color(0xFFF0F2F5),
                  child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _AnimatedActionIcon(
                      icon: LucideIcons.heart,
                      isActive: p['liked'],
                      activeColor: Colors.red,
                      floatIcon: LucideIcons.heart,
                      onTap: () => _handleLike(i),
                    ),
                    const SizedBox(width: 4),
                    _AnimatedActionIcon(
                      icon: LucideIcons.messageCircle,
                      isActive: false,
                      activeColor: Colors.black,
                      onTap: () => _openComments(p['id']),
                    ),
                    const SizedBox(width: 4),
                    _AnimatedActionIcon(
                      icon: LucideIcons.upload,
                      isActive: false,
                      activeColor: Colors.black,
                      onTap: () {},
                    ),
                    const Spacer(),
                    _AnimatedActionIcon(
                      icon: LucideIcons.bookmark,
                      isActive: p['isSaved'],
                      activeColor: kPrimary,
                      floatIcon: LucideIcons.bookmark,
                      onTap: () => _handleSave(i),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['likes']} likes', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '@${p['user']} ', style: const TextStyle(fontWeight: FontWeight.w500)),
                    TextSpan(text: p['caption']),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      );
}

class _AnimatedActionIcon extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final IconData? floatIcon;
  final VoidCallback onTap;

  const _AnimatedActionIcon({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    this.floatIcon,
    required this.onTap,
  });

  @override
  State<_AnimatedActionIcon> createState() => _AnimatedActionIconState();
}

class _AnimatedActionIconState extends State<_AnimatedActionIcon> {
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
      builder: (context) => _FloatingHearts(
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
        return const Icon(Icons.bookmark, size: 28, color: kPrimary);
      }
    }
    return SwifsIcon(widget.icon, size: 28, color: Colors.black);
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

class _FloatingHearts extends StatefulWidget {
  final double startX;
  final double startY;
  final IconData icon;
  final Color color;

  const _FloatingHearts({
    required this.startX,
    required this.startY,
    required this.icon,
    required this.color,
  });

  @override
  State<_FloatingHearts> createState() => _FloatingHeartsState();
}

class _FloatingHeartsState extends State<_FloatingHearts> with SingleTickerProviderStateMixin {
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
  bool _isPlaying = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          _controller!.setVolume(0); // Default muted
          _controller!.setLooping(true);
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'video' && _controller != null && _controller!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 4 / 5, // Instagram style aspect ratio
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller!),
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.play_arrow, size: 64, color: Colors.white),
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
                  child: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: CachedNetworkImage(
        imageUrl: widget.thumbUrl ?? widget.url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFFF0F2F5),
          child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
        ),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xFFF0F2F5),
          child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey)),
        ),
      ),
    );
  }
}
