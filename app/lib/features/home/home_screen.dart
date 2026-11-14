import 'package:flutter/material.dart';
import '../../core/theme/swifs_icon.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/mocks/mock_feed.dart';

const Color kPrimary = Color(0xFFFF6B35);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> _posts = mockPosts;

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
            const Text('Swifs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kPrimary)),
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
              // Header
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              // Image
              Container(
                height: 350, color: Colors.grey.shade200,
                child: const Center(child: SwifsIcon(LucideIcons.image, size: 48, color: Colors.grey)),
              ),
              // Action Icons (Aligned and Sized 28)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ActionIcon(
                      icon: LucideIcons.heart,
                      isLiked: p['liked'],
                      onTap: () => setState(() => p['liked'] = !p['liked']),
                    ),
                    const SizedBox(width: 12),
                    _ActionIcon(icon: LucideIcons.messageCircle, onTap: () {}),
                    const SizedBox(width: 12),
                    _ActionIcon(icon: LucideIcons.send, onTap: () {}),
                    const Spacer(),
                    _ActionIcon(icon: LucideIcons.bookmark, onTap: () {}),
                  ],
                ),
              ),
              // Likes & Caption
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['likes'] + (p['liked'] ? 1 : 0)} likes', style: const TextStyle(fontWeight: FontWeight.w500)),
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

// Custom Icon widget to perfectly align Lucide icons without default IconButton padding issues
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final bool isLiked;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, this.isLiked = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Consistent touch target
        child: SwifsIcon(
          icon,
          size: 28, // Bigger size as requested
          color: isLiked ? kPrimary : null, // Orange heart if liked
        ),
      ),
    );
  }
}
