import 'package:flutter/material.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../core/theme/swifs_refresh.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/widgets/post_media.dart';
import 'hashtag_screen.dart';
import 'search_screen.dart';
import 'saved_posts_screen.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kHashtagBlue = Color(0xFF1877F2);

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  List<Map<String, dynamic>> _tags = [];
  List<FeedPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads trending tags and the most liked/commented posts together.
  Future<void> _load() async {
    final results = await Future.wait([
      social.fetchTrendingWithUses().catchError((_) => <Map<String, dynamic>>[]),
      social.fetchExplorePosts().catchError((_) => <FeedPost>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _tags = results[0] as List<Map<String, dynamic>>;
      _posts = results[1] as List<FeedPost>;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _openSearch() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _openTag(Map<String, dynamic> tag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HashtagScreen(tag: tag['tag'] as String, uses: tag['uses'] as int),
      ),
    );
  }

  void _openPost(FeedPost post) {
    Navigator.push(context, slideRoute(PostViewerScreen(post: post)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SmartRefresher(
        enablePullDown: true,
        header: CustomHeader(
          height: 60.0,
          builder: (context, mode) => Center(
            child: buildSwifsRefreshIcon(LucideIcons.search),
          ),
        ),
        controller: _refreshController,
        onRefresh: () async {
          await _load();
          _refreshController.refreshCompleted();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _openSearch,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              const SwifsIcon(LucideIcons.search, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              const Text('Search Swifs', style: TextStyle(color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const SavedPostsScreen(),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                              child: child,
                            );
                          },
                        ),
                      ),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: SwifsIcon(LucideIcons.bookmark, size: 20, color: Colors.black)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_tags.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _tags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final t = _tags[i];
                      final uses = t['uses'] as int;
                      return GestureDetector(
                        onTap: () => _openTag(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${t['tag']}',
                                style: const TextStyle(
                                  color: kHashtagBlue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '$uses ${uses == 1 ? 'user' : 'users'}',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_loading && _posts.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator(color: kPrimary)),
                ),
              )
            else if (_posts.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('No posts yet', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(4),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => PostGridTile(post: _posts[i], onTap: () => _openPost(_posts[i])),
                    childCount: _posts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
