import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import '../../core/data/messages_repository.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/swifs_skeleton.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);

class CreateGroupScreen extends StatefulWidget {
  final String postId;
  final List<String> initialUsers;
  const CreateGroupScreen({super.key, required this.postId, required this.initialUsers});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _repo = MessagesRepository.instance;
  List<Map<String, dynamic>> _users = [];
  final Set<String> _selected = {};
  final TextEditingController _groupName = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _caption = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialUsers);
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
      final groupId = await _repo.createGroup(_groupName.text.trim().isEmpty ? 'New Group' : _groupName.text.trim(), _selected.toList());
      await _repo.sendPostToGroup(widget.postId, _caption.text.trim(), groupId);
      if (mounted) Navigator.pop(context, groupId);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create group')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Discard chat?', style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text('If you quit before creating the chat, your changes won\'t be saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard chat', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continue', style: TextStyle(color: kInk)),
              ),
            ],
          ),
        );
        if (shouldPop == true && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const SwifsIcon(LucideIcons.arrowLeft, color: kInk),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('New group', style: TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _groupName,
                onChanged: (_) => setState(() => _hasChanges = true),
                decoration: const InputDecoration(
                  hintText: 'Name group (optional)',
                  hintStyle: TextStyle(color: kMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1, color: kLine),
            
            // Selected Users
            if (_selected.isNotEmpty)
              Container(
                height: 90,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _selected.map((id) {
                    final u = _users.firstWhere((e) => e['id'].toString() == id, orElse: () => {'id': id, 'username': 'user', 'avatar_url': null});
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              UserAvatar(url: u['avatar_url']?.toString(), name: u['username'].toString(), radius: 26),
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
                          const SizedBox(height: 4),
                          Text(u['username'].toString(), style: const TextStyle(fontSize: 11, color: kInk), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: kMuted),
                    prefixIcon: Icon(Icons.search, color: kMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // Suggested Users
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft, child: Text('Suggested', style: TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 16))),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const LoadingList()
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                        final u = _users[i];
                        final id = u['id'].toString();
                        if (_selected.contains(id)) return const SizedBox.shrink();
                        return ListTile(
                          leading: UserAvatar(url: u['avatar_url']?.toString(), name: u['username'].toString(), radius: 22),
                          title: Text(u['username'].toString(), style: const TextStyle(color: kInk, fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: const SwifsIcon(LucideIcons.plus, color: kMuted),
                            onPressed: () => setState(() { _selected.add(id); _hasChanges = true; }),
                          ),
                        );
                      },
                    ),
            ),

            // Send Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty || _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _sending ? const CircularProgressIndicator(color: Colors.white) : const Text('Send to group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
