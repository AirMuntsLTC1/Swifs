import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../profile/user_profile_screen.dart';
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
const Color _kMenuDark = Color(0xFF262628);

const List<String> _kQuickReactions = ['❤️', '😂', '😮', '😢', '😡', '👍'];
const List<String> _kMoreReactions = [
  '🔥', '🎉', '👏', '😍', '🥳', '😭', '🤔', '🙏', '💯', '😎', '🤣', '😊', '😅', '🥰', '🤩', '✨',
];

String _stamp(DateTime t) {
  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final ap = t.hour < 12 ? 'AM' : 'PM';
  return '${months[t.month - 1]} ${t.day}, $h:$mm $ap';
}

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

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      _snack("Message didn't send. Tap it to try again.");
    }
  }

  Future<void> _retry(DirectMessage m) async {
    setState(() => _messages = _messages.where((x) => x.id != m.id).toList());
    _input.text = m.text;
    await _send();
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

  // ------------------------------------------------------------------
  // Long-press menu
  // ------------------------------------------------------------------

  Future<void> _openMenu(DirectMessage m) async {
    if (m.pending || m.failed) return;
    final mine = m.senderId == _me;
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, _, __) => _MessageMenu(
        message: m,
        mine: mine,
        stamp: _stamp(m.createdAt),
      ),
    );
    if (action == null || !mounted) return;
    await _handle(m, action);
  }

  Future<void> _handle(DirectMessage m, String action) async {
    try {
      if (action.startsWith('react:')) {
        final emoji = action.substring(6);
        await _repo.setReaction(m.id, emoji, on: !m.myReactions.contains(emoji));
        await _load();
        return;
      }
      switch (action) {
        case 'more':
          await _openMoreReactions(m);
          break;
        case 'reply':
          setState(() => _replyTo = m);
          break;
        case 'forward':
          await _forward(m);
          break;
        case 'copy':
          await Clipboard.setData(ClipboardData(text: m.text));
          _snack('Copied');
          break;
        case 'pin':
          await _repo.setPinned(m.id, pinned: true);
          await _load();
          break;
        case 'unpin':
          await _repo.setPinned(m.id, pinned: false);
          await _load();
          break;
        case 'unsend':
          await _repo.unsend(m.id);
          if (mounted) setState(() => _messages = _messages.where((x) => x.id != m.id).toList());
          break;
        case 'hide':
          await _repo.hideForMe(m.id);
          if (mounted) setState(() => _messages = _messages.where((x) => x.id != m.id).toList());
          break;
        case 'report':
          await _report(m);
          break;
      }
    } catch (_) {
      _snack("Something went wrong. Try again.");
    }
  }

  Future<void> _openMoreReactions(DirectMessage m) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final e in [..._kQuickReactions, ..._kMoreReactions])
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, e),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null) return;
    await _repo.setReaction(m.id, emoji, on: !m.myReactions.contains(emoji));
    await _load();
  }

  Future<void> _forward(DirectMessage m) async {
    final targets = await _repo.fetchInbox();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Conversation>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Forward to', style: TextStyle(color: _kInk, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: targets.isEmpty
                  ? const Center(child: Text('No conversations yet', style: TextStyle(color: _kMuted)))
                  : ListView.builder(
                      itemCount: targets.length,
                      itemBuilder: (_, i) {
                        final c = targets[i];
                        return ListTile(
                          leading: UserAvatar(url: c.avatarUrl, name: c.label, radius: 22),
                          title: Text(c.label),
                          subtitle: Text('@${c.username}', style: const TextStyle(color: _kMuted)),
                          onTap: () => Navigator.pop(ctx, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await _repo.send(chosen.otherId, m.text);
    _snack('Forwarded to ${chosen.label}');
  }

  Future<void> _report(DirectMessage m) async {
    const reasons = ['Spam', 'Harassment or hate', 'Scam', 'Other'];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    await _repo.report(m.id, reason);
    _snack('Thanks. We will review this message.');
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final items = _messages.reversed.toList();
    String? showSeenFor;
    for (final m in _messages.reversed) {
      if (m.senderId == _me) {
        if (m.readAt != null) showSeenFor = m.id;
        break;
      }
    }
    DirectMessage? pinned;
    for (final m in _messages) {
      if (m.pinnedAt != null && (pinned == null || m.pinnedAt!.isAfter(pinned.pinnedAt!))) pinned = m;
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
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: widget.otherId))),
              child: UserAvatar(url: widget.avatarUrl, name: widget.label, radius: 16),
            ),
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
          if (pinned != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(color: _kBubbleThem, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, size: 16, color: _kPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pinned.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _kInk, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Unpin',
                    icon: const Icon(Icons.close, size: 18, color: _kMuted),
                    onPressed: () async {
                      await _repo.setPinned(pinned!.id, pinned: false);
                      await _load();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : items.isEmpty
                    ? const Center(child: Text('Say hi 👋', style: TextStyle(color: _kMuted, fontSize: 15)))
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
                              if (m.reactions.isNotEmpty) _reactionChips(m, mine),
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

  Widget _reactionChips(DirectMessage m, bool mine) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4, left: mine ? 0 : 6, right: mine ? 6 : 0),
      child: Wrap(
        spacing: 4,
        children: [
          for (final e in m.reactions.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Text(
                e.value > 1 ? '${e.key} ${e.value}' : e.key,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubble(DirectMessage m, bool mine) {
    final quoted = _findMessage(m.replyToId);
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    final content = <Widget>[];
    if (m.sharedPostId != null) {
      content.add(SharedPostWidget(postId: m.sharedPostId!, mine: mine));
    }
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
                    decoration: BoxDecoration(color: _kBubbleThem, borderRadius: BorderRadius.circular(6)),
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
        style: TextStyle(color: mine ? Colors.white : _kInk, fontSize: 15, height: 1.3),
      ),
    );

    return GestureDetector(
      onLongPress: () => _openMenu(m),
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
                color: m.failed ? const Color(0xFFFFE5E5) : (mine ? _kPrimary : _kBubbleThem),
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

/// The long-press overlay: quick reactions on top, the message, then the action card.
class _MessageMenu extends StatelessWidget {
  final DirectMessage message;
  final bool mine;
  final String stamp;

  const _MessageMenu({required this.message, required this.mine, required this.stamp});

  void _pick(BuildContext context, String action) => Navigator.pop(context, action);

  Widget _item(BuildContext context, {required IconData icon, required String label, required String action, bool danger = false}) {
    final color = danger ? const Color(0xFFFF453A) : Colors.white;
    return InkWell(
      onTap: () => _pick(context, action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 16))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mineReact = message.myReactions;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Quick reactions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: _kMenuDark, borderRadius: BorderRadius.circular(40)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in _kQuickReactions)
                        GestureDetector(
                          onTap: () => _pick(context, 'react:$e'),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mineReact.contains(e) ? Colors.white24 : Colors.transparent,
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _pick(context, 'more'),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.add, color: Colors.white, size: 26),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // The message itself
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: mine ? _kPrimary : const Color(0xFF3A3A3C),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                // Action card
                Container(
                  width: MediaQuery.of(context).size.width * 0.62,
                  decoration: BoxDecoration(color: _kMenuDark, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: Text(stamp, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                      _item(context, icon: LucideIcons.reply, label: 'Reply', action: 'reply'),
                      _item(context, icon: LucideIcons.send, label: 'Forward', action: 'forward'),
                      _item(context, icon: LucideIcons.copy, label: 'Copy', action: 'copy'),
                      _item(
                        context,
                        icon: message.pinnedAt == null ? LucideIcons.pin : LucideIcons.pinOff,
                        label: message.pinnedAt == null ? 'Pin' : 'Unpin',
                        action: message.pinnedAt == null ? 'pin' : 'unpin',
                      ),
                      if (mine)
                        _item(context, icon: LucideIcons.undo2, label: 'Unsend', action: 'unsend', danger: true),
                      _item(context, icon: LucideIcons.trash2, label: 'Delete for you', action: 'hide', danger: true),
                      if (!mine)
                        _item(context, icon: LucideIcons.flag, label: 'Report', action: 'report', danger: true),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class SharedPostWidget extends StatelessWidget {
  final String postId;
  final bool mine;
  const SharedPostWidget({super.key, required this.postId, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: mine ? Colors.white24 : _kBubbleThem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Center(child: Icon(Icons.image, color: Colors.grey, size: 32)),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Shared a post', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
