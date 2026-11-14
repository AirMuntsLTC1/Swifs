import 'package:flutter/material.dart';
import '../../core/widgets/pop_heart.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);
const List<String> kReactions = ['❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂'];

/// Slides the comments sheet up from the bottom.
Future<void> showCommentsSheet(BuildContext context, {required String postId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(postId: postId),
  );
}

class CommentItem {
  final String id;
  final String user;
  final String text;
  final String time;
  int likes;
  bool liked = false;
  bool showReplies = false;
  final List<CommentItem> replies;

  CommentItem({
    required this.id,
    required this.user,
    required this.text,
    required this.time,
    this.likes = 0,
    List<CommentItem>? replies,
  }) : replies = replies ?? [];
}

// Sample data until comments come from the API.
List<CommentItem> _sampleComments() => [
      CommentItem(
        id: 'c1',
        user: 'mia',
        time: '2h',
        text: 'Love this vibe 🔥',
        likes: 24,
        replies: [
          CommentItem(id: 'r1', user: 'alex', time: '1h', text: 'Right? What song is this?', likes: 3),
          CommentItem(id: 'r2', user: 'leo', time: '50m', text: 'Same, I need this playlist', likes: 1),
        ],
      ),
      CommentItem(id: 'c2', user: 'zara', time: '5h', text: 'Where was this taken?', likes: 4),
      CommentItem(
        id: 'c3',
        user: 'leo',
        time: '8h',
        text: 'Follow me back please 🙌',
        likes: 2,
        replies: [
          CommentItem(id: 'r3', user: 'mia', time: '7h', text: 'Done!', likes: 0),
        ],
      ),
    ];

class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final List<CommentItem> _comments = _sampleComments();
  final TextEditingController _input = TextEditingController();
  CommentItem? _replyTo;
  String? _replyMention;
  int _nextId = 1;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toggleLike(CommentItem c) {
    setState(() {
      c.liked = !c.liked;
      c.likes += c.liked ? 1 : -1;
    });
  }

  void _startReply(CommentItem parent, {String? mention}) {
    setState(() {
      _replyTo = parent;
      _replyMention = mention;
      if (mention != null) {
        _input.text = '@$mention ';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyTo = null;
      _replyMention = null;
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final item = CommentItem(id: 'n${_nextId++}', user: 'you', text: text, time: 'now');
    setState(() {
      final parent = _replyTo;
      if (parent != null) {
        parent.replies.add(item);
        parent.showReplies = true;
      } else {
        _comments.insert(0, item);
      }
      _replyTo = null;
      _replyMention = null;
      _input.clear();
    });
  }

  void _addReaction(String emoji) {
    final sel = _input.selection;
    final text = _input.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final safeBottom = keyboard > 0 ? 0.0 : media.padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  children: [for (final c in _comments) _thread(c)],
                ),
              ),
              _composer(safeBottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Comments',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: kLine),
      ],
    );
  }

  Widget _thread(CommentItem c) {
    final count = c.replies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tile(c),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(left: 56, top: 2, bottom: 4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => c.showReplies = !c.showReplies),
              child: Row(
                children: [
                  Container(width: 24, height: 1, color: const Color(0xFFD0D0D0)),
                  const SizedBox(width: 8),
                  Text(
                    c.showReplies
                        ? 'Hide replies'
                        : 'View $count more ${count == 1 ? 'reply' : 'replies'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (c.showReplies)
          ...c.replies.map((r) => Padding(
                padding: const EdgeInsets.only(left: 40),
                child: _tile(r, parent: c),
              )),
      ],
    );
  }

  Widget _tile(CommentItem c, {CommentItem? parent}) {
    final isReply = parent != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 11 : 14,
            backgroundColor: kLine,
            child: Text(
              c.user[0].toUpperCase(),
              style: TextStyle(
                fontSize: isReply ? 10 : 12,
                fontWeight: FontWeight.w600,
                color: kMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.user,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(c.time, style: const TextStyle(fontSize: 12, color: kMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.text,
                  style: const TextStyle(fontSize: 14, height: 1.3, color: kInk),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _startReply(parent ?? c, mention: isReply ? c.user : null),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Reply',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PopHeart(
            key: ValueKey('heart-${c.id}'),
            isActive: c.liked,
            count: c.likes,
            size: isReply ? 16 : 18,
            onTap: () => _toggleLike(c),
          ),
        ],
      ),
    );
  }

  Widget _composer(double safeBottom) {
    final canSend = _input.text.trim().isNotEmpty;
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kLine)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 4, 8 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in kReactions)
                GestureDetector(
                  onTap: () => _addReaction(e),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
            ],
          ),
          if (_replyTo != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to @${_replyMention ?? _replyTo!.user}',
                    style: const TextStyle(fontSize: 12, color: kMuted),
                  ),
                ),
                GestureDetector(
                  onTap: _cancelReply,
                  child: const Icon(Icons.close, size: 16, color: kMuted),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: kPrimary,
                child: Text(
                  'Y',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _input,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 14, color: kInk),
                  decoration: InputDecoration(
                    hintText: 'Join the conversation...',
                    hintStyle: const TextStyle(fontSize: 14, color: kMuted),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF3F3F5),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: noBorder,
                    enabledBorder: noBorder,
                    focusedBorder: noBorder,
                  ),
                ),
              ),
              IconButton(
                onPressed: canSend ? _send : null,
                icon: Icon(Icons.send_rounded, color: canSend ? kPrimary : kMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
