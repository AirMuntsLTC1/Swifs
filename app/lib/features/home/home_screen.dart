import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/mocks/mock_feed.dart';
import '../../core/native/swifs_ffi.dart';

const Color kPrimary = Color(0xFFFF6B35);
const String apiUrl = 'http://10.0.2.2:8000/api'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Map<String, dynamic>> _posts;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    _audioPlayer.setSource(AssetSource('sounds/bubble_pop.mp3'));
    _posts = mockPosts.map((p) => {
      ...p, 
      'isFollowing': false,
      'isSaved': false,
    }).toList();
  }

  void _playPopSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.resume();
    } catch (e) {
      print('Audio error: $e');
    }
  }

  void _handleLike(int index) {
    final p = _posts[index];
    final newLikedState = !p['liked'];
    if (newLikedState) _playPopSound();
    final newLikesCount = newLikedState ? p['likes'] + 1 : p['likes'] - 1;

    // Try-catch prevents crash if C++ isn't compiled in Gradle yet
    int newScore = 0;
    try {
      newScore = SwifsCore.feedScore(newLikesCount, p['comments'], p['views'], p['age_minutes']);
      print('C++ Calculated New Score: $newScore');
    } catch (e) {
      print('C++ FFI not loaded yet: $e');
    }

    setState(() {
      p['liked'] = newLikedState;
      p['likes'] = newLikesCount;
    });

    _sendToApi('/like', {'post_id': p['id'], 'score': newScore});
  }

  void _handleSave(int index) {
    final p = _posts[index];
    if (!p['isSaved']) _playPopSound();
    setState(() => p['isSaved'] = !p['isSaved']);
    _sendToApi('/save', {'post_id': p['id']});
  }

  void _handleFollow(int index) {
    final p = _posts[index];
    setState(() => p['isFollowing'] = !p['isFollowing']);
    
    int userHash = 0;
    try {
      userHash = SwifsCore.hashUser(p['user']);
    } catch (e) {
      print('C++ FFI not loaded yet: $e');
    }
    
    _sendToApi('/follow', {'username': p['user'], 'user_hash': userHash});
  }

  Future<void> _sendToApi(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      print('PHP API Response: ${response.body}');
    } catch (e) {
      print('PHP API Error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _storiesRow(),
            Expanded(child: _feed()),
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
              IconButton(icon: const SwifsIcon(LucideIcons.search), onPressed: () {}),
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
                      onTap: () {},
                    ),
                    const SizedBox(width: 4),
                    _AnimatedActionIcon(
                      icon: LucideIcons.upload, // Straight up arrow
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
    if (widget.isActive) return; // Only animate when turning ON

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
      // Filled solid icons for active state
      if (widget.icon == LucideIcons.heart) {
        return const Icon(Icons.favorite, size: 28, color: Colors.red);
      } else if (widget.icon == LucideIcons.bookmark) {
        return const Icon(Icons.bookmark, size: 28, color: kPrimary);
      }
    }
    // Lucide outline icons for inactive state
    return SwifsIcon(widget.icon, size: 28, color: Colors.black);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
  void dispose() {
    _audioPlayer.dispose();
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
