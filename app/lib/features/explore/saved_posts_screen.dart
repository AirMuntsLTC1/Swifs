import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/post_media.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<FeedPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await social.fetchSavedPosts();
      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Saved', style: TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(icon: const SwifsIcon(LucideIcons.search, color: kInk), onPressed: () {}),
          IconButton(icon: const SwifsIcon(LucideIcons.plus, color: kInk), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _posts.isEmpty
              ? _emptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) => PostGridTile(
                    post: _posts[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostViewerScreen(post: _posts[i])),
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: Color(0xFFF0F2F5), shape: BoxShape.circle),
            child: const Center(child: SwifsIcon(LucideIcons.bookmark, size: 32, color: kMuted)),
          ),
          const SizedBox(height: 16),
          const Text('Save what interests you', style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Come back anytime to watch or share your saved\ncontent, or add it to a collection.', textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Explore', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
