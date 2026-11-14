import 'package:flutter/material.dart';
import '../../core/data/models.dart';
import '../../core/data/social.dart';
import '../../core/network/interaction_queue.dart';
import '../../core/widgets/pop_heart.dart';
import '../../core/widgets/user_avatar.dart';

const Color kPrimary = Color(0xFFFF6B35);
const Color kInk = Color(0xFF111111);
const Color kMuted = Color(0xFF8E8E93);
const Color kLine = Color(0xFFEFEFEF);
const List<String> kReactions = ['❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂'];

/// Slides the comments sheet up. Completes when it closes.
Future<void> showCommentsSheet(BuildContext context, {required String postId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(postId: postId),
  );
}

class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final List<CommentModel> _comments = [];
  final TextEditingController _input = TextEditingController();
  bool _loading = true;
  String? _error;
  int _tempSeq = 0;
  CommentModel? _replyTo;
  String? _replyMention;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Shows the saved comments at once, then refreshes them from Supabase.
  Future<void> _load() async {
    final cached = await social.cachedComments(widget.postId);
    if (cached != null && mounted) {
      setState(() {
        _apply(cached);
        _loading = false;
      });
    }
    try {
      final fresh = await social.fetchComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _apply(fresh);
        _loading = false;
        _error = null;
      });
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_comments.isEmpty) _error = e.retryable ? "Can't reach the server." : e.message;
      });
    }
  }

  /// Replaces the list with [list] (ordered on the phone by the C++ core).
  /// Comments that are still waiting to be sent stay at the top.
  void _apply(List<CommentModel> list) {
    final pending = _comments.where((c) => c.isPending).toList();
    _comments
      ..clear()
      ..addAll(list)
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final p in pending.reversed) {
      _comments.insert(0, p);
    }
  }

  // ---- Actions: update now, send through the outbox ----

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final parent = _replyTo;
    final tempId = 'tmp${++_tempSeq}';
    final temp = CommentModel(id: tempId, parentId: parent?.id, user: kCurrentUser, text: text, time: 'now');

    setState(() {
      if (parent != null) {
        parent.replies.add(temp);
        parent.showReplies = true;
      } else {
        _comments.insert(0, temp);
      }
      _replyTo = null;
      _replyMention = null;
      _input.clear();
    });

    InteractionQueue.instance.enqueue(
      OutboxOp('comment:$tempId', 'comment', {
        'postId': widget.postId,
        'text': text,
        'parentId': parent?.id,
        'tempId': tempId,
      }),
      onSuccess: (result) {
        if (!mounted) return;
        final server = result as CommentModel;
        setState(() {
          temp.id = server.id;
          temp.time = server.time;
          temp.ageMinutes = server.ageMinutes;
        });
      },
      onFail: (_) {
        if (!mounted) return;
        setState(() {
          _comments.remove(temp);
          parent?.replies.remove(temp);
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Comment not sent. Try again.')),
        );
      },
    );
  }

  void _toggleLike(CommentModel c) {
    if (c.isPending) return; // saved on the server first
    final wasLiked = c.liked;
    final prevLikes = c.likes;
    final nowLiked = !wasLiked;
    setState(() {
      c.liked = nowLiked;
      c.likes += nowLiked ? 1 : -1;
    });

    InteractionQueue.instance.enqueue(
      OutboxOp('clike:${c.id}', 'commentLike', {'commentId': c.id, 'liked': nowLiked}),
      onSuccess: (result) {
        if (!mounted) return;
        final r = result as LikeResult;
        setState(() {
          c.liked = r.liked;
          c.likes = r.count;
        });
      },
      onFail: (_) {
        if (!mounted) return;
        setState(() {
          c.liked = wasLiked;
          c.likes = prevLikes;
        });
      },
    );
  }

  void _startReply(CommentModel parent, {String? mention}) {
    setState(() {
      _replyTo = parent;
      _replyMention = mention;
      if (mention != null) {
        _input.text = '@$mention ';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      }
    });
  }

  void _cancelReply() => setState(() {
        _replyTo = null;
        _replyMention = null;
      });

  void _addReaction(String emoji) {
    final sel = _input.selection;
    final text = _input.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _input.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    setState(() {});
  }

  // ---- Layout ----

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
              Expanded(child: _body(scroll)),
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

  Widget _body(ScrollController scroll) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontSize: 14, color: kMuted)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: const Text('Try again', style: TextStyle(color: kPrimary)),
            ),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Text('No comments yet', style: TextStyle(fontSize: 14, color: kMuted)),
      );
    }
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      children: [for (final c in _comments) _thread(c)],
    );
  }

  Widget _thread(CommentModel c) {
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMuted),
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

  Widget _tile(CommentModel c, {CommentModel? parent}) {
    final isReply = parent != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            url: c.avatarUrl,
            name: c.user,
            radius: isReply ? 11 : 14,
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                    ),
                    const SizedBox(width: 6),
                    Text(c.time, style: const TextStyle(fontSize: 12, color: kMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(c.text, style: const TextStyle(fontSize: 14, height: 1.3, color: kInk)),
                const SizedBox(height: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _startReply(parent ?? c, mention: isReply ? c.user : null),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Reply',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMuted),
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
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kLine))),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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


