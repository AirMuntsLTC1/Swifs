import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class DirectMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? replyToId;
  final String? storyId;
  final String? sharedPostId;
  final String? groupId;
  bool pending;
  bool failed;
  DateTime? pinnedAt;
  /// emoji -> how many people reacted with it
  final Map<String, int> reactions = {};
  /// emojis I have used on this message
  final Set<String> myReactions = {};

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
    this.readAt,
    this.replyToId,
    this.storyId,
    this.sharedPostId,
    this.groupId,
    this.pinnedAt,
    this.pending = false,
    this.failed = false,
  });
}

/// One chat with one person, with the latest message and how many are unread.
class Conversation {
  final String otherId;
  DirectMessage last;
  int unread = 0;
  String username = 'user';
  String displayName = '';
  String? avatarUrl;
  bool iFollow = false;
  bool followsMe = false;

  Conversation({required this.otherId, required this.last});

  String get label => displayName.trim().isNotEmpty ? displayName.trim() : username;

  /// Primary: people you follow. General: they follow you. Requests: neither.
  String get tier => iFollow ? 'primary' : (followsMe ? 'general' : 'requests');
}

/// A short note above someone's name in the inbox. Notes last 24 hours.
class NoteItem {
  final String userId;
  final String text;
  final DateTime createdAt;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const NoteItem({
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  String get label => displayName.trim().isNotEmpty ? displayName.trim() : username;
}

class MessagesRepository {
  MessagesRepository._();
  static final MessagesRepository instance = MessagesRepository._();

  static const _select = 'id, sender, recipient, text, created_at, read_at, reply_to_id, story_id, pinned_at';

  SupabaseClient get _db => Supabase.instance.client;

  String? get meOrNull => _db.auth.currentUser?.id;

  String get _me {
    final id = meOrNull;
    if (id == null) throw StateError('Please sign in.');
    return id;
  }

  DirectMessage _fromRow(Map<String, dynamic> r) => DirectMessage(
        id: r['id'].toString(),
        senderId: r['sender'].toString(),
        recipientId: r['recipient'].toString(),
        text: (r['text'] ?? '').toString(),
        createdAt: DateTime.tryParse(r['created_at'].toString())?.toLocal() ?? DateTime.now(),
        readAt: r['read_at'] == null ? null : DateTime.tryParse(r['read_at'].toString()),
        replyToId: r['reply_to_id']?.toString(),
        storyId: r['story_id']?.toString(),
        sharedPostId: r['shared_post_id']?.toString(),
        groupId: r['group_id']?.toString(),
        pinnedAt: r['pinned_at'] == null ? null : DateTime.tryParse(r['pinned_at'].toString())?.toLocal(),
      );

  Future<Map<String, Map<String, dynamic>>> _profiles(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _db.from('profiles').select('id, username, display_name, avatar_url').inFilter('id', list);
    return {for (final p in rows) p['id'].toString(): Map<String, dynamic>.from(p)};
  }

  Future<Set<String>> _iFollow(String me) async {
    final rows = await _db.from('follows').select('followee').eq('follower', me);
    return {for (final r in rows) r['followee'].toString()};
  }

  Future<Set<String>> _followsMe(String me) async {
    final rows = await _db.from('follows').select('follower').eq('followee', me);
    return {for (final r in rows) r['follower'].toString()};
  }

  /// Every conversation, newest first, with unread counts and follow state for the tabs.
  Future<List<Conversation>> fetchInbox() async {
    final me = _me;
    final rows = await _db
        .from('messages')
        .select(_select)
        .or('sender.eq.$me,recipient.eq.$me')
        .order('created_at', ascending: false)
        .limit(500);

    final byOther = <String, Conversation>{};
    for (final r in rows) {
      final m = _fromRow(Map<String, dynamic>.from(r));
      final other = m.senderId == me ? m.recipientId : m.senderId;
      final conv = byOther.putIfAbsent(other, () => Conversation(otherId: other, last: m));
      if (m.recipientId == me && m.readAt == null) conv.unread++;
    }

    final profiles = await _profiles(byOther.keys);
    final iFollow = await _iFollow(me);
    final followsMe = await _followsMe(me);
    for (final conv in byOther.values) {
      final p = profiles[conv.otherId] ?? <String, dynamic>{};
      conv.username = (p['username'] ?? 'user').toString();
      conv.displayName = (p['display_name'] ?? '').toString();
      conv.avatarUrl = p['avatar_url']?.toString();
      conv.iFollow = iFollow.contains(conv.otherId);
      conv.followsMe = followsMe.contains(conv.otherId);
    }

    final out = byOther.values.toList()..sort((a, b) => b.last.createdAt.compareTo(a.last.createdAt));
    return out;
  }

  /// All messages between me and one person, oldest first.
  Future<List<DirectMessage>> fetchThread(String otherId, {int limit = 200}) async {
    final me = _me;
    final rows = await _db
        .from('messages')
        .select(_select)
        .or('and(sender.eq.$me,recipient.eq.$otherId),and(sender.eq.$otherId,recipient.eq.$me)')
        .order('created_at', ascending: false)
        .limit(limit);
    final list = rows.map((r) => _fromRow(Map<String, dynamic>.from(r))).toList();
    if (list.isEmpty) return list;

    final byId = {for (final m in list) m.id: m};
    final ids = byId.keys.toList();

    final hidden = await _db.from('message_hidden').select('message_id').eq('user_id', me).inFilter('message_id', ids);
    final hiddenIds = {for (final h in hidden) h['message_id'].toString()};

    final reactRows = await _db.from('message_reactions').select('message_id, user_id, emoji').inFilter('message_id', ids);
    for (final r in reactRows) {
      final m = byId[r['message_id'].toString()];
      if (m == null) continue;
      final emoji = r['emoji'].toString();
      m.reactions[emoji] = (m.reactions[emoji] ?? 0) + 1;
      if (r['user_id'].toString() == me) m.myReactions.add(emoji);
    }

    return list.where((m) => !hiddenIds.contains(m.id)).toList();
  }

  /// Marks everything they sent me as read.
  Future<void> markRead(String otherId) async {
    final me = _me;
    await _db
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient', me)
        .eq('sender', otherId)
        .isFilter('read_at', null);
  }

  Future<DirectMessage> send(String otherId, String text, {String? replyToId, String? storyId}) async {
    final me = _me;
    final row = await _db
        .from('messages')
        .insert({
          'sender': me,
          'recipient': otherId,
          'text': text,
          'reply_to_id': replyToId,
          'story_id': storyId,
        })
        .select(_select)
        .single();
    return _fromRow(Map<String, dynamic>.from(row));
  }

    Future<List<Map<String, dynamic>>> fetchMutualFollowers() async {
    final me = _me;
    final following = await _iFollow(me);
    final followers = await _followsMe(me);
    final mutual = following.intersection(followers).toList();
    if (mutual.isEmpty) return [];
    final profiles = await _db.from('profiles').select('id, username, display_name, avatar_url').inFilter('id', mutual);
    return profiles.map((p) => Map<String, dynamic>.from(p)).toList();
  }

  Future<String> createGroup(String name, List<String> memberIds) async {
    final me = _me;
    final group = await _db.from('groups').insert({'name': name, 'admin_id': me}).select('id').single();
    final groupId = group['id'].toString();
    
    final allMembers = [me, ...memberIds];
    for (final uid in allMembers) {
      await _db.from('group_members').insert({'group_id': groupId, 'user_id': uid});
    }
    return groupId;
  }

  Future<void> sendPostToUsers(String postId, String caption, List<String> userIds) async {
    final me = _me;
    for (final uid in userIds) {
      await _db.from('messages').insert({
        'sender': me,
        'recipient': uid,
        'text': caption,
        'shared_post_id': postId,
      });
    }
  }

  Future<void> sendPostToGroup(String postId, String caption, String groupId) async {
    final me = _me;
    await _db.from('messages').insert({
      'sender': me,
      'group_id': groupId,
      'text': caption,
      'shared_post_id': postId,
    });
  }

  Future<void> unsend(String messageId) async {
    final me = _me;
    await _db.from('messages').delete().eq('id', messageId).eq('sender', me);
  }

  /// Notes from me and people I follow, from the last 24 hours. Newest per person.
  Future<List<NoteItem>> fetchNotes() async {
    final me = _me;
    final following = await _iFollow(me);
    final ids = [me, ...following];
    final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
    final rows = await _db
        .from('notes')
        .select('user_id, text, created_at')
        .inFilter('user_id', ids)
        .gt('created_at', since)
        .order('created_at', ascending: false);

    final latest = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final id = r['user_id'].toString();
      latest.putIfAbsent(id, () => Map<String, dynamic>.from(r));
    }
    final profiles = await _profiles(latest.keys);
    return latest.entries.map((e) {
      final p = profiles[e.key] ?? <String, dynamic>{};
      return NoteItem(
        userId: e.key,
        text: (e.value['text'] ?? '').toString(),
        createdAt: DateTime.tryParse(e.value['created_at'].toString())?.toLocal() ?? DateTime.now(),
        username: (p['username'] ?? 'user').toString(),
        displayName: (p['display_name'] ?? '').toString(),
        avatarUrl: p['avatar_url']?.toString(),
      );
    }).toList();
  }

  /// Replaces my note. Empty text removes it.
  Future<void> setNote(String text) async {
    final me = _me;
    final clean = text.trim();
    await _db.from('notes').delete().eq('user_id', me);
    if (clean.isEmpty) return;
    await _db.from('notes').insert({
      'user_id': me,
      'text': clean.length > 60 ? clean.substring(0, 60) : clean,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Story photo URL for a story reply bubble.
  Future<String?> storyPhotoUrl(String storyId) async {
    final row = await _db.from('stories').select('photo_path').eq('id', storyId).maybeSingle();
    final path = row?['photo_path']?.toString();
    if (path == null || path.isEmpty) return null;
    final base = _db.rest.url.replaceAll('/rest/v1', '');
    return '$base/storage/v1/object/public/stories/$path';
  }

  /// Calls [onChange] whenever any message row changes that I am allowed to see.
  RealtimeChannel subscribe(void Function() onChange) {
    final me = meOrNull ?? 'anon';
    return _db
        .channel('messages-$me-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _db.removeChannel(channel);

  /// Adds or removes one emoji reaction from my side.
  Future<void> setReaction(String messageId, String emoji, {required bool on}) async {
    final me = _me;
    if (on) {
      await _db.from('message_reactions').upsert(
            {'message_id': messageId, 'user_id': me, 'emoji': emoji},
            onConflict: 'message_id,user_id,emoji',
            ignoreDuplicates: true,
          );
    } else {
      await _db
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', me)
          .eq('emoji', emoji);
    }
  }

  Future<void> setPinned(String messageId, {required bool pinned}) async {
    await _db
        .from('messages')
        .update({'pinned_at': pinned ? DateTime.now().toUtc().toIso8601String() : null})
        .eq('id', messageId);
  }

  /// Removes the message from my view only.
  Future<void> hideForMe(String messageId) async {
    final me = _me;
    await _db.from('message_hidden').upsert(
          {'message_id': messageId, 'user_id': me},
          onConflict: 'message_id,user_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> report(String messageId, String reason) async {
    final me = _me;
    await _db.from('message_reports').insert({'message_id': messageId, 'reporter': me, 'reason': reason});
  }
}
