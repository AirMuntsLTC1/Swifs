import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/post_media.dart';

const Color _kInk = Color(0xFF111111);
const Color _kMuted = Color(0xFF8E8E93);
const Color _kHashtagBlue = Color(0xFF1877F2);
const Color _kPrimary = Color(0xFFFF6B35);

class HashtagScreen extends StatefulWidget {
  final String tag;
  final int uses;

  const HashtagScreen({super.key, required this.tag, required this.uses});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  List<FeedPost> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await social.fetchHashtagPosts(widget.tag);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load posts for #${widget.tag}. Check your connection.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesLabel = '${widget.uses} ${widget.uses == 1 ? 'user' : 'users'} use this';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Rounded top header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FE),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const SwifsIcon(LucideIcons.arrowLeft, color: _kInk),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '#${widget.tag}',
                      style: const TextStyle(
                        color: _kHashtagBlue,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Hashtag', style: const TextStyle(color: _kMuted, fontSize: 14)),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(usesLabel, style: const TextStyle(color: _kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _kMuted)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Text('No posts with this hashtag yet', style: TextStyle(color: _kMuted)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _posts.length,
      itemBuilder: (_, i) => PostGridTile(
        post: _posts[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostViewerScreen(post: _posts[i])),
        ),
      ),
    );
  }
}
