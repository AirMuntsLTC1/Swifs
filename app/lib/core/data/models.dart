import '../native/swifs_ffi.dart';

/// Shown on a comment that has not reached the server yet.
const String kCurrentUser = 'you';

/// Most photos or videos one post can hold (Instagram-style carousel).
const int kMaxPostMedia = 10;

/// A failed data call. Network problems are retryable. Server rejections are not.
class DataException implements Exception {
  final String message;
  final bool retryable;

  const DataException(this.message, {this.retryable = false});

  @override
  String toString() => message;
}

/// Minutes to a short label: now, 5m, 2h, 3d.
String formatAge(int minutes) {
  if (minutes < 1) return 'now';
  if (minutes < 60) return '${minutes}m';
  if (minutes < 1440) return '${minutes ~/ 60}h';
  return '${minutes ~/ 1440}d';
}

class LikeResult {
  final bool liked;
  final int count;

  const LikeResult({required this.liked, required this.count});
}

/// One action waiting to be sent. [key] replaces an older unsent action with the same key.
class OutboxOp {
  final String key;
  final String kind;
  final Map<String, dynamic> args;

  const OutboxOp(this.key, this.kind, this.args);

  Map<String, dynamic> toJson() => {'key': key, 'kind': kind, 'args': args};

  factory OutboxOp.fromJson(Map<String, dynamic> j) => OutboxOp(
        j['key'] as String,
        j['kind'] as String,
        Map<String, dynamic>.from(j['args'] as Map),
      );
}

class FeedPost {
  final String id;
  final String authorId;
  final String user;
  final String displayName;
  final String? avatarUrl;
  final String caption;
  final String? mediaUrl;
  final String? mediaType;
  final String? thumbUrl;
  final int views;
  final int ageMinutes;
  int likes;
  int comments;
  int shares;
  bool liked;
  bool isSaved;
  bool isFollowing;
  final DateTime? createdAt;
  final List<Map<String, dynamic>> media;

  FeedPost({
    required this.id,
    required this.authorId,
    required this.user,
    required this.displayName,
    required this.avatarUrl,
    required this.caption,
    this.mediaUrl,
    this.mediaType,
    this.thumbUrl,
    required this.views,
    required this.ageMinutes,
    required this.likes,
    required this.comments,
    this.shares = 0,
    required this.liked,
    required this.isSaved,
    required this.isFollowing,
    this.createdAt,
    this.media = const [],
  });

  /// Ranking score from the C++ core.
  int get score => SwifsScore.feed(likes, comments, views, ageMinutes);

  /// The shape the feed screen reads. Also what goes into the cache.
  Map<String, dynamic> toMap() => {
        'id': id,
        'authorId': authorId,
        'user': user,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'caption': caption,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'thumbUrl': thumbUrl,
        'time': formatAge(ageMinutes),
        'views': views,
        'age_minutes': ageMinutes,
        'likes': likes,
        'comments': comments,
        'shares': shares,
        'liked': liked,
        'isSaved': isSaved,
        'isFollowing': isFollowing,
        'score': score,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'media': media,
      };

  factory FeedPost.fromMap(Map<String, dynamic> m) => FeedPost(
        id: m['id'].toString(),
        authorId: m['authorId'].toString(),
        user: m['user'].toString(),
        displayName: (m['displayName'] ?? '').toString(),
        avatarUrl: m['avatarUrl']?.toString(),
        caption: (m['caption'] ?? '').toString(),
        mediaUrl: m['mediaUrl']?.toString(),
        mediaType: m['mediaType']?.toString(),
        thumbUrl: m['thumbUrl']?.toString(),
        views: (m['views'] as num?)?.toInt() ?? 0,
        ageMinutes: (m['age_minutes'] as num?)?.toInt() ?? 0,
        likes: (m['likes'] as num?)?.toInt() ?? 0,
        comments: (m['comments'] as num?)?.toInt() ?? 0,
        shares: (m['shares'] as num?)?.toInt() ?? 0,
        liked: m['liked'] == true,
        isSaved: m['isSaved'] == true,
        isFollowing: m['isFollowing'] == true,
        createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()),
        media: (m['media'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      );
}

class CommentModel {
  String id;
  final String? parentId;
  final String authorId;
  final String user;
  final String? avatarUrl;
  final String text;
  String time;
  int ageMinutes;
  int likes;
  bool liked;
  bool showReplies;
  final List<CommentModel> replies;

  CommentModel({
    required this.id,
    this.parentId,
    this.authorId = '',
    required this.user,
    this.avatarUrl,
    required this.text,
    required this.time,
    this.ageMinutes = 0,
    this.likes = 0,
    this.liked = false,
    this.showReplies = false,
    List<CommentModel>? replies,
  }) : replies = replies ?? [];

  /// Ids that start with tmp have not reached the server yet.
  bool get isPending => id.startsWith('tmp');

  /// Ranking score from the C++ core.
  int get score => SwifsScore.comment(likes, replies.length, ageMinutes);

  Map<String, dynamic> toFlat() => {
        'id': id,
        'parent_id': parentId,
        'author_id': authorId,
        'user': user,
        'avatar_url': avatarUrl,
        'text': text,
        'age_minutes': ageMinutes,
        'likes': likes,
        'liked': liked,
      };

  factory CommentModel.fromFlat(Map<String, dynamic> m) {
    final age = (m['age_minutes'] as num?)?.toInt() ?? 0;
    return CommentModel(
      id: m['id'].toString(),
      parentId: m['parent_id']?.toString(),
      authorId: (m['author_id'] ?? '').toString(),
      user: (m['user'] ?? 'user').toString(),
      avatarUrl: m['avatar_url']?.toString(),
      text: (m['text'] ?? '').toString(),
      time: formatAge(age),
      ageMinutes: age,
      likes: (m['likes'] as num?)?.toInt() ?? 0,
      liked: m['liked'] == true,
    );
  }
}

/// Turns a flat list into top-level comments, with each one's replies inside.
List<CommentModel> buildCommentTree(List<CommentModel> flat) {
  final tops = <CommentModel>[];
  final byParent = <String, List<CommentModel>>{};
  for (final c in flat) {
    final parent = c.parentId;
    if (parent == null) {
      tops.add(c);
    } else {
      byParent.putIfAbsent(parent, () => []).add(c);
    }
  }
  for (final t in tops) {
    t.replies.addAll(byParent[t.id] ?? const []);
  }
  return tops;
}



class NotificationModel {
  final String id;
  final String type;
  final String actorId;
  final String actorUsername;
  final String? actorAvatarUrl;
  final String timeAgo;
  bool isFollowing;
  /// Short text of a message notification (the start of the message).
  final String? preview;

  NotificationModel({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorUsername,
    this.actorAvatarUrl,
    required this.timeAgo,
    this.isFollowing = false,
    this.preview,
  });
}


class StoryViewerModel {
  final String userId;
  final String username;
  final String? avatarUrl;
  final String? reaction;

  StoryViewerModel({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.reaction,
  });
}

class GroupModel {
  final String id;
  final String name;
  final String adminId;
  GroupModel({required this.id, required this.name, required this.adminId});
}
