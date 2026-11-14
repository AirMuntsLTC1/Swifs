import 'dart:async';
import 'package:flutter/material.dart';
import '../messages/share_bottom_sheet.dart';
import '../profile/user_profile_screen.dart';
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
import '../../core/widgets/post_media.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/story_ring.dart';
import '../../core/data/stories_repository.dart';
import '../stories/story_camera_screen.dart';
import '../stories/story_viewer_screen.dart';
import '../../core/network/interaction_queue.dart';
import '../comments/comments_sheet.dart';
import '../create/create_post_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../core/native/swifs_ffi.dart';
import '../../core/notifications/realtime_notification_service.dart';
import '../../core/widgets/swifs_skeleton.dart';

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
  bool _loading = true;
  static const int _pageSize = 10;
  final ScrollController _scroll = ScrollController();
  bool _loadingMore = false;
  bool _hasMore = true;
  Timer? _realtimeDebounce;
  StreamSubscription<String>? _realtimeSub;
  static const Set<String> _feedTables = {
    'posts', 'post_media', 'post_likes', 'post_saves', 'comments', 'comment_likes', 'follows', 'profiles', 'blocked_users',
  };
  List<StoryGroup> _groups = [];
  String? _myAvatar;
  String _myName = 'You';

  StoryGroup? get _mine {
    for (final g in _groups) {
      if (g.isMine) return g;
    }
    return null;
  }

  void _onStoryUploadChanged() {
    if (StoriesRepository.uploadProgress.value == null) _loadStories();
  }

  void _onStoryError() {
    final e = StoriesRepository.uploadError.value;
    if (e != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
      StoriesRepository.uploadError.value = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _posts = [];

    // Preload audio for low latency
    _scroll.addListener(_onScroll);
    _realtimeSub = RealtimeHub.instance.changes.listen(_onRealtime);
    _loadFeed();
    _loadStories();
    StoriesRepository.uploadProgress.addListener(_onStoryUploadChanged);
    StoriesRepository.uploadError.addListener(_onStoryError);
  }

  @override
  void dispose() {
    StoriesRepository.uploadProgress.removeListener(_onStoryUploadChanged);
    StoriesRepository.uploadError.removeListener(_onStoryError);
    _audioPlayer.dispose();
    _refreshController.dispose();
    _scroll.dispose();
    _realtimeDebounce?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _playPopSound() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/bubble_pop.mp3')).catchError((_) {});
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

  /// Offline first: the saved first page shows at once, then the newest page loads from Supabase.
  /// Newest first, like a photo feed. Later pages load as you scroll.
  Future<void> _loadFeed() async {
    final cached = await social.cachedFeed();
    if (cached != null && mounted && _posts.isEmpty) {
      setState(() {
        _posts = cached.map((p) => p.toMap()).toList();
        _loading = false;
      });
    }
    try {
      final fresh = await social.fetchFeedPage(limit: _pageSize);
      if (mounted) {
        setState(() {
          _posts = fresh.map((p) => p.toMap()).toList();
          _hasMore = fresh.length >= _pageSize;
        });
        // A short first page does not fill the screen, so load the next one now.
        WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      }
    } catch (_) {
      // Offline: keep what is on screen.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Loads the next page of older posts.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _posts.isEmpty) return;
    final before = DateTime.tryParse((_posts.last['created_at'] ?? '').toString());
    if (before == null) return;
    setState(() => _loadingMore = true);
    try {
      final more = await social.fetchFeedPage(before: before, limit: _pageSize);
      if (!mounted) return;
      final known = {for (final p in _posts) p['id']};
      setState(() {
        _posts.addAll(more.map((p) => p.toMap()).where((m) => !known.contains(m['id'])));
        _hasMore = more.length >= _pageSize;
      });
    } catch (_) {
      // Try again on the next scroll.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  /// Realtime: a change to a feed table refreshes the newest page (after a short pause for bursts).
  void _onRealtime(String table) {
    if (!_feedTables.contains(table)) return;
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _syncNewest();
    });
  }

  /// Fetches the newest page and merges it. New posts go on top. Existing posts get fresh counts,
  /// names and photos. Like and save state is not overwritten, so an action still being sent does not flicker.
  Future<void> _syncNewest() async {
    try {
      final fresh = await social.fetchFeedPage(limit: _pageSize);
      if (!mounted) return;
      final byId = {for (final p in fresh) p.id: p.toMap()};
      setState(() {
        final known = <String>{};
        for (final post in _posts) {
          final id = post['id'] as String;
          known.add(id);
          final f = byId[id];
          if (f == null) continue;
          post['likes'] = f['likes'];
          post['comments'] = f['comments'];
          post['views'] = f['views'];
          post['user'] = f['user'];
          post['displayName'] = f['displayName'];
          post['avatarUrl'] = f['avatarUrl'];
          final hasMedia = (post['media'] as List?)?.isNotEmpty ?? false;
          if (!hasMedia) {
            post['media'] = f['media'];
            post['mediaUrl'] = f['mediaUrl'];
            post['mediaType'] = f['mediaType'];
            post['thumbUrl'] = f['thumbUrl'];
          }
          _rescore(post);
        }
        final newOnes = fresh.where((p) => !known.contains(p.id)).map((p) => p.toMap()).toList();
        if (newOnes.isNotEmpty) _posts.insertAll(0, newOnes);
      });
    } catch (_) {
      // Offline: keep the feed as it is.
    }
  }

  /// Refreshes counts after the comments sheet closes.
  Future<void> _refreshCounts() => _syncNewest();

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
                  await _loadStories();
                  await _loadFeed();
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
              IconButton(
                icon: const SwifsIcon(LucideIcons.bell), 
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ]),
          ],
        ),
      );

  /// Loads the story rail and my profile photo for the first ring.
  Future<void> _loadStories() async {
    try {
      final groups = await StoriesRepository.instance.fetchRail();
      Map<String, dynamic>? me;
      try {
        me = await social.fetchMyProfile();
      } catch (_) {
        me = await social.cachedMyProfile();
      }
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _myAvatar = me?['avatar_url']?.toString();
        final name = (me?['display_name'] ?? '').toString().trim();
        final handle = (me?['username'] ?? '').toString().trim();
        _myName = name.isNotEmpty ? name : (handle.isNotEmpty ? handle : 'You');
      });
    } catch (_) {
      // Offline: keep the rail that is already on screen.
    }
  }

  /// The photos and videos of a post, in order. Falls back to the first media for older cached posts.
  List<Map<String, dynamic>> _mediaOf(Map<String, dynamic> p) {
    final raw = p['media'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    }
    final url = p['mediaUrl'];
    if (url == null) return const [];
    return [
      {'type': p['mediaType'] ?? 'image', 'url': url, 'thumbUrl': p['thumbUrl'], 'width': 0, 'height': 0},
    ];
  }

  void _openCamera() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryCameraScreen()))
        .then((_) => _loadStories());
  }

  void _openViewer(int groupIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryViewerScreen(groups: _groups, startGroup: groupIndex)),
    ).then((_) => _loadStories());
  }

  Widget _storyColumn({required Widget avatar, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myStoryItem(double? uploading) {
    final mine = _mine;
    final hasStory = mine != null;
    final avatar = SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          StoryRing(
            size: 68,
            seen: mine == null || mine.allSeen,
            uploadProgress: uploading,
            child: UserAvatar(url: _myAvatar, name: _myName, radius: 30),
          ),
          if (uploading == null)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: _openCamera,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: kStoryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
    final label = uploading != null ? 'Sharing…' : 'Your story';
    final onTap = (mine != null && uploading == null)
        ? () => _openViewer(_groups.indexOf(mine))
        : _openCamera;
    return _storyColumn(avatar: avatar, label: label, onTap: onTap);
  }

  Widget _storiesRow() {
    return SizedBox(
      height: 100,
      child: ValueListenableBuilder<double?>(
        valueListenable: StoriesRepository.uploadProgress,
        builder: (context, uploading, _) {
          final others = _groups.where((g) => !g.isMine).toList();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 12, top: 4),
            children: [
              Padding(padding: const EdgeInsets.only(right: 12), child: _myStoryItem(uploading)),
              for (final g in others)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _storyColumn(
                    avatar: StoryRing(
                      size: 68,
                      seen: g.allSeen,
                      child: UserAvatar(url: g.avatarUrl, name: g.label, radius: 30),
                    ),
                    label: g.label,
                    onTap: () => _openViewer(_groups.indexOf(g)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _feed() => _posts.isEmpty ? _emptyFeed() : ListView.builder(
        controller: _scroll,
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _posts.length) return const FeedSkeleton(count: 1);
          final p = _posts[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: p['authorId'].toString()))),
                      child: UserAvatar(url: p['avatarUrl']?.toString(), name: (p['displayName'] ?? p['user']).toString(), radius: 18),
                    ),
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
              SizedBox(
                width: double.infinity,
                child: PostCarousel(
                  media: _mediaOf(p),
                  ratio: postAspectRatio(_mediaOf(p).isEmpty ? null : _mediaOf(p).first),
                ),
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
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ShareBottomSheet(postId: p['id']),
                        );
                      },
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

extension _EmptyFeedBuilder on _HomeScreenState {
  Widget _emptyFeed() {
    if (_loading) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [FeedSkeleton(count: 2)],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 320,
          child: Center(child: Text('No posts yet. Be the first to post.', style: TextStyle(color: Colors.grey))),
        ),
      ],
    );
  }
}
