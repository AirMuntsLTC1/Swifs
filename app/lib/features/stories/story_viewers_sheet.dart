import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/user_avatar.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);

class StoryViewersSheet extends StatefulWidget {
  final String storyId;
  final String? photoUrl;
  final VoidCallback onAddToStory;

  const StoryViewersSheet({
    super.key,
    required this.storyId,
    required this.photoUrl,
    required this.onAddToStory,
  });

  @override
  State<StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<StoryViewersSheet> {
  List<StoryViewerModel> _viewers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await social.fetchStoryViewers(widget.storyId);
      if (mounted) setState(() { _viewers = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          
          // Top Section: Story Preview and Add to Story
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                  Container(
                    width: 100, height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: NetworkImage(widget.photoUrl!), fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: widget.onAddToStory,
                  child: Container(
                    width: 100, height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 8),
                        const Text('Add to story', style: TextStyle(color: Color(0xFF1877F2), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Tabs (Only Viewers, no Insights)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFEAF2FE), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Viewers', style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Viewers Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_viewers.length} viewers', style: const TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w700)),
                const SwifsIcon(LucideIcons.eye, color: kMuted, size: 20),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // List of Viewers
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : _viewers.isEmpty
                    ? const Center(child: Text('No viewers yet', style: TextStyle(color: kMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _viewers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, i) {
                          final v = _viewers[i];
                          return Row(
                            children: [
                              UserAvatar(url: v.avatarUrl, name: v.username, radius: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(v.username, style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w500)),
                              ),
                              if (v.reaction != null)
                                Text(v.reaction!, style: const TextStyle(fontSize: 20)),
                            ],
                          );
                        },
                      ),
          ),

          // Share your next update prompt
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share your next update 👋', style: TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Your friends are loving your updates. Share another story and keep connecting.', style: TextStyle(color: kMuted, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: widget.onAddToStory,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFEAF2FE),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Create a new story', style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
