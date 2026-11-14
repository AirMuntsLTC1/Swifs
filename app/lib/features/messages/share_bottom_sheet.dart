import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/messages_repository.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/user_avatar.dart';
import 'create_group_screen.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);

class ShareBottomSheet extends StatefulWidget {
  final String postId;
  const ShareBottomSheet({super.key, required this.postId});

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final _repo = MessagesRepository.instance;
  List<Map<String, dynamic>> _users = [];
  final Set<String> _selected = {};
  final TextEditingController _search = TextEditingController();
  final TextEditingController _caption = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.fetchMutualFollowers();
      if (mounted) setState(() { _users = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _repo.sendPostToUsers(widget.postId, _caption.text.trim(), _selected.toList());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openGroupCreation() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => CreateGroupScreen(postId: widget.postId, initialUsers: _selected.toList())),
    );
    if (result != null && mounted) Navigator.pop(context); // Close sheet if group was sent
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      final q = _search.text.toLowerCase();
      return (u['username'] ?? '').toString().toLowerCase().contains(q) ||
             (u['display_name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
      height: (screenH - keyboard) * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          
          // Search Bar with Group Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(color: kMuted),
                        prefixIcon: Icon(Icons.search, color: kMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _openGroupCreation,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFF0F2F5), shape: BoxShape.circle),
                    child: const Center(child: SwifsIcon(LucideIcons.users, size: 20, color: kInk)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          // Selected Users Row
          if (_selected.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _selected.map((id) {
                  final u = _users.firstWhere((e) => e['id'].toString() == id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        UserAvatar(url: u['avatar_url']?.toString(), name: u['username'].toString(), radius: 28),
                        Positioned(
                          top: 0, right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected.remove(id)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Users List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      final id = u['id'].toString();
                      final isSelected = _selected.contains(id);
                      return ListTile(
                        leading: UserAvatar(url: u['avatar_url']?.toString(), name: u['username'].toString(), radius: 22),
                        title: Text((u['display_name'] ?? u['username']).toString(), style: const TextStyle(color: kInk, fontWeight: FontWeight.w600)),
                        subtitle: Text('@${u['username']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                        trailing: GestureDetector(
                          onTap: () => setState(() => isSelected ? _selected.remove(id) : _selected.add(id)),
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? kPrimary : Colors.transparent,
                              border: Border.all(color: isSelected ? kPrimary : kMuted, width: 1.5),
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Caption & Send
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _caption,
                  decoration: const InputDecoration(
                    hintText: 'Write a message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: kMuted),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty || _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      disabledBackgroundColor: const Color(0xFFB0C4DE),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _sending ? const CircularProgressIndicator(color: Colors.white) : const Text('Send separately', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
