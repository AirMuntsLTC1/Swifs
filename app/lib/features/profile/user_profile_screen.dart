import 'package:flutter/material.dart';
import 'follow_list_screen.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/post_media.dart';
import '../../core/widgets/user_avatar.dart';
import '../messages/thread_screen.dart';
import '../../core/widgets/swifs_skeleton.dart';
import '../../core/widgets/route_defer.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kBlue = Color(0xFF1877F2);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  void _openFollows({required bool followers}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FollowListScreen(userId: widget.userId, followers: followers),
    ));
  }

  Map<String, dynamic> _profile = {};
  List<FeedPost> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followsMe = false;

  /// True when this profile is the signed-in user's own.
  bool get _isMe => Supabase.instance.client.auth.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    if (_isMe) {
      // Your own profile is the Profile tab, not a visitor's page with Follow and Message.
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyProfile());
      return;
    }
    // Load after the slide-in finishes so the transition stays smooth.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runAfterRouteAnimation(context, () { if (mounted) _load(); });
    });
  }

  /// Returns to the main screens and slides to the Profile tab.
  void _goToMyProfile() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.requestedTab.value = 3;
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        social.fetchUserProfile(widget.userId),
        social.fetchUserPosts(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _posts = results[1] as List<FeedPost>;
        _isFollowing = _profile['isFollowing'] == true;
        _followsMe = _profile['followsMe'] == true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _toggleFollow() async {
    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !wasFollowing);
    try {
      await social.setFollow(widget.userId, !wasFollowing);
    } catch (_) {
      if (mounted) setState(() => _isFollowing = wasFollowing);
    }
  }

  void _openMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadScreen(
          otherId: widget.userId,
          label: _profile['display_name'] ?? _profile['username'],
          username: _profile['username'],
          avatarUrl: _profile['avatar_url'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('@${_profile['username'] ?? ''}', style: const TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
      ),
      body: _loading
          ? const LoadingGrid()
          : DefaultTabController(
              length: 2,
              child: NestedScrollView(
                headerSliverBuilder: (_, __) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              UserAvatar(
                                url: _profile['avatar_url']?.toString(),
                                name: _profile['username'] ?? 'User',
                                radius: 42,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat('${_profile['posts_count'] ?? 0}', 'Posts'),
                                    _Stat('${_profile['followers_count'] ?? 0}', 'Followers', onTap: () => _openFollows(followers: true)),
                                    _Stat('${_profile['following_count'] ?? 0}', 'Following', onTap: () => _openFollows(followers: false)),
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
                                Text(_profile['display_name'] ?? _profile['username'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: kInk)),
                                const SizedBox(height: 4),
                                Text(_profile['bio'] ?? '', style: const TextStyle(color: kMuted, fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Action Buttons
                          Row(
                            children: [
                              if (!_isMe) Expanded(
                                child: GestureDetector(
                                  onTap: _toggleFollow,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isFollowing ? const Color(0xFFF0F2F5) : kPrimary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _isFollowing ? 'Following' : (_followsMe ? 'Follow Back' : 'Follow'),
                                        style: TextStyle(
                                          color: _isFollowing ? kInk : Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _openMessage,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(8)),
                                    child: const Center(
                                      child: Text('Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                    ),
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
                      unselectedLabelColor: kMuted,
                      tabs: [
                        Tab(icon: SwifsIcon(LucideIcons.grid3x3)),
                        Tab(icon: SwifsIcon(LucideIcons.play)),
                      ],
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _buildGrid(_posts),
                    _buildGrid(_posts.where((p) => p.mediaType == 'video').toList()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGrid(List<FeedPost> posts) {
    if (posts.isEmpty) return const Center(child: Text('No posts yet', style: TextStyle(color: kMuted)));
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) => PostGridTile(
        post: posts[i],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostFeedScreen(posts: posts, initialIndex: i))),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _Stat(this.value, this.label, {this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: kInk)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
