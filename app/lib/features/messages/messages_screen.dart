import 'dart:async';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/notifications/realtime_notification_service.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/messages_repository.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/user_avatar.dart';
import 'thread_screen.dart';

const Color _kPrimary = Color(0xFFFF6B35);
const Color _kInk = Color(0xFF111111);
const Color _kMuted = Color(0xFF8E8E93);
const Color _kPill = Color(0xFFF0F2F5);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _repo = MessagesRepository.instance;
  List<Conversation> _all = [];
  List<NoteItem> _notes = [];
  String _tab = 'primary';
  String _query = '';
  bool _loading = true;
  String _myHandle = '';
  RealtimeChannel? _channel;
  Timer? _debounce;
  StreamSubscription<String>? _hubSub;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHandle();
    _channel = _repo.subscribe(_scheduleReload);
    _hubSub = RealtimeHub.instance.changes.listen((t) {
      if (t == 'messages' || t == 'resume') _scheduleReload();
    });
  }

  @override
  void dispose() {
    _hubSub?.cancel();
    _debounce?.cancel();
    final ch = _channel;
    if (ch != null) _repo.unsubscribe(ch);
    super.dispose();
  }

  /// Live updates can arrive in bursts, so wait a moment and reload once.
  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load();
    });
  }

  Future<void> _loadHandle() async {
    try {
      final me = await social.fetchMyProfile();
      if (mounted) setState(() => _myHandle = (me['username'] ?? '').toString());
    } catch (_) {
      final cached = await social.cachedMyProfile();
      if (mounted && cached != null) setState(() => _myHandle = (cached['username'] ?? '').toString());
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.fetchInbox(), _repo.fetchNotes()]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List<Conversation>;
        _notes = results[1] as List<NoteItem>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Conversation> get _visible {
    final q = _query.trim().toLowerCase();
    return _all.where((c) {
      if (c.tier != _tab) return false;
      if (q.isEmpty) return true;
      return c.label.toLowerCase().contains(q) || c.username.toLowerCase().contains(q);
    }).toList();
  }

  int _countTier(String tier) => _all.where((c) => c.tier == tier).length;

  String _ago(DateTime t) {
    final minutes = DateTime.now().difference(t).inMinutes;
    return formatAge(minutes < 0 ? 0 : minutes);
  }

  void _openThread(Conversation c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadScreen(
          otherId: c.otherId,
          label: c.label,
          username: c.username,
          avatarUrl: c.avatarUrl,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _editNote() async {
    final current = _notes.where((n) => n.userId == _repo.meOrNull).toList();
    final controller = TextEditingController(text: current.isEmpty ? '' : current.first.text);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Note', style: TextStyle(color: _kInk, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Shared with people you follow. Disappears in 24 hours.',
                style: TextStyle(color: _kMuted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: 'Share a thought…',
                filled: true,
                fillColor: _kPill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0),
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == null) return;
    try {
      await _repo.setNote(saved);
      await _load();
    } catch (_) {
      _snack("Couldn't save your note.");
    }
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _compose() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _ComposeSheet(onPick: (user) {
        Navigator.pop(ctx);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ThreadScreen(
              otherId: user['id'].toString(),
              label: (user['display_name'] ?? '').toString().trim().isNotEmpty
                  ? (user['display_name']).toString().trim()
                  : (user['username'] ?? '').toString(),
              username: (user['username'] ?? '').toString(),
              avatarUrl: user['avatar_url']?.toString(),
            ),
          ),
        ).then((_) => _load());
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _repo.meOrNull;
    final ownNote = _notes.where((n) => n.userId == me).toList();
    final others = _notes.where((n) => n.userId != me).toList();

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _myHandle.isEmpty ? 'Messages' : _myHandle,
                          style: const TextStyle(color: _kInk, fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                        const Icon(Icons.expand_more, color: _kInk, size: 20),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New message',
                  icon: const SwifsIcon(LucideIcons.pencil, color: _kInk),
                  onPressed: _compose,
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: _kPill, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: _kMuted),
                  prefixIcon: Icon(Icons.search, color: _kMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          // Notes row
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _NoteBubble(
                  label: 'Your note',
                  note: ownNote.isEmpty ? null : ownNote.first.text,
                  avatarUrl: null,
                  name: _myHandle,
                  onTap: _editNote,
                ),
                for (final n in others)
                  _NoteBubble(
                    label: n.label,
                    note: n.text,
                    avatarUrl: n.avatarUrl,
                    name: n.label,
                    onTap: null,
                  ),
              ],
            ),
          ),
          // Tabs
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _tabPill('Primary', 'primary'),
                const SizedBox(width: 8),
                _tabPill('General', 'general'),
                const SizedBox(width: 8),
                _tabPill('Requests', 'requests'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : RefreshIndicator(
                    color: _kPrimary,
                    onRefresh: _load,
                    child: _visible.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  _tab == 'requests'
                                      ? 'No message requests'
                                      : (_tab == 'general' ? 'No general messages' : 'No messages yet'),
                                  style: const TextStyle(color: _kMuted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _visible.length,
                            itemBuilder: (_, i) => _tile(_visible[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabPill(String label, String tier) {
    final selected = _tab == tier;
    final count = _countTier(tier);
    return GestureDetector(
      onTap: () => setState(() => _tab = tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kInk : _kPill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          count > 0 && tier != 'primary' ? '$label · $count' : label,
          style: TextStyle(
            color: selected ? Colors.white : _kInk,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _tile(Conversation c) {
    final unread = c.unread > 0;
    final mine = c.last.senderId == _repo.meOrNull;
    final preview = c.last.text.isEmpty ? 'Sent a photo' : c.last.text;
    return InkWell(
      onTap: () => _openThread(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Ring: orange when unread, grey when read
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: unread
                    ? const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFE1306C)])
                    : null,
                color: unread ? null : const Color(0xFFD0D3D9),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: UserAvatar(url: c.avatarUrl, name: c.label, radius: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _kInk,
                      fontSize: 15,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${mine ? 'You: ' : ''}$preview · ${_ago(c.last.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread ? _kInk : _kMuted,
                      fontSize: 13,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${c.unread}',
                  style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteBubble extends StatelessWidget {
  final String label;
  final String? note;
  final String? avatarUrl;
  final String name;
  final VoidCallback? onTap;

  const _NoteBubble({
    required this.label,
    required this.note,
    required this.avatarUrl,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: UserAvatar(url: avatarUrl, name: name.isEmpty ? '?' : name, radius: 30),
                ),
                if (note != null && note!.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD0D3D9)),
                      ),
                      child: Text(
                        note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: _kInk),
                      ),
                    ),
                  ),
                if (onTap != null && (note == null || note!.isEmpty))
                  const Positioned(
                    top: 26,
                    right: 0,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: _kPrimary,
                      child: Icon(Icons.add, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search for someone to start a new conversation with.
class _ComposeSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> user) onPick;

  const _ComposeSheet({required this.onPick});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  Timer? _debounce;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    try {
      final users = await social.searchUsers(q);
      if (!mounted || id != _request) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('New message', style: TextStyle(color: _kInk, fontWeight: FontWeight.w700, fontSize: 16)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: _kPill, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                autofocus: true,
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250), () => _search(v));
                },
                decoration: const InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: Icon(Icons.search, color: _kMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : _users.isEmpty
                    ? const Center(child: Text('No people found', style: TextStyle(color: _kMuted)))
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (_, i) {
                          final u = _users[i];
                          final display = (u['display_name'] ?? '').toString().trim();
                          final username = (u['username'] ?? '').toString();
                          return ListTile(
                            leading: UserAvatar(
                              url: u['avatar_url']?.toString(),
                              name: display.isNotEmpty ? display : username,
                              radius: 22,
                            ),
                            title: Text(display.isNotEmpty ? display : username),
                            subtitle: Text('@$username', style: const TextStyle(color: _kMuted)),
                            onTap: () => widget.onPick(u),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
