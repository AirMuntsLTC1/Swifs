import '../native/swifs_ffi.dart';

/// Shown on a comment that has not reached the server yet.
const String kCurrentUser = 'you';

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
  final int views;
  final int ageMinutes;
  int likes;
  int comments;
  bool liked;
  bool isSaved;
  bool isFollowing;

  FeedPost({
    required this.id,
    required this.authorId,
    required this.user,
    required this.displayName,
    required this.avatarUrl,
    required this.caption,
    required this.views,
    required this.ageMinutes,
    required this.likes,
    required this.comments,
    required this.liked,
    required this.isSaved,
    required this.isFollowing,
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
        'time': formatAge(ageMinutes),
        'views': views,
        'age_minutes': ageMinutes,
        'likes': likes,
        'comments': comments,
        'liked': liked,
        'isSaved': isSaved,
        'isFollowing': isFollowing,
        'score': score,
      };

  factory FeedPost.fromMap(Map<String, dynamic> m) => FeedPost(
        id: m['id'].toString(),
        authorId: m['authorId'].toString(),
        user: m['user'].toString(),
        displayName: (m['displayName'] ?? '').toString(),
        avatarUrl: m['avatarUrl']?.toString(),
        caption: (m['caption'] ?? '').toString(),
        views: (m['views'] as num?)?.toInt() ?? 0,
        ageMinutes: (m['age_minutes'] as num?)?.toInt() ?? 0,
        likes: (m['likes'] as num?)?.toInt() ?? 0,
        comments: (m['comments'] as num?)?.toInt() ?? 0,
        liked: m['liked'] == true,
        isSaved: m['isSaved'] == true,
        isFollowing: m['isFollowing'] == true,
      );
}

class CommentModel {
  String id;
  final String? parentId;
  final String authorId;
  final String user;
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
