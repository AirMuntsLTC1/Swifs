import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter_plus/lucide_icons_flutter_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/messages_repository.dart';
import '../../core/theme/swifs_icon.dart';
import '../../core/widgets/user_avatar.dart';

const Color _kPrimary = Color(0xFFFF6B35);
const Color _kInk = Color(0xFF111111);
const Color _kMuted = Color(0xFF8E8E93);
const Color _kBubbleThem = Color(0xFFF0F2F5);

class ThreadScreen extends StatefulWidget {
  final String otherId;
  final String label;
  final String username;
  final String? avatarUrl;

  const ThreadScreen({
    super.key,
    required this.otherId,
    required this.label,
    required this.username,
    required this.avatarUrl,
  });

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _repo = MessagesRepository.instance;
  final _input = TextEditingController();
  List<DirectMessage> _messages = [];
  final Map<String, Future<String?>> _storyFutures = {};
  DirectMessage? _replyTo;
  bool _loading = true;
  RealtimeChannel? _channel;
  Timer? _debounce;

  String? get _me => _repo.meOrNull;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.subscribe(_scheduleReload);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final ch = _channel;
    if (ch != null) _repo.unsubscribe(ch);
    _input.dispose();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final list = await _repo.fetchThread(widget.otherId);
      if (!mounted) return;
      setState(() {
        // Keep any message still sending, so it does not vanish on a live update.
        final pending = _messages.where((m) => m.pending).toList();
        _messages = [...list, ...pending];
        _loading = false;
      });
      // Mark incoming messages as read. Failure here is not important to the user.
      unawaited(_repo.markRead(widget.otherId).catchError((_) {}));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final me = _me;
    if (me == null) return;

    final replyId = _replyTo?.id;
    final tempId = 'tmp-${DateTime.now().microsecondsSinceEpoch}';
    final temp = DirectMessage(
      id: tempId,
      senderId: me,
      recipientId: widget.otherId,
      text: text,
      createdAt: DateTime.now(),
      replyToId: replyId,
      pending: true,
    );
    _input.clear();
    setState(() {
      _messages = [..._messages, temp];
      _replyTo = null;
    });

    try {
      final saved = await _repo.send(widget.otherId, text, replyToId: replyId);
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m.id == tempId) saved else m,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        temp.pending = false;
        temp.failed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message didn't send. Tap it to try again.")),
      );
    }
  }

  Future<void> _retry(DirectMessage m) async {
    setState(() {
      _messages = _messages.where((x) => x.id != m.id).toList();
    });
    _input.text = m.text;
    await _send();
  }

  void _showActions(DirectMessage m) {
    final mine = m.senderId == _me;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const SwifsIcon(LucideIcons.reply, color: _kInk),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = m);
              },
            ),
            ListTile(
              leading: const SwifsIcon(LucideIcons.copy, color: _kInk),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: m.text));
              },
            ),
            if (mine && !m.pending)
              ListTile(
                leading: const SwifsIcon(LucideIcons.trash2, color: Colors.red),
                title: const Text('Unsend', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _repo.unsend(m.id);
                    if (mounted) setState(() => _messages = _messages.where((x) => x.id != m.id).toList());
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't unsend. Try again.")),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  DirectMessage? _findMessage(String? id) {
    if (id == null) return null;
    for (final m in _messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<String?> _storyUrl(String storyId) =>
      _storyFutures.putIfAbsent(storyId, () => _repo.storyPhotoUrl(storyId));

  @override
  Widget build(BuildContext context) {
    final items = _messages.reversed.toList();
    // The last message I sent that they have read, to show "Seen" under it.
    String? showSeenFor;
    for (final m in _messages.reversed) {
      if (m.senderId == _me) {
        if (m.readAt != null) showSeenFor = m.id;
        break;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const SwifsIcon(LucideIcons.arrowLeft, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(url: widget.avatarUrl, name: widget.label, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kInk, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (widget.username.isNotEmpty)
                    Text('@${widget.username}', style: const TextStyle(color: _kMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : items.isEmpty
                    ? const Center(
                        child: Text('Say hi 👋', style: TextStyle(color: _kMuted, fontSize: 15)),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final m = items[i];
                          final mine = m.senderId == _me;
                          return Column(
                            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              _bubble(m, mine),
                              if (m.id == showSeenFor)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, bottom: 6, right: 4),
                                  child: Text('Seen', style: TextStyle(color: _kMuted, fontSize: 11)),
                                ),
                              const SizedBox(height: 4),
                            ],
                          );
                        },
                      ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(DirectMessage m, bool mine) {
    final quoted = _findMessage(m.replyToId);
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    final content = <Widget>[];
    if (m.storyId != null) {
      content.add(
        FutureBuilder<String?>(
          future: _storyUrl(m.storyId!),
          builder: (_, snap) {
            final url = snap.data;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _kBubbleThem,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: url == null || url.isEmpty
                        ? const SizedBox.shrink()
                        : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mine ? 'You replied to their story' : 'Replied to your story',
                    style: const TextStyle(color: _kMuted, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    if (quoted != null) {
      content.add(
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: mine ? Colors.white : _kPrimary, width: 3)),
          ),
          child: Text(
            quoted.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: mine ? Colors.white : _kInk, fontSize: 12),
          ),
        ),
      );
    }
    content.add(
      Text(
        m.text,
        style: TextStyle(
          color: mine ? Colors.white : _kInk,
          fontSize: 15,
          height: 1.3,
        ),
      ),
    );

    return GestureDetector(
      onLongPress: () => _showActions(m),
      onTap: m.failed ? () => _retry(m) : null,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Opacity(
            opacity: m.pending ? 0.6 : 1,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: m.failed
                    ? const Color(0xFFFFE5E5)
                    : (mine ? _kPrimary : _kBubbleThem),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    final reply = _replyTo;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEFEFEF))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                decoration: BoxDecoration(color: _kBubbleThem, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to: ${reply.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _kMuted, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18, color: _kMuted),
                      onPressed: () => setState(() => _replyTo = null),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _kBubbleThem, borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        hintStyle: TextStyle(color: _kMuted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: _kPrimary),
                  onPressed: _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
