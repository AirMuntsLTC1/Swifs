import 'package:flutter/material.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import '../../core/theme/swifs_refresh.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'settings_screen.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/widgets/post_media.dart';
import '../../core/widgets/user_avatar.dart';

const Color kPrimary = Color(0xFFFF6B35);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  Map<String, dynamic> _profile = {};
  List<FeedPost> _posts = [];
  List<FeedPost> _saved = [];

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _load();
  }

  Future<void> _loadCachedProfile() async {
    final cached = await social.cachedMyProfile();
    if (cached != null && mounted) setState(() => _profile = cached);
  }

  /// Loads the signed-in user's profile, posts, and saved posts from Supabase.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        social.fetchMyProfile(),
        social.fetchMyPosts(),
        social.fetchSavedPosts(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _posts = results[1] as List<FeedPost>;
        _saved = results[2] as List<FeedPost>;
      });
    } catch (_) {
      // Offline: keep whatever is already on screen.
    }
  }

  String get _displayName {
    final name = (_profile['display_name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final handle = (_profile['username'] ?? '').toString().trim();
    return handle.isNotEmpty ? handle : 'Your name';
  }

  List<FeedPost> _tabPosts(int idx) {
    if (idx == 0) return _posts;
    if (idx == 1) return _posts.where((p) => p.mediaType == 'video').toList();
    return _saved;
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SmartRefresher(
        enablePullDown: true,
        header: CustomHeader(
          height: 60.0,
          builder: (context, mode) => Center(
            child: buildSwifsRefreshIcon(LucideIcons.user),
          ),
        ),
        controller: _refreshController,
        onRefresh: () async {
          await _load();
          _refreshController.refreshCompleted();
        },
        child: DefaultTabController(
          length: 3,
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: Padding(
                  // Added top padding to respect status bar
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          UserAvatar(
                            url: _profile['avatar_url']?.toString(),
                            name: _displayName,
                            radius: 42,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Stat('${_posts.length}', 'Posts'),
                                _Stat('${_profile['followers_count'] ?? 0}', 'Followers'),
                                _Stat('${_profile['following_count'] ?? 0}', 'Following'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_displayName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('@${_profile['username'] ?? ''}', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(1.0, 0.0); // Slide from right
                                    const end = Offset.zero;
                                    const curve = Curves.easeOutCubic;
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    return SlideTransition(position: animation.drive(tween), child: child);
                                  },
                                ),
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0F2F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SwifsIcon(LucideIcons.settings, size: 20, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: TabBar(
                  indicatorColor: kPrimary,
                  labelColor: kPrimary,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: SwifsIcon(LucideIcons.grid3x3)),
                    Tab(icon: SwifsIcon(LucideIcons.play)),
                    Tab(icon: SwifsIcon(LucideIcons.bookmark)),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              children: List.generate(3, (idx) {
                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _tabPosts(idx).length,
                  itemBuilder: (_, i) => PostGridTile(
                    post: _tabPosts(idx)[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostViewerScreen(post: _tabPosts(idx)[i])),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

